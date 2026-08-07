/*
Run From Debug Console

Id jobId = DHM_DuplicateCheckBatch.startBatch(
    'Account',
    false,
    null,
    'C501_Age_Calculate__c < 18',
    1,
    null // optional source Account/Contact Id; use an Id here for a focused test
);
System.debug('Batch Job Id = ' + jobId);
*/

public without sharing class DHM_DuplicateCheckBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    public static final Integer REQUIRED_BATCH_SIZE = 50;

    public class BatchScopeException extends Exception {}

    private String objectType;
    private Boolean performMerge;
    // Legacy internal name retained for compatibility. In Version 2.0 production paths,
    // this contains Flow input additionalMatchFieldsCsv (for example, Birthdate).
    private String matchFieldsCsv;
    private String contactExclusionCriteria;
    private Integer maxMerges;
    private Id sourceRecordId;

    private Integer processedCount = 0;
    private Integer updatedCount = 0;
    private Integer candidateSetCount = 0;
    private Integer mergeCount = 0;
    private Boolean mergeLimitReached = false;
    private Integer errorCount = 0;

    public DHM_DuplicateCheckBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv
    ) {
        this(objectType, performMerge, matchFieldsCsv, null);
    }

    public DHM_DuplicateCheckBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria
    ) {
        this(objectType, performMerge, matchFieldsCsv, contactExclusionCriteria, null, null);
    }

    public DHM_DuplicateCheckBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria,
        Integer maxMerges
    ) {
        this(objectType, performMerge, matchFieldsCsv, contactExclusionCriteria, maxMerges, null);
    }

    public DHM_DuplicateCheckBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria,
        Integer maxMerges,
        Id sourceRecordId
    ) {
        this.objectType = objectType;
        this.performMerge = performMerge == null ? false : performMerge;
        this.matchFieldsCsv = matchFieldsCsv;
        this.contactExclusionCriteria = contactExclusionCriteria;
        this.maxMerges = (maxMerges == null || maxMerges <= 0) ? null : maxMerges;
        this.sourceRecordId = sourceRecordId;

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::Constructor objectType=' + objectType +
            ', performMerge=' + String.valueOf(this.performMerge) +
            ', matchFieldsCsv=' + matchFieldsCsv +
            ', contactExclusionCriteria=' + this.contactExclusionCriteria +
            ', maxMerges=' + String.valueOf(this.maxMerges) +
            ', sourceRecordId=' + String.valueOf(this.sourceRecordId)
        );
    }

    public static Id startBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv
    ) {
        return startBatch(objectType, performMerge, matchFieldsCsv, null);
    }

    public static Id startBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria
    ) {
        return startBatch(objectType, performMerge, matchFieldsCsv, contactExclusionCriteria, null);
    }

    public static Id startBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria,
        Integer maxMerges
    ) {
        return startBatch(objectType, performMerge, matchFieldsCsv, contactExclusionCriteria, maxMerges, null);
    }

    public static Id startBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria,
        Integer maxMerges,
        Id sourceRecordId
    ) {
        Integer batchSizeToUse = Test.isRunningTest() ? 200 : REQUIRED_BATCH_SIZE;

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::startBatch objectType=' + objectType +
            ', performMerge=' + String.valueOf(performMerge == null ? false : performMerge) +
            ', matchFieldsCsv=' + matchFieldsCsv +
            ', contactExclusionCriteria=' + contactExclusionCriteria +
            ', maxMerges=' + String.valueOf(maxMerges) +
            ', sourceRecordId=' + String.valueOf(sourceRecordId) +
            ', batchSize=' + String.valueOf(batchSizeToUse)
        );

        return Database.executeBatch(
            new DHM_DuplicateCheckBatch(
                objectType,
                performMerge,
                matchFieldsCsv,
                contactExclusionCriteria,
                maxMerges,
                sourceRecordId
            ),
            batchSizeToUse
        );
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String soql;

        if (objectType == 'Contact') {
            soql =
                'SELECT Id, Duplicate_Check_Candidate__c, Duplicate_Check_Error__c ' +
                'FROM Contact' +
                (sourceRecordId == null ? '' : ' WHERE Id = :sourceRecordId');
        } else if (objectType == 'Account') {
            soql =
                'SELECT Id, Duplicate_Check_Candidate__c, Duplicate_Check_Error__c ' +
                'FROM Account' +
                (sourceRecordId == null ? '' : ' WHERE Id = :sourceRecordId');
        } else {
            soql = 'SELECT Id FROM Account WHERE Id = null';
        }

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::start jobId=' + bc.getJobId() +
            ', objectType=' + objectType +
            ', sourceRecordId=' + String.valueOf(sourceRecordId) +
            ', soql=' + soql
        );

        return Database.getQueryLocator(soql);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {

        Integer actualScopeSize = (scope == null ? 0 : scope.size());

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::execute ENTER jobId=' +
            bc.getJobId() +
            ', scopeSize=' + (scope == null ? 'null' : String.valueOf(scope.size())) +
            ', objectType=' + objectType
        );

        if (scope == null || scope.isEmpty()) {
            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatch::execute scope is NULL/EMPTY - exiting'
            );
            return;
        }

        if (hasReachedMergeLimit()) {
            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatch::execute merge limit already reached. Skipping remaining scope. maxMerges=' +
                String.valueOf(maxMerges) + ', mergeCount=' + String.valueOf(mergeCount)
            );
            return;
        }

        if (objectType == 'Contact') {

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatch::execute routing Contact'
            );

            processContacts(scope);

        } else if (objectType == 'Account') {

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatch::execute routing Account'
            );

            processAccounts(scope);

        } else {

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatch::execute unsupported objectType=' + objectType
            );
        }

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::execute EXIT jobId=' + bc.getJobId()
        );
    }

    private void processContacts(List<SObject> scope) {
        List<Contact> updates = new List<Contact>();
        List<Id> contactIds = new List<Id>();

        for (SObject sob : scope) {
            contactIds.add((Id)sob.get('Id'));
        }

        List<String> matchFields = getMatchFields();
        Set<String> fieldSet = new Set<String>{
            'Id',
            'Duplicate_Check_Candidate__c',
            'Duplicate_Check_Error__c'
        };
        fieldSet.addAll(matchFields);

        Map<Id, Contact> contactsById = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            String soql =
                'SELECT ' + String.join(new List<String>(fieldSet), ',') +
                ' FROM Contact WHERE Id IN :contactIds';

            for (Contact con : Database.query(soql)) {
                contactsById.put(con.Id, con);
            }
        }

        for (SObject sob : scope) {
            if (hasReachedMergeLimit()) {
                break;
            }

            Id contactId = (Id)sob.get('Id');
            Contact con = contactsById.get(contactId);
            processedCount++;

            if (con == null) {
                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatch::processContacts missing queried Contact for Id=' +
                    String.valueOf(contactId) +
                    ''
                );

                continue;
            }

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatch::processContacts evaluating Contact Id=' +
                String.valueOf(con.Id) +
                ', existing Duplicate_Check_Candidate__c=' +
                String.valueOf(con.Duplicate_Check_Candidate__c)
            );

            if (Test.isRunningTest() &&
                !DHM_DuplicateRuleCandidateService.hasTestCandidates() &&
                !recordHasRequiredMatchFields(con, matchFields)) {
                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatch::processContacts skipping Contact Id=' +
                    String.valueOf(con.Id) +
                    ' due to missing required match fields'
                );

                if (con.Duplicate_Check_Error__c != null) {
                    Contact updateCon = new Contact(Id = con.Id);
                    DHM_SharedCode.ClearDuplicateCheckError(updateCon);
                    updates.add(updateCon);
                }
                continue;
            }

            Contact updateCon = new Contact(
                Id = con.Id
            );
            Boolean updateNeeded = false;

            try {
                DHM_SingleContactMerge.Result res =
                    DHM_SingleContactMergeService.evaluateAndMerge(
                        con.Id,
                        performMerge,
                        matchFieldsCsv
                    );

                if (con.Duplicate_Check_Error__c != null) {
                    DHM_SharedCode.ClearDuplicateCheckError(updateCon);
                    updateNeeded = true;
                }

                if (res != null &&
                    res.candidateFound &&
                    res.masterContactId != null &&
                    res.duplicateContactId != null) {

                    recordEligibleMerge(res.merged);

                    Id candidateId =
                        (res.masterContactId == con.Id)
                        ? res.duplicateContactId
                        : res.masterContactId;

                    if (candidateId != null &&
                        candidateId != con.Id &&
                        con.Duplicate_Check_Candidate__c != candidateId) {

                        updateCon.Duplicate_Check_Candidate__c = candidateId;
                        updateNeeded = true;
                        candidateSetCount++;

                        DHM_SharedCode.OutputDebugLogText(
                            LoggingLevel.DEBUG,
                            '***** DHM_DuplicateCheckBatch::processContacts setting Duplicate_Check_Candidate__c for Contact Id=' +
                            String.valueOf(con.Id) +
                            ' to candidateId=' + String.valueOf(candidateId)
                        );
                    }
                }
            } catch (Exception e) {
                errorCount++;
                DHM_SharedCode.LogAndSetError(
                    updateCon,
                    '***** DHM_DuplicateCheckBatch::processContacts Contact Id=' +
                    String.valueOf(con.Id) +
                    ' Exception: ' + String.valueOf(e.getMessage())
                );
                updateNeeded = true;
            }

            if (updateNeeded) {
                updates.add(updateCon);
            }
        }

        saveContactUpdates(updates);
    }

    private void saveContactUpdates(List<Contact> updates) {
        if (updates.isEmpty()) {
            return;
        }

        Database.SaveResult[] saveResults = Database.update(updates, false);

        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                updatedCount++;
            } else {
                errorCount++;
                for (Database.Error err : saveResults[i].getErrors()) {
                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.DEBUG,
                        '***** DHM_DuplicateCheckBatch::saveContactUpdates error Contact Id=' +
                        String.valueOf(updates[i].Id) +
                        ', statusCode=' + String.valueOf(err.getStatusCode()) +
                        ', message=' + err.getMessage()
                    );
                }
            }
        }

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::saveContactUpdates complete updatedCount=' +
            String.valueOf(updatedCount) +
            ', errorCount=' + String.valueOf(errorCount)
        );
    }

    private void processAccounts(List<SObject> scope) {
        List<Account> updates = new List<Account>();
        List<Id> accountIds = new List<Id>();

        for (SObject sob : scope) {
            accountIds.add((Id)sob.get('Id'));
        }

        Map<Id, Account> accountsById = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, Duplicate_Check_Candidate__c, Duplicate_Check_Error__c
                FROM Account
                WHERE Id IN :accountIds
            ]) {
                accountsById.put(acc.Id, acc);
            }
        }

        List<String> matchFields = getMatchFields();
        Set<String> contactFieldSet = new Set<String>{ 'Id', 'AccountId' };
        contactFieldSet.addAll(matchFields);

        Map<Id, List<Contact>> contactsByAccountId = new Map<Id, List<Contact>>();
        if (!accountIds.isEmpty()) {
            String contactSoql =
                'SELECT ' + String.join(new List<String>(contactFieldSet), ',') +
                ' FROM Contact WHERE AccountId IN :accountIds';

            for (Contact con : Database.query(contactSoql)) {
                if (!contactsByAccountId.containsKey(con.AccountId)) {
                    contactsByAccountId.put(con.AccountId, new List<Contact>());
                }
                contactsByAccountId.get(con.AccountId).add(con);
            }
        }

        for (SObject sob : scope) {
            if (hasReachedMergeLimit()) {
                break;
            }

            Id accountId = (Id)sob.get('Id');
            Account acc = accountsById.get(accountId);
            processedCount++;

            if (acc == null) {
                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatch::processAccounts missing queried Account for Id=' +
                    String.valueOf(accountId) +
                    ''
                );

                continue;
            }

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatch::processAccounts evaluating Account Id=' +
                String.valueOf(acc.Id) +
                ', existing Duplicate_Check_Candidate__c=' +
                String.valueOf(acc.Duplicate_Check_Candidate__c)
            );

            List<Contact> accountContacts = contactsByAccountId.get(acc.Id);
            if (Test.isRunningTest() &&
                !DHM_DuplicateRuleCandidateService.hasTestCandidates() &&
                !accountHasAnyMatchableContact(accountContacts, matchFields)) {
                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatch::processAccounts skipping Account Id=' +
                    String.valueOf(acc.Id) +
                    ' due to no related Contacts with all required match fields populated'
                );

                if (acc.Duplicate_Check_Error__c != null) {
                    Account updateAcc = new Account(Id = acc.Id);
                    DHM_SharedCode.ClearDuplicateCheckError(updateAcc);
                    updates.add(updateAcc);
                }
                continue;
            }

            Account updateAcc = new Account(
                Id = acc.Id
            );
            Boolean updateNeeded = false;

            try {
                DHM_SingleAccountMerge.Result res =
                    DHM_SingleAccountMergeService.evaluateAndMerge(
                        acc.Id,
                        performMerge,
                        matchFieldsCsv,
                        contactExclusionCriteria
                    );

                if (acc.Duplicate_Check_Error__c != null) {
                    DHM_SharedCode.ClearDuplicateCheckError(updateAcc);
                    updateNeeded = true;
                }

                if (res != null &&
                    res.candidateFound &&
                    res.masterAccountId != null &&
                    res.duplicateAccountId != null) {

                    recordEligibleMerge(res.merged);

                    Id candidateId =
                        (res.masterAccountId == acc.Id)
                        ? res.duplicateAccountId
                        : res.masterAccountId;

                    if (candidateId != null &&
                        candidateId != acc.Id &&
                        acc.Duplicate_Check_Candidate__c != candidateId) {

                        updateAcc.Duplicate_Check_Candidate__c = candidateId;
                        updateNeeded = true;
                        candidateSetCount++;

                        DHM_SharedCode.OutputDebugLogText(
                            LoggingLevel.DEBUG,
                            '***** DHM_DuplicateCheckBatch::processAccounts setting Duplicate_Check_Candidate__c for Account Id=' +
                            String.valueOf(acc.Id) +
                            ' to candidateId=' + String.valueOf(candidateId)
                        );
                    }
                }
            } catch (Exception e) {
                errorCount++;
                DHM_SharedCode.LogAndSetError(
                    updateAcc,
                    '***** DHM_DuplicateCheckBatch::processAccounts Account Id=' +
                    String.valueOf(acc.Id) +
                    ' Exception: ' + String.valueOf(e.getMessage())
                );
                updateNeeded = true;
            }

            if (updateNeeded) {
                updates.add(updateAcc);
            }
        }

        saveAccountUpdates(updates);
    }

    private void saveAccountUpdates(List<Account> updates) {
        if (updates.isEmpty()) {
            return;
        }

        Database.SaveResult[] saveResults = Database.update(updates, false);

        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                updatedCount++;
            } else {
                errorCount++;
                for (Database.Error err : saveResults[i].getErrors()) {
                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.DEBUG,
                        '***** DHM_DuplicateCheckBatch::saveAccountUpdates error Account Id=' +
                        String.valueOf(updates[i].Id) +
                        ', statusCode=' + String.valueOf(err.getStatusCode()) +
                        ', message=' + err.getMessage()
                    );
                }
            }
        }

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::saveAccountUpdates complete updatedCount=' +
            String.valueOf(updatedCount) +
            ', errorCount=' + String.valueOf(errorCount)
        );
    }

    private List<String> getMatchFields() {
        List<String> matchFields = new List<String>();

        if (String.isBlank(matchFieldsCsv)) {
            return matchFields;
        }

        for (String fieldName : matchFieldsCsv.split(',')) {
            String trimmedField = fieldName == null ? '' : fieldName.trim();
            if (!String.isBlank(trimmedField)) {
                matchFields.add(trimmedField);
            }
        }

        return matchFields;
    }

    private Boolean recordHasRequiredMatchFields(SObject recordToCheck, List<String> matchFields) {
        if (recordToCheck == null) {
            return false;
        }

        if (matchFields == null || matchFields.isEmpty()) {
            return true;
        }

        for (String fieldName : matchFields) {
            if (!fieldHasValue(recordToCheck, fieldName)) {
                return false;
            }
        }

        return true;
    }

    private Boolean accountHasAnyMatchableContact(List<Contact> contactsToCheck, List<String> matchFields) {
        if (contactsToCheck == null || contactsToCheck.isEmpty()) {
            return false;
        }

        for (Contact con : contactsToCheck) {
            if (recordHasRequiredMatchFields(con, matchFields)) {
                return true;
            }
        }

        return false;
    }

    private Boolean fieldHasValue(SObject recordToCheck, String fieldName) {
        if (recordToCheck == null || String.isBlank(fieldName)) {
            return false;
        }

        Object fieldValue = recordToCheck.get(fieldName);

        if (fieldValue == null) {
            return false;
        }

        if (fieldValue instanceof String) {
            return !String.isBlank((String)fieldValue);
        }

        return true;
    }

    private Boolean hasReachedMergeLimit() {
        return maxMerges != null && mergeCount >= maxMerges;
    }

    private void recordEligibleMerge(Boolean merged) {
        // In evaluation-only mode, a candidateFound result is a merge that would occur.
        // In merge mode, only count a merge after the service reports it completed.
        if (performMerge && merged != true) {
            return;
        }

        mergeCount++;
        mergeLimitReached = hasReachedMergeLimit();

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::recordEligibleMerge mergeCount=' +
            String.valueOf(mergeCount) + ', maxMerges=' + String.valueOf(maxMerges) +
            ', mergeLimitReached=' + String.valueOf(mergeLimitReached)
        );
    }

    public void finish(Database.BatchableContext bc) {
        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::finish jobId=' + bc.getJobId() +
            ', objectType=' + objectType +
            ', processedCount=' + String.valueOf(processedCount) +
            ', updatedCount=' + String.valueOf(updatedCount) +
            ', candidateSetCount=' + String.valueOf(candidateSetCount) +
            ', mergeCount=' + String.valueOf(mergeCount) +
            ', maxMerges=' + String.valueOf(maxMerges) +
            ', mergeLimitReached=' + String.valueOf(mergeLimitReached) +
            ', errorCount=' + String.valueOf(errorCount)
        );
    }
}