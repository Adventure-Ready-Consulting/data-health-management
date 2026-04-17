public without sharing class MM_Flow_SingleContactMergeService {

    public static final String DEFAULT_MATCH_FIELDS_CSV = 'FirstName,LastName,Birthdate';

    public class MatchBundle {
        public Id accountId;
        public String matchKey;
        public Contact masterContact;
        public List<Contact> duplicateContacts = new List<Contact>();
        public List<Contact> allMatchingContacts = new List<Contact>();
    }

    public static MM_Flow_SingleContactMerge.Result evaluateAndMerge(
        Id sourceContactId,
        Boolean performMerge
    ) {
        return evaluateAndMerge(sourceContactId, performMerge, DEFAULT_MATCH_FIELDS_CSV);
    }
    
    public static MM_Flow_SingleContactMerge.Result evaluateAndMerge(
        Id sourceContactId,
        Boolean performMerge,
        String matchFieldsCsv
    ) {
        MM_Flow_SingleContactMerge.Result res = new MM_Flow_SingleContactMerge.Result();
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
    
        List<String> matchFields = parseMatchFields(matchFieldsCsv);
        String sourceContactSelect = buildContactSelectFields(matchFields);
    
        List<Contact> sourceContacts = Database.query(
            'SELECT ' + sourceContactSelect +
            ' FROM Contact ' +
            ' WHERE Id = :sourceContactId ' +
            ' LIMIT 1'
        );
    
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
    
        String sourceKey = buildMatchKeyFromRecord(sourceContact, matchFields);
        if (String.isBlank(sourceKey)) {
            res.message = 'Input contact is missing one or more required match fields.';
            return res;
        }
    
        String candidateSelect = buildContactSelectFields(matchFields);

        Id sourceId = sourceContact.Id;
        Id sourceAccountId = sourceContact.AccountId;
        
        List<Contact> candidateContacts = Database.query(
            'SELECT ' + candidateSelect +
            ' FROM Contact ' +
            ' WHERE Id != :sourceId' +
            ' AND AccountId = :sourceAccountId'
        );
            
        List<Contact> matches = new List<Contact>();
        for (Contact candidate : candidateContacts) {
            String candidateKey = buildMatchKeyFromRecord(candidate, matchFields);
            if (candidateKey == sourceKey) {
                matches.add(candidate);
            }
        }
    
        if (matches.isEmpty()) {
            res.masterContactId = sourceContact.Id;
            res.duplicateCount = 0;
            res.message = 'No matching contacts found within the same account.';
            return res;
        }
    
        Contact winningMaster = sourceContact;
        Contact winningDuplicate = matches[0];
    
        List<Id> compareIds = new List<Id>{ sourceContact.Id, winningDuplicate.Id };
        List<Contact> compareContacts = [
            SELECT Id, CreatedDate
            FROM Contact
            WHERE Id IN :compareIds
            ORDER BY CreatedDate ASC, Id ASC
        ];
    
        if (!compareContacts.isEmpty()) {
            winningMaster = compareContacts[0];
            winningDuplicate =
                (compareContacts[0].Id == sourceContact.Id)
                ? matches[0]
                : sourceContact;
        }
    
        res.candidateFound = true;
        res.masterContactId = winningMaster.Id;
        res.duplicateContactId = winningDuplicate.Id;
        res.duplicateCount = matches.size();
    
        if (!performMerge) {
            res.message =
                'Candidate found. Contact ' + String.valueOf(res.duplicateContactId) +
                ' would be merged into master contact ' + String.valueOf(res.masterContactId) + '.';
            return res;
        }
    
        new MassMerge_SharedCode_Contact().ObjectsMerge(
            winningMaster,
            new List<Contact>{ winningDuplicate }
        );
    
        res.merged = true;
        res.message =
            'Merged contact ' + String.valueOf(res.duplicateContactId) +
            ' into master contact ' + String.valueOf(res.masterContactId) + '.';
    
        return res;
    }
    
    @TestVisible
    static MatchBundle findMatchesWithinAccount(Contact inputContact) {
        return findMatchesWithinAccount(inputContact, parseMatchFields(DEFAULT_MATCH_FIELDS_CSV));
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
            ' ORDER BY CreatedDate ASC, Id ASC';

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

        new MassMerge_SharedCode_Contact().ObjectsMerge(
            bundle.masterContact,
            bundle.duplicateContacts
        );
    }

    public static List<String> parseMatchFields(String matchFieldsCsv) {
        List<String> matchFields = new List<String>();

        String effectiveCsv = String.isBlank(matchFieldsCsv)
            ? DEFAULT_MATCH_FIELDS_CSV
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
            'Id', 'AccountId', 'CreatedDate'
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