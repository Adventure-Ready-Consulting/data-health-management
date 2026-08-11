/*
Run From Debug Console

Id jobId = DHM_DuplicateCheckBatch.startBatch(
    'Account',
    false,
    null,
    'C501_Age_Calculate__c < 18',
    1,
    null, // optional source Account/Contact Id; use an Id here for a focused test
    false  // Account Merge Require All Matching Contacts
);
System.debug('Batch Job Id = ' + jobId);
*/

public without sharing class DHM_DuplicateCheckBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    public static final Integer ACCOUNT_BATCH_SIZE = 10;
    public static final Integer CONTACT_BATCH_SIZE = 50;
    public static final Integer REQUIRED_BATCH_SIZE = CONTACT_BATCH_SIZE;

    public class BatchScopeException extends Exception {}

    private String objectType;
    private Boolean performMerge;
    private String matchFieldsCsv;
    private String contactExclusionCriteria;
    private Integer maxMerges;
    private Id sourceRecordId;
    private Boolean accountMergeRequireAllMatchingContacts;

    private Integer processedCount = 0;
    private Integer updatedCount = 0;
    private Integer candidateSetCount = 0;
    private Integer mergeCount = 0;
    private Integer deferredContactMergeCount = 0;
    private Set<String> deferredContactPairKeys = new Set<String>();
    private Datetime batchStartedAt;
    private Boolean contactWorkerScheduled = false;
    private Boolean mergeLimitReached = false;
    private Integer errorCount = 0;

    public DHM_DuplicateCheckBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria,
        Integer maxMerges,
        Id sourceRecordId,
        Boolean accountMergeRequireAllMatchingContacts
    ) {
        this.objectType = objectType;
        this.performMerge = performMerge == null ? false : performMerge;
        this.matchFieldsCsv = matchFieldsCsv;
        this.contactExclusionCriteria = contactExclusionCriteria;
        this.maxMerges = (maxMerges == null || maxMerges <= 0) ? null : maxMerges;
        this.sourceRecordId = sourceRecordId;
        this.accountMergeRequireAllMatchingContacts = accountMergeRequireAllMatchingContacts == true;

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::Constructor objectType=' + objectType +
            ', performMerge=' + String.valueOf(this.performMerge) +
            ', matchFieldsCsv=' + matchFieldsCsv +
            ', contactExclusionCriteria=' + this.contactExclusionCriteria +
            ', maxMerges=' + String.valueOf(this.maxMerges) +
            ', sourceRecordId=' + String.valueOf(this.sourceRecordId) +
            ', accountMergeRequireAllMatchingContacts=' + String.valueOf(this.accountMergeRequireAllMatchingContacts)
        );
    }

    public static Id startBatch(
        String objectType,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria,
        Integer maxMerges,
        Id sourceRecordId,
        Boolean accountMergeRequireAllMatchingContacts
    ) {
        Integer batchSizeToUse = Test.isRunningTest()
            ? 200
            : (objectType == 'Account' ? ACCOUNT_BATCH_SIZE : CONTACT_BATCH_SIZE);

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::startBatch objectType=' + objectType +
            ', performMerge=' + String.valueOf(performMerge == null ? false : performMerge) +
            ', matchFieldsCsv=' + matchFieldsCsv +
            ', contactExclusionCriteria=' + contactExclusionCriteria +
            ', maxMerges=' + String.valueOf(maxMerges) +
            ', sourceRecordId=' + String.valueOf(sourceRecordId) +
            ', accountMergeRequireAllMatchingContacts=' + String.valueOf(accountMergeRequireAllMatchingContacts == true) +
            ', batchSize=' + String.valueOf(batchSizeToUse)
        );

        return Database.executeBatch(
            new DHM_DuplicateCheckBatch(
                objectType,
                performMerge,
                matchFieldsCsv,
                contactExclusionCriteria,
                maxMerges,
                sourceRecordId,
                accountMergeRequireAllMatchingContacts
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

        batchStartedAt = System.now();

        DHM_JobLogService.createStartedLog(
            bc.getJobId(),
            objectType,
            performMerge,
            maxMerges,
            objectType == 'Account' ? ACCOUNT_BATCH_SIZE : CONTACT_BATCH_SIZE
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
                '***** DHM_DuplicateCheckBatch::execute merge limit already reached. Aborting remaining batch work. maxMerges=' +
                String.valueOf(maxMerges) + ', mergeCount=' + String.valueOf(mergeCount)
            );
            abortRemainingBatchWork(bc);
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

        // Returning from execute() only ends the current scope. QueryLocator has already
        // prepared the remaining scopes, so explicitly abort the Batch Apex job once the
        // configured merge limit is satisfied.
        if (hasReachedMergeLimit()) {
            abortRemainingBatchWork(bc);
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

            if (!recordHasRequiredMatchFields(con, matchFields)) {
                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatch::processContacts skipping Contact Id=' +
                    String.valueOf(con.Id) +
                    ' due to missing required match fields'
                );

                Contact updateCon = new Contact(Id = con.Id);
                Boolean updateNeeded = false;

                if (con.Duplicate_Check_Error__c != null) {
                    DHM_SharedCode.ClearDuplicateCheckError(updateCon);
                    updateNeeded = true;
                }

                if (con.Duplicate_Check_Candidate__c != null) {
                    updateCon.Duplicate_Check_Candidate__c = null;
                    updateNeeded = true;

                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.DEBUG,
                        '***** DHM_DuplicateCheckBatch::processContacts clearing stale Duplicate_Check_Candidate__c for Contact Id=' +
                        String.valueOf(con.Id) +
                        ' because required additional match fields are not populated'
                    );
                }

                if (updateNeeded) {
                    updates.add(updateCon);
                }
                continue;
            }

            Contact updateCon = new Contact(
                Id = con.Id
            );
            Boolean updateNeeded = false;

            try {
                // Contact merges are intentionally deferred out of Batch Apex. NPSP can
                // enqueue multiple Queueable jobs during Database.merge(), which exceeds the
                // one-Queueable limit of a Batch Apex transaction. Discovery still happens
                // here; a scheduled worker performs the actual Contact merges afterward.
                DHM_SingleContactMerge.Result res =
                    DHM_SingleContactMergeService.evaluateAndMerge(
                        con.Id,
                        false,
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

                    if (performMerge) {
                        String pairKey = buildContactPairKey(res.masterContactId, res.duplicateContactId);
                        if (!deferredContactPairKeys.contains(pairKey)) {
                            deferredContactPairKeys.add(pairKey);
                            deferredContactMergeCount++;
                            candidateSetCount++;
                            mergeLimitReached = hasReachedMergeLimit();
                        }
                    } else {
                        recordEligibleMerge(false);
                    }

                    Id candidateId =
                        (res.masterContactId == con.Id)
                        ? res.duplicateContactId
                        : res.masterContactId;

                    if (candidateId != null && candidateId != con.Id &&
                        (performMerge || con.Duplicate_Check_Candidate__c != candidateId)) {

                        // In merge mode, write the candidate even when unchanged so the
                        // scheduled worker can isolate candidates touched by this batch run.
                        updateCon.Duplicate_Check_Candidate__c = candidateId;
                        updateNeeded = true;
                        if (!performMerge) {
                            candidateSetCount++;
                        }

                        DHM_SharedCode.OutputDebugLogText(
                            LoggingLevel.DEBUG,
                            '***** DHM_DuplicateCheckBatch::processContacts setting Duplicate_Check_Candidate__c for Contact Id=' +
                            String.valueOf(con.Id) +
                            ' to candidateId=' + String.valueOf(candidateId)
                        );
                    }
                } else if (con.Duplicate_Check_Candidate__c != null) {
                    updateCon.Duplicate_Check_Candidate__c = null;
                    updateNeeded = true;

                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.DEBUG,
                        '***** DHM_DuplicateCheckBatch::processContacts clearing stale Duplicate_Check_Candidate__c for Contact Id=' +
                        String.valueOf(con.Id) +
                        ' because the current evaluation found no eligible candidate'
                    );
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
            if (!accountHasAnyMatchableContact(accountContacts, matchFields)) {
                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatch::processAccounts skipping Account Id=' +
                    String.valueOf(acc.Id) +
                    ' due to no related Contacts with all required match fields populated'
                );

                Account updateAcc = new Account(Id = acc.Id);
                Boolean updateNeeded = false;

                if (acc.Duplicate_Check_Error__c != null) {
                    DHM_SharedCode.ClearDuplicateCheckError(updateAcc);
                    updateNeeded = true;
                }

                if (acc.Duplicate_Check_Candidate__c != null) {
                    updateAcc.Duplicate_Check_Candidate__c = null;
                    updateNeeded = true;

                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.DEBUG,
                        '***** DHM_DuplicateCheckBatch::processAccounts clearing stale Duplicate_Check_Candidate__c for Account Id=' +
                        String.valueOf(acc.Id) +
                        ' because no related Contact has all required additional match fields populated'
                    );
                }

                if (updateNeeded) {
                    updates.add(updateAcc);
                }
                continue;
            }

            Account updateAcc = new Account(
                Id = acc.Id
            );
            Boolean updateNeeded = false;

            try {
                // NPSP KNOWN RISK - ACCOUNT MERGES FROM BATCH APEX
                // Historical DHM/NPSP implementations observed that an Account merge can
                // invoke NPSP Account-delete automation that starts asynchronous work. In
                // some NPSP versions/configurations this can fail when Database.merge is
                // reached from Batch Apex (for example, a future/async invocation error).
                // Account merges currently remain inline because this org's production runs
                // have completed successfully. If that NPSP failure returns, do NOT try to
                // solve it by catching the exception or by moving the merge to Queueable.
                // Recommended fallback: use the same architecture as Contact merging -- let
                // this batch discover/persist eligible Account pairs, then have a separately
                // scheduled synchronous worker revalidate and perform Database.merge outside
                // the Batch/Queueable transaction.
                //
                // PSEUDOCODE ONLY - intentionally commented out until the workaround is needed:
                // if (performMerge) {
                //     persistAccountMergeCandidate(...);
                //     deferAccountMergeToScheduledWorker = true;
                // }
                DHM_SingleAccountMerge.Result res =
                    DHM_SingleAccountMergeService.evaluateAndMerge(
                        acc.Id,
                        performMerge,
                        matchFieldsCsv,
                        contactExclusionCriteria,
                        accountMergeRequireAllMatchingContacts
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

                    if (performMerge && res.merged) {
                        candidateSetCount++;

                        // The duplicate Account no longer exists after a successful merge.
                        // Do not attempt to update it, which previously produced a false
                        // application error for every intentional merge. If the current
                        // Account survived as master, clear any stale candidate value.
                        if (res.duplicateAccountId == acc.Id) {
                            updateNeeded = false;
                            continue;
                        }
                        if (acc.Duplicate_Check_Candidate__c != null) {
                            updateAcc.Duplicate_Check_Candidate__c = null;
                            updateNeeded = true;
                        }
                        if (updateNeeded) {
                            updates.add(updateAcc);
                        }
                        continue;
                    }

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
                } else if (acc.Duplicate_Check_Candidate__c != null) {
                    updateAcc.Duplicate_Check_Candidate__c = null;
                    updateNeeded = true;

                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.DEBUG,
                        '***** DHM_DuplicateCheckBatch::processAccounts clearing stale Duplicate_Check_Candidate__c for Account Id=' +
                        String.valueOf(acc.Id) +
                        ' because the current evaluation found no eligible candidate'
                    );
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

        Map<String, Schema.SObjectField> fieldMap =
            recordToCheck.getSObjectType().getDescribe().fields.getMap();

        if (!fieldMap.containsKey(fieldName)) {
            return false;
        }

        Schema.DisplayType fieldType =
            fieldMap.get(fieldName).getDescribe().getType();

        Object fieldValue = recordToCheck.get(fieldName);

        if (fieldValue == null) {
            return false;
        }

        if (
            fieldType == Schema.DisplayType.String ||
            fieldType == Schema.DisplayType.TextArea ||
            fieldType == Schema.DisplayType.Email ||
            fieldType == Schema.DisplayType.Phone ||
            fieldType == Schema.DisplayType.Url ||
            fieldType == Schema.DisplayType.EncryptedString
        ) {
            return !String.isBlank(String.valueOf(fieldValue));
        }

        // Date, DateTime, Time, Boolean, numeric, Id/reference, picklist,
        // and other typed values are populated when non-null.
        return true;
    }

    private void abortRemainingBatchWork(Database.BatchableContext bc) {
        if (bc == null || !hasReachedMergeLimit()) {
            return;
        }

        Id jobId = bc.getJobId();

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatch::abortRemainingBatchWork merge limit reached. Aborting jobId=' +
            String.valueOf(jobId) + ', mergeCount=' + String.valueOf(mergeCount) +
            ', maxMerges=' + String.valueOf(maxMerges)
        );

        if (objectType == 'Contact' && performMerge && deferredContactMergeCount > 0) {
            scheduleDeferredContactMerges(jobId);
        } else {
            DHM_JobLogService.markStoppedForMergeLimit(
                jobId,
                processedCount,
                updatedCount,
                candidateSetCount,
                mergeCount,
                errorCount
            );
        }

        // Do not abort Salesforce's asynchronous unit-test harness. The existing maxMerges
        // tests still exercise the decision path, while production stops future scopes here.
        if (!Test.isRunningTest()) {
            System.abortJob(jobId);
        }
    }

    private void scheduleDeferredContactMerges(Id batchJobId) {
        if (contactWorkerScheduled || batchJobId == null || deferredContactMergeCount <= 0) {
            return;
        }

        contactWorkerScheduled = true;
        DHM_JobLogService.markContactMergesPending(
            batchJobId,
            processedCount,
            updatedCount,
            candidateSetCount,
            errorCount
        );

        if (!Test.isRunningTest()) {
            DHM_ContactMergeWorker.scheduleFirstRun(
                batchJobId,
                batchStartedAt,
                matchFieldsCsv,
                maxMerges
            );
        }
    }

    private Boolean hasReachedMergeLimit() {
        Integer countForLimit = (objectType == 'Contact' && performMerge)
            ? deferredContactMergeCount
            : mergeCount;
        return maxMerges != null && countForLimit >= maxMerges;
    }

    private static String buildContactPairKey(Id firstId, Id secondId) {
        String first = String.valueOf(firstId);
        String second = String.valueOf(secondId);
        return first.compareTo(second) <= 0 ? first + ':' + second : second + ':' + first;
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

        if (objectType == 'Contact' && performMerge && deferredContactMergeCount > 0) {
            scheduleDeferredContactMerges(bc.getJobId());
        } else {
            DHM_JobLogService.completeFromAsyncApexJob(
                bc.getJobId(),
                processedCount,
                updatedCount,
                candidateSetCount,
                mergeCount,
                errorCount,
                mergeLimitReached
            );
        }
    }
}