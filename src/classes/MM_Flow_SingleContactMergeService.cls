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
        Id inputContactId,
        Boolean performMerge
    ) {
        return evaluateAndMerge(inputContactId, performMerge, DEFAULT_MATCH_FIELDS_CSV);
    }

    public static MM_Flow_SingleContactMerge.Result evaluateAndMerge(
        Id inputContactId,
        Boolean performMerge,
        String matchFieldsCsv
    ) {
        MM_Flow_SingleContactMerge.Result res = new MM_Flow_SingleContactMerge.Result();
        res.inputContactId = inputContactId;
        res.accountId = null;
        res.matchKey = null;
        res.masterContactId = null;
        res.duplicateContactId = null;
        res.candidateFound = false;
        res.merged = false;
        res.duplicateCount = 0;

        List<String> matchFields = parseMatchFields(matchFieldsCsv);

        String selectFields = buildContactSelectFields(matchFields);

        Contact inputContact = (Contact)Database.query(
            'SELECT ' + selectFields +
            ' FROM Contact ' +
            ' WHERE Id = :inputContactId ' +
            ' LIMIT 1'
        );

        res.accountId = inputContact.AccountId;
        res.matchKey = buildMatchKeyFromRecord(inputContact, matchFields);

        if (inputContact.AccountId == null) {
            res.message = 'Input contact is not associated with an Account.';
            return res;
        }

        if (String.isBlank(res.matchKey)) {
            res.message = 'Input contact is missing one or more required match fields.';
            return res;
        }

        MatchBundle bundle = findMatchesWithinAccount(inputContact, matchFields);

        if (bundle == null || bundle.duplicateContacts.isEmpty()) {
            res.masterContactId = inputContact.Id;
            res.message = 'No matching contacts found within the same account.';
            return res;
        }

        res.accountId = bundle.accountId;
        res.matchKey = bundle.matchKey;
        res.masterContactId = bundle.masterContact.Id;
        res.duplicateCount = bundle.duplicateContacts.size();
        res.duplicateContactId = bundle.duplicateContacts[0].Id;
        res.candidateFound = true;

        if (!performMerge) {
            res.message =
                'Candidate found. Contact ' + String.valueOf(res.duplicateContactId) +
                ' would be merged into master contact ' + String.valueOf(res.masterContactId) + '.';
            return res;
        }

        mergeContacts(bundle);

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

        new C501_MassMerge_SharedCode_Contact().ObjectsMerge(
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