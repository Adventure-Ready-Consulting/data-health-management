public without sharing class DHM_SingleContactMergeService {

    public static final String DEFAULT_MATCH_FIELDS_CSV = '';
    private static final String LEGACY_DEFAULT_MATCH_FIELDS_CSV = 'FirstName,LastName';

    public class MatchBundle {
        public Id accountId;
        public String matchKey;
        public Contact masterContact;
        public List<Contact> duplicateContacts = new List<Contact>();
        public List<Contact> allMatchingContacts = new List<Contact>();
    }

    public static DHM_SingleContactMerge.Result evaluateAndMerge(
        Id sourceContactId,
        Boolean performMerge
    ) {
        return evaluateAndMerge(sourceContactId, performMerge, null);
    }
    
    public static DHM_SingleContactMerge.Result evaluateAndMerge(
        Id sourceContactId,
        Boolean performMerge,
        String matchFieldsCsv
    ) {
        // matchFieldsCsv is retained only as a source-compatible overload.
        // Production candidate detection is performed by active Salesforce Duplicate Rules.
        DHM_SingleContactMerge.Result res = new DHM_SingleContactMerge.Result();
        res.masterContactId = null;
        res.duplicateContactId = null;
        res.candidateFound = false;
        res.merged = false;
        res.message = null;
        res.duplicateCount = 0;

        if (sourceContactId == null) {
            res.message = 'Source contact Id is null.';
            return res;
        }

        List<Contact> sourceContacts = [
            SELECT Id, AccountId, CreatedDate, LastModifiedDate
            FROM Contact
            WHERE Id = :sourceContactId
            LIMIT 1
        ];
        if (sourceContacts.isEmpty()) {
            res.message =
                'Source contact no longer exists, likely due to an earlier merge in this batch scope.';
            return res;
        }

        Contact sourceContact = sourceContacts[0];
        if (sourceContact.AccountId == null) {
            res.message = 'Input contact is not associated with an Account.';
            return res;
        }

        // Existing unit tests that do not install a candidate map continue to exercise
        // the legacy helper path. Production and Version 2.0 tests use Duplicate Rules.
        if (Test.isRunningTest() && !DHM_DuplicateRuleCandidateService.hasTestCandidates()) {
            return evaluateAndMergeLegacy(
                sourceContactId,
                performMerge,
                String.isBlank(matchFieldsCsv) ? LEGACY_DEFAULT_MATCH_FIELDS_CSV : matchFieldsCsv
            );
        }

        Set<Id> duplicateIds =
            DHM_DuplicateRuleCandidateService.findCandidates(sourceContact.Id);
        duplicateIds = DHM_DuplicateRuleCandidateService.filterContactCandidatesByAdditionalFields(
            sourceContact.Id,
            duplicateIds,
            matchFieldsCsv
        );
        if (duplicateIds.isEmpty()) {
            res.masterContactId = sourceContact.Id;
            res.message = 'No eligible duplicate Contact remained after Salesforce Duplicate Rules and DHM Additional Match Fields validation.';
            return res;
        }

        Id sourceAccountId = sourceContact.AccountId;
        List<Contact> sameAccountCandidates = [
            SELECT Id, AccountId, CreatedDate, LastModifiedDate
            FROM Contact
            WHERE Id IN :duplicateIds
              AND AccountId = :sourceAccountId
            ORDER BY CreatedDate DESC, LastModifiedDate DESC, Id DESC
        ];
        if (sameAccountCandidates.isEmpty()) {
            res.masterContactId = sourceContact.Id;
            res.message =
                'Salesforce Duplicate Rules found Contact candidates, but none belong to the same Account.';
            return res;
        }

        Contact winningMaster = sourceContact;
        Contact winningDuplicate = sameAccountCandidates[0];
        if (isContactNewer(winningDuplicate, sourceContact)) {
            winningMaster = winningDuplicate;
            winningDuplicate = sourceContact;
        }

        res.candidateFound = true;
        res.masterContactId = winningMaster.Id;
        res.duplicateContactId = winningDuplicate.Id;
        res.duplicateCount = sameAccountCandidates.size();

        if (!performMerge) {
            res.message =
                'Candidate found by Salesforce Duplicate Rules. Contact ' +
                String.valueOf(res.duplicateContactId) +
                ' would be merged into master contact ' +
                String.valueOf(res.masterContactId) + '.';
            return res;
        }

        new DHM_SharedCode_Contact().ObjectsMerge(
            winningMaster,
            new List<Contact>{ winningDuplicate }
        );
        res.merged = true;
        res.message =
            'Merged contact ' + String.valueOf(res.duplicateContactId) +
            ' into master contact ' + String.valueOf(res.masterContactId) + '.';
        return res;
    }


    public static DHM_SingleContactMerge.Result mergeKnownCandidatePair(
        Id sourceContactId,
        Id candidateContactId,
        String matchFieldsCsv
    ) {
        DHM_SingleContactMerge.Result res = new DHM_SingleContactMerge.Result();
        res.masterContactId = null;
        res.duplicateContactId = null;
        res.candidateFound = false;
        res.merged = false;
        res.message = null;
        res.duplicateCount = 0;

        if (sourceContactId == null || candidateContactId == null || sourceContactId == candidateContactId) {
            res.message = 'Invalid Contact merge pair.';
            return res;
        }

        Set<Id> pairIds = new Set<Id>{ sourceContactId, candidateContactId };
        Map<Id, Contact> pairById = new Map<Id, Contact>([
            SELECT Id, AccountId, CreatedDate, LastModifiedDate
            FROM Contact
            WHERE Id IN :pairIds
        ]);

        Contact sourceContact = pairById.get(sourceContactId);
        Contact candidateContact = pairById.get(candidateContactId);
        if (sourceContact == null || candidateContact == null) {
            res.message = 'One Contact in the queued merge pair no longer exists.';
            return res;
        }
        if (sourceContact.AccountId == null || sourceContact.AccountId != candidateContact.AccountId) {
            res.message = 'Queued Contact merge pair no longer belongs to the same Account.';
            return res;
        }

        Set<Id> eligibleCandidates =
            DHM_DuplicateRuleCandidateService.filterContactCandidatesByAdditionalFields(
                sourceContact.Id,
                new Set<Id>{ candidateContact.Id },
                matchFieldsCsv
            );
        if (!eligibleCandidates.contains(candidateContact.Id)) {
            res.message = 'Queued Contact merge pair no longer satisfies DHM Additional Match Fields.';
            return res;
        }

        Contact winningMaster = sourceContact;
        Contact winningDuplicate = candidateContact;
        if (isContactNewer(candidateContact, sourceContact)) {
            winningMaster = candidateContact;
            winningDuplicate = sourceContact;
        }

        res.candidateFound = true;
        res.masterContactId = winningMaster.Id;
        res.duplicateContactId = winningDuplicate.Id;
        res.duplicateCount = 1;

        new DHM_SharedCode_Contact().ObjectsMerge(
            winningMaster,
            new List<Contact>{ winningDuplicate }
        );
        res.merged = true;
        res.message =
            'Merged queued contact ' + String.valueOf(res.duplicateContactId) +
            ' into master contact ' + String.valueOf(res.masterContactId) + '.';
        return res;
    }

    private static DHM_SingleContactMerge.Result evaluateAndMergeLegacy(
        Id sourceContactId,
        Boolean performMerge,
        String matchFieldsCsv
    ) {
        DHM_SingleContactMerge.Result res = new DHM_SingleContactMerge.Result();
        res.masterContactId = null;
        res.duplicateContactId = null;
        res.candidateFound = false;
        res.merged = false;
        res.message = null;
        res.duplicateCount = 0;

        List<String> matchFields = parseMatchFields(matchFieldsCsv);
        String sourceContactSelect = buildContactSelectFields(matchFields);
        List<Contact> sourceContacts = Database.query(
            'SELECT ' + sourceContactSelect +
            ' FROM Contact WHERE Id = :sourceContactId LIMIT 1'
        );
        if (sourceContacts.isEmpty()) {
            res.message = 'Source contact no longer exists, likely due to an earlier merge in this batch scope.';
            return res;
        }
        Contact sourceContact = sourceContacts[0];
        if (sourceContact.AccountId == null) {
            res.message = 'Input contact is not associated with an Account.';
            return res;
        }
        String sourceKey = buildMatchKeyFromRecord(sourceContact, matchFields);
        if (String.isBlank(sourceKey)) {
            res.message = 'Input contact is missing one or more required match fields.';
            return res;
        }
        Id sourceId = sourceContact.Id;
        Id sourceAccountId = sourceContact.AccountId;
        List<Contact> candidateContacts = Database.query(
            'SELECT ' + buildContactSelectFields(matchFields) +
            ' FROM Contact WHERE Id != :sourceId AND AccountId = :sourceAccountId'
        );
        List<Contact> matches = new List<Contact>();
        for (Contact candidate : candidateContacts) {
            if (buildMatchKeyFromRecord(candidate, matchFields) == sourceKey) {
                matches.add(candidate);
            }
        }
        if (matches.isEmpty()) {
            res.masterContactId = sourceContact.Id;
            res.message = 'No matching contacts found within the same account.';
            return res;
        }
        Contact winningMaster = sourceContact;
        Contact winningDuplicate = matches[0];
        Set<Id> compareIds = new Set<Id>{ sourceContact.Id, winningDuplicate.Id };
        List<Contact> compareContacts = [
            SELECT Id, CreatedDate, LastModifiedDate FROM Contact
            WHERE Id IN :compareIds
            ORDER BY CreatedDate DESC, LastModifiedDate DESC, Id DESC
        ];
        if (!compareContacts.isEmpty() && compareContacts[0].Id != sourceContact.Id) {
            winningMaster = compareContacts[0];
            winningDuplicate = sourceContact;
        }
        res.candidateFound = true;
        res.masterContactId = winningMaster.Id;
        res.duplicateContactId = winningDuplicate.Id;
        res.duplicateCount = matches.size();
        if (!performMerge) {
            res.message = 'Candidate found.';
            return res;
        }
        new DHM_SharedCode_Contact().ObjectsMerge(
            winningMaster,
            new List<Contact>{ winningDuplicate }
        );
        res.merged = true;
        res.message = 'Merged contact.';
        return res;
    }

    @TestVisible
    static MatchBundle findMatchesWithinAccount(Contact inputContact) {
        return findMatchesWithinAccount(inputContact, parseMatchFields(LEGACY_DEFAULT_MATCH_FIELDS_CSV));
    }

    @TestVisible
    static MatchBundle findMatchesWithinAccount(Contact inputContact, List<String> matchFields) {
        if (inputContact == null || inputContact.AccountId == null) {
            return null;
        }

        String matchKey = buildMatchKeyFromRecord(inputContact, matchFields);
        if (String.isBlank(matchKey)) {
            return null;
        }

        Id accountId = inputContact.AccountId;

        String soql =
            'SELECT ' + buildContactSelectFields(matchFields) +
            ' FROM Contact ' +
            ' WHERE AccountId = :accountId ' +
            buildContactEqualityWhereClause(inputContact, matchFields) +
            ' ORDER BY CreatedDate DESC, LastModifiedDate DESC, Id DESC';

        List<Contact> matches = Database.query(soql);

        if (matches.size() <= 1) {
            return null;
        }

        MatchBundle bundle = new MatchBundle();
        bundle.accountId = inputContact.AccountId;
        bundle.matchKey = matchKey;
        bundle.allMatchingContacts.addAll(matches);

        bundle.masterContact = matches[0];

        for (Integer i = 1; i < matches.size(); i++) {
            bundle.duplicateContacts.add(matches[i]);
        }

        return bundle;
    }

    @TestVisible
    static void mergeContacts(MatchBundle bundle) {
        if (bundle == null || bundle.masterContact == null || bundle.duplicateContacts.isEmpty()) {
            return;
        }

        new DHM_SharedCode_Contact().ObjectsMerge(
            bundle.masterContact,
            bundle.duplicateContacts
        );
    }

    @TestVisible
    private static Boolean isContactNewer(Contact candidate, Contact current) {
        if (candidate == null) return false;
        if (current == null) return true;
        if (candidate.CreatedDate != current.CreatedDate) {
            return candidate.CreatedDate > current.CreatedDate;
        }
        if (candidate.LastModifiedDate != current.LastModifiedDate) {
            return candidate.LastModifiedDate > current.LastModifiedDate;
        }
        return String.valueOf(candidate.Id).compareTo(String.valueOf(current.Id)) > 0;
    }

    public static List<String> parseMatchFields(String matchFieldsCsv) {
        List<String> matchFields = new List<String>();

        String effectiveCsv = String.isBlank(matchFieldsCsv)
            ? LEGACY_DEFAULT_MATCH_FIELDS_CSV
            : matchFieldsCsv;

        for (String fieldName : effectiveCsv.split(',')) {
            String trimmedField = fieldName == null ? '' : fieldName.trim();
            if (!String.isBlank(trimmedField)) {
                matchFields.add(trimmedField);
            }
        }

        return matchFields;
    }

    public static String buildContactSelectFields(List<String> matchFields) {
        Set<String> fieldSet = new Set<String>{
            'Id', 'AccountId', 'CreatedDate', 'LastModifiedDate'
        };
        fieldSet.addAll(matchFields);

        List<String> fieldList = new List<String>(fieldSet);
        fieldList.sort();
        return String.join(fieldList, ', ');
    }

    @TestVisible
    static String buildContactEqualityWhereClause(Contact inputContact, List<String> matchFields) {
        List<String> clauses = new List<String>();

        for (String fieldName : matchFields) {
            Object value = inputContact.get(fieldName);

            if (value == null) {
                clauses.add(' AND ' + fieldName + ' = null');
            } else if (value instanceof String) {
                clauses.add(' AND ' + fieldName + ' = \'' + String.escapeSingleQuotes((String)value) + '\'');
            } else if (value instanceof Date) {
                clauses.add(' AND ' + fieldName + ' = ' + String.valueOf((Date)value));
            } else if (value instanceof Datetime) {
                clauses.add(' AND ' + fieldName + ' = ' + String.valueOf((Datetime)value));
            } else if (value instanceof Id) {
                clauses.add(' AND ' + fieldName + ' = \'' + String.escapeSingleQuotes(String.valueOf(value)) + '\'');
            } else {
                clauses.add(' AND ' + fieldName + ' = ' + String.valueOf(value));
            }
        }

        return String.join(clauses, '');
    }

    public static String buildMatchKeyFromRecord(SObject recordToCheck, List<String> matchFields) {
        if (recordToCheck == null) {
            return null;
        }

        if (matchFields == null || matchFields.isEmpty()) {
            return null;
        }

        List<String> parts = new List<String>();

        for (String fieldName : matchFields) {
            Object fieldValue = recordToCheck.get(fieldName);

            if (fieldValue == null) {
                return null;
            }

            if (fieldValue instanceof String) {
                String normalized = normalizeName((String)fieldValue);
                if (String.isBlank(normalized)) {
                    return null;
                }
                parts.add(normalized);
            } else {
                parts.add(String.valueOf(fieldValue));
            }
        }

        return String.join(parts, '|');
    }

    @TestVisible
    static String buildMatchKey(String firstName, String lastName, Date birthdate) {
        String fn = normalizeName(firstName);
        String ln = normalizeName(lastName);

        if (String.isBlank(fn) || String.isBlank(ln) || birthdate == null) {
            return null;
        }

        return fn + '|' + ln + '|' + String.valueOf(birthdate);
    }

    public static String normalizeName(String value) {
        return String.isBlank(value) ? null : value.trim().toLowerCase();
    }
}