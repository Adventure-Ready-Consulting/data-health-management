public without sharing class DHM_SingleAccountMergeService {

    public static final String DEFAULT_MATCH_FIELDS_CSV = 'FirstName,LastName,Birthdate';

    public class MatchBundle {
        public Id sourceAccountId;
        public Id targetAccountId;
        public List<ContactMatch> contactMatches = new List<ContactMatch>();
    }

    public class ContactMatch {
        public Contact sourceContact;
        public Contact targetContact;
    }

    public static DHM_SingleAccountMerge.Result evaluateAndMerge(
        Id sourceAccountId,
        Boolean performMerge
    ) {
        return evaluateAndMerge(sourceAccountId, performMerge, DEFAULT_MATCH_FIELDS_CSV, null);
    }

    public static DHM_SingleAccountMerge.Result evaluateAndMerge(
        Id sourceAccountId,
        Boolean performMerge,
        String matchFieldsCsv
    ) {
        return evaluateAndMerge(sourceAccountId, performMerge, matchFieldsCsv, null);
    }

    public static DHM_SingleAccountMerge.Result evaluateAndMerge(
        Id sourceAccountId,
        Boolean performMerge,
        String matchFieldsCsv,
        String contactExclusionCriteria
    ) {
        DHM_SingleAccountMerge.Result res = new DHM_SingleAccountMerge.Result();
        res.sourceAccountId = sourceAccountId;
        res.targetAccountId = null;
        res.masterAccountId = null;
        res.duplicateAccountId = null;
        res.candidateFound = false;
        res.merged = false;

        Boolean useLegacyTestMatching =
            Test.isRunningTest() && !DHM_DuplicateRuleCandidateService.hasTestCandidates();
        List<String> matchFields = parseMatchFields(matchFieldsCsv);
        if (useLegacyTestMatching) {
            validateMatchFields(matchFields);
        }

        Account sourceAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :sourceAccountId
            LIMIT 1
        ];

        Set<String> sourceFieldSet = new Set<String>{ 'Id', 'AccountId', 'CreatedDate' };
        if (useLegacyTestMatching) {
            sourceFieldSet.addAll(matchFields);
        }

        String sourceContactSelect = String.join(new List<String>(sourceFieldSet), ', ');

        Id sourceAcctId = sourceAccount.Id;

        List<Contact> sourceContacts = Database.query(
            'SELECT ' + sourceContactSelect +
            ' FROM Contact ' +
            ' WHERE AccountId = :sourceAcctId ' +
            ' ORDER BY CreatedDate, Id'
        );

        if (sourceContacts.isEmpty()) {
            res.message = 'Source account has no contacts.';
            return res;
        }

        validateContactExclusionCriteria(contactExclusionCriteria);
        if (accountMatchesContactExclusion(sourceAccount.Id, contactExclusionCriteria)) {
            res.message =
                'Account merge skipped because the source account contains a Contact matching the exclusion criteria.';
            return res;
        }

        MatchBundle matchBundle;
        if (useLegacyTestMatching) {
            matchBundle = findTargetAccountForSource(
                sourceAccount,
                sourceContacts,
                matchFields,
                contactExclusionCriteria
            );
        } else {
            matchBundle = findTargetAccountUsingDuplicateRules(
                sourceAccount,
                sourceContacts,
                contactExclusionCriteria
            );
        }

        if (matchBundle == null) {
            res.message = 'No target account found where all Contacts in one Account have distinct matches in the other Account.';
            return res;
        }

        res.targetAccountId = matchBundle.targetAccountId;
        res.masterAccountId = matchBundle.targetAccountId;
        res.duplicateAccountId = matchBundle.sourceAccountId;
        res.candidateFound = true;

        if (!performMerge) {
            res.message =
                'Candidate found. Account ' + String.valueOf(res.duplicateAccountId) +
                ' would be merged into master account ' + String.valueOf(res.masterAccountId) + '.';
            return res;
        }

        moveMatchedContactsToMaster(matchBundle);
        mergeAccounts(matchBundle.targetAccountId, matchBundle.sourceAccountId);

        res.merged = true;
        res.message =
            'Merged account ' + String.valueOf(res.duplicateAccountId) +
            ' into master account ' + String.valueOf(res.masterAccountId) + '.';

        return res;
    }

    @TestVisible
    static void moveMatchedContactsToMaster(MatchBundle bundle) {
        if (bundle == null || bundle.contactMatches.isEmpty()) {
            return;
        }

        List<Contact> updates = new List<Contact>();

        for (ContactMatch cm : bundle.contactMatches) {
            if (cm == null || cm.sourceContact == null) {
                continue;
            }

            if (cm.sourceContact.AccountId != bundle.targetAccountId) {
                updates.add(new Contact(
                    Id = cm.sourceContact.Id,
                    AccountId = bundle.targetAccountId
                ));
            }
        }

        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    @TestVisible
    static MatchBundle findTargetAccountForSource(Account sourceAccount, List<Contact> sourceContacts) {
        return findTargetAccountForSource(
            sourceAccount,
            sourceContacts,
            parseMatchFields(DEFAULT_MATCH_FIELDS_CSV),
            null
        );
    }

    @TestVisible
    static MatchBundle findTargetAccountForSource(
        Account sourceAccount,
        List<Contact> sourceContacts,
        List<String> matchFields
    ) {
        return findTargetAccountForSource(sourceAccount, sourceContacts, matchFields, null);
    }

    @TestVisible
    static MatchBundle findTargetAccountForSource(
        Account sourceAccount,
        List<Contact> sourceContacts,
        List<String> matchFields,
        String contactExclusionCriteria
    ) {
        if (sourceAccount == null || sourceAccount.Id == null ||
            sourceContacts == null || sourceContacts.isEmpty()) {
            return null;
        }

        validateMatchFields(matchFields);

        Map<String, Integer> sourceKeyCounts = new Map<String, Integer>();
        Map<String, List<Contact>> sourceContactsByKey = new Map<String, List<Contact>>();

        for (Contact con : sourceContacts) {
            String key = DHM_SingleContactMergeService.buildMatchKeyFromRecord(con, matchFields);
            if (key == null) {
                return null;
            }

            sourceKeyCounts.put(
                key,
                sourceKeyCounts.containsKey(key) ? sourceKeyCounts.get(key) + 1 : 1
            );

            if (!sourceContactsByKey.containsKey(key)) {
                sourceContactsByKey.put(key, new List<Contact>());
            }
            sourceContactsByKey.get(key).add(con);
        }

        String filterField = findFilterableMatchField(matchFields);
        Set<Object> filterValues = new Set<Object>();
        for (Contact con : sourceContacts) {
            filterValues.add(con.get(filterField));
        }

        Set<String> candidateFieldSet = new Set<String>(matchFields);
        String candidateSelect =
            DHM_SingleContactMergeService.buildContactSelectFields(
                new List<String>(candidateFieldSet)
            );

        // Dynamic SOQL bind variables must exist in this method's local scope.
        // The previous query referenced :sourceAccountId without declaring it,
        // which caused every Account matching test to fail at Database.query().
        Id sourceAccountId = sourceAccount.Id;

        String possibleTargetsSoql =
            'SELECT ' + candidateSelect + ', Account.CreatedDate' +
            ' FROM Contact' +
            ' WHERE AccountId != :sourceAccountId' +
            ' AND AccountId != null' +
            ' AND ' + filterField + ' IN (' + buildSoqlLiteralList(filterValues) + ')' +
            ' ORDER BY Account.CreatedDate ASC, AccountId ASC, CreatedDate ASC, Id ASC';

        List<Contact> possibleTargetContacts = Database.query(possibleTargetsSoql);

        Map<Id, Map<String, List<Contact>>> targetContactsByAccountAndKey =
            new Map<Id, Map<String, List<Contact>>>();

        for (Contact con : possibleTargetContacts) {
            String key = DHM_SingleContactMergeService.buildMatchKeyFromRecord(con, matchFields);
            if (!sourceKeyCounts.containsKey(key)) {
                continue;
            }

            if (!targetContactsByAccountAndKey.containsKey(con.AccountId)) {
                targetContactsByAccountAndKey.put(
                    con.AccountId,
                    new Map<String, List<Contact>>()
                );
            }

            Map<String, List<Contact>> keyed = targetContactsByAccountAndKey.get(con.AccountId);
            if (!keyed.containsKey(key)) {
                keyed.put(key, new List<Contact>());
            }
            keyed.get(key).add(con);
        }

        List<Id> candidateAccountIds = new List<Id>();
        for (Id candidateAccountId : targetContactsByAccountAndKey.keySet()) {
            if (hasRequiredKeyCounts(
                sourceKeyCounts,
                targetContactsByAccountAndKey.get(candidateAccountId)
            )) {
                candidateAccountIds.add(candidateAccountId);
            }
        }
        candidateAccountIds.sort();

        Set<Id> excludedAccountIds = findAccountIdsMatchingContactExclusion(
            new Set<Id>(candidateAccountIds),
            contactExclusionCriteria
        );

        Id winningTargetAccountId;
        for (Id candidateAccountId : candidateAccountIds) {
            if (!excludedAccountIds.contains(candidateAccountId)) {
                winningTargetAccountId = candidateAccountId;
                break;
            }
        }

        if (winningTargetAccountId == null) {
            return null;
        }

        MatchBundle bundle = new MatchBundle();
        bundle.sourceAccountId = sourceAccount.Id;
        bundle.targetAccountId = winningTargetAccountId;

        Map<String, List<Contact>> winningContactsByKey =
            targetContactsByAccountAndKey.get(winningTargetAccountId);

        for (String key : sourceContactsByKey.keySet()) {
            List<Contact> sourceForKey = sourceContactsByKey.get(key);
            List<Contact> targetForKey = winningContactsByKey.get(key);

            for (Integer i = 0; i < sourceForKey.size(); i++) {
                ContactMatch cm = new ContactMatch();
                cm.sourceContact = sourceForKey[i];
                cm.targetContact = targetForKey[i];
                bundle.contactMatches.add(cm);
            }
        }

        return bundle;
    }

    @TestVisible
    static MatchBundle findTargetAccountUsingDuplicateRules(
        Account sourceAccount,
        List<Contact> sourceContacts,
        String contactExclusionCriteria
    ) {
        if (sourceAccount == null || sourceAccount.Id == null ||
            sourceContacts == null || sourceContacts.isEmpty()) {
            return null;
        }

        // Version 2.0: Account candidates are derived entirely from Contact Duplicate Rules.
        // Account names can change with household composition, so an Account Matching Rule
        // is not a reliable way to discover household candidates. A duplicate Contact in
        // another Account is enough to nominate that Account for the full DHM household check.
        Set<Id> sourceContactIds = new Set<Id>();
        for (Contact sourceContact : sourceContacts) {
            sourceContactIds.add(sourceContact.Id);
        }

        Map<Id, Set<Id>> duplicateContactIdsBySourceId =
            DHM_DuplicateRuleCandidateService.findCandidates(sourceContactIds);

        Set<Id> possibleDuplicateContactIds = new Set<Id>();
        for (Set<Id> duplicateIds : duplicateContactIdsBySourceId.values()) {
            if (duplicateIds != null) {
                possibleDuplicateContactIds.addAll(duplicateIds);
            }
        }
        possibleDuplicateContactIds.removeAll(sourceContactIds);

        if (possibleDuplicateContactIds.isEmpty()) {
            return null;
        }

        Set<Id> accountCandidateIds = new Set<Id>();
        Id sourceAccountId = sourceAccount.Id;
        for (Contact duplicateContact : [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id IN :possibleDuplicateContactIds
              AND AccountId != null
              AND AccountId != :sourceAccountId
        ]) {
            accountCandidateIds.add(duplicateContact.AccountId);
        }

        if (accountCandidateIds.isEmpty()) {
            return null;
        }

        List<Account> candidateAccounts = [
            SELECT Id, CreatedDate,
                   (SELECT Id, AccountId, CreatedDate FROM Contacts ORDER BY CreatedDate, Id)
            FROM Account
            WHERE Id IN :accountCandidateIds
            ORDER BY CreatedDate ASC, Id ASC
        ];

        Set<Id> allCandidateAccountIds = new Set<Id>();
        for (Account candidate : candidateAccounts) {
            allCandidateAccountIds.add(candidate.Id);
        }
        Set<Id> excludedAccountIds = findAccountIdsMatchingContactExclusion(
            allCandidateAccountIds,
            contactExclusionCriteria
        );

        for (Account candidate : candidateAccounts) {
            if (excludedAccountIds.contains(candidate.Id) || candidate.Contacts.isEmpty()) {
                continue;
            }

            MatchBundle sourceIntoCandidate = buildDuplicateRuleMatchBundle(
                sourceAccount.Id,
                sourceContacts,
                candidate.Id,
                candidate.Contacts
            );
            if (sourceIntoCandidate != null) {
                return sourceIntoCandidate;
            }

            MatchBundle candidateIntoSource = buildDuplicateRuleMatchBundle(
                candidate.Id,
                candidate.Contacts,
                sourceAccount.Id,
                sourceContacts
            );
            if (candidateIntoSource != null) {
                return candidateIntoSource;
            }
        }
        return null;
    }

    private static MatchBundle buildDuplicateRuleMatchBundle(
        Id duplicateAccountId,
        List<Contact> duplicateContacts,
        Id masterAccountId,
        List<Contact> masterContacts
    ) {
        if (duplicateContacts == null || duplicateContacts.isEmpty() ||
            masterContacts == null || masterContacts.isEmpty()) {
            return null;
        }

        Set<Id> duplicateContactIds = new Set<Id>();
        for (Contact con : duplicateContacts) {
            duplicateContactIds.add(con.Id);
        }
        Map<Id, Set<Id>> rawCandidates =
            DHM_DuplicateRuleCandidateService.findCandidates(duplicateContactIds);
        Map<Id, Contact> masterContactsById = new Map<Id, Contact>(masterContacts);

        Map<Id, List<Id>> eligibleMasterIdsByDuplicateId = new Map<Id, List<Id>>();
        for (Contact duplicateContact : duplicateContacts) {
            List<Id> eligibleIds = new List<Id>();
            Set<Id> possibleIds = rawCandidates.get(duplicateContact.Id);
            if (possibleIds != null) {
                for (Id possibleId : possibleIds) {
                    if (masterContactsById.containsKey(possibleId)) {
                        eligibleIds.add(possibleId);
                    }
                }
            }
            eligibleIds.sort();
            if (eligibleIds.isEmpty()) {
                return null;
            }
            eligibleMasterIdsByDuplicateId.put(duplicateContact.Id, eligibleIds);
        }

        Map<Id, Id> duplicateIdByMasterId = new Map<Id, Id>();
        List<Id> orderedDuplicateIds = new List<Id>(duplicateContactIds);
        orderedDuplicateIds.sort();
        for (Id duplicateContactId : orderedDuplicateIds) {
            if (!assignDistinctMasterContact(
                duplicateContactId,
                eligibleMasterIdsByDuplicateId,
                duplicateIdByMasterId,
                new Set<Id>()
            )) {
                return null;
            }
        }

        Map<Id, Id> masterIdByDuplicateId = new Map<Id, Id>();
        for (Id masterContactId : duplicateIdByMasterId.keySet()) {
            masterIdByDuplicateId.put(
                duplicateIdByMasterId.get(masterContactId),
                masterContactId
            );
        }

        Map<Id, Contact> duplicateContactsById = new Map<Id, Contact>(duplicateContacts);
        MatchBundle bundle = new MatchBundle();
        bundle.sourceAccountId = duplicateAccountId;
        bundle.targetAccountId = masterAccountId;
        for (Id duplicateContactId : orderedDuplicateIds) {
            ContactMatch cm = new ContactMatch();
            cm.sourceContact = duplicateContactsById.get(duplicateContactId);
            cm.targetContact = masterContactsById.get(
                masterIdByDuplicateId.get(duplicateContactId)
            );
            bundle.contactMatches.add(cm);
        }
        return bundle;
    }

    private static Boolean assignDistinctMasterContact(
        Id duplicateContactId,
        Map<Id, List<Id>> eligibleMasterIdsByDuplicateId,
        Map<Id, Id> duplicateIdByMasterId,
        Set<Id> visitedMasterIds
    ) {
        for (Id masterContactId : eligibleMasterIdsByDuplicateId.get(duplicateContactId)) {
            if (visitedMasterIds.contains(masterContactId)) {
                continue;
            }
            visitedMasterIds.add(masterContactId);

            Id currentlyAssignedDuplicateId = duplicateIdByMasterId.get(masterContactId);
            if (currentlyAssignedDuplicateId == null ||
                assignDistinctMasterContact(
                    currentlyAssignedDuplicateId,
                    eligibleMasterIdsByDuplicateId,
                    duplicateIdByMasterId,
                    visitedMasterIds
                )) {
                duplicateIdByMasterId.put(masterContactId, duplicateContactId);
                return true;
            }
        }
        return false;
    }

    @TestVisible
    static Boolean hasRequiredKeyCounts(
        Map<String, Integer> sourceKeyCounts,
        Map<String, List<Contact>> targetContactsByKey
    ) {
        if (sourceKeyCounts == null || targetContactsByKey == null) {
            return false;
        }

        for (String key : sourceKeyCounts.keySet()) {
            if (!targetContactsByKey.containsKey(key) ||
                targetContactsByKey.get(key).size() < sourceKeyCounts.get(key)) {
                return false;
            }
        }
        return true;
    }

    @TestVisible
    static Boolean accountMatchesContactExclusion(Id accountId, String criteria) {
        if (accountId == null || String.isBlank(criteria)) {
            return false;
        }
        return !findAccountIdsMatchingContactExclusion(
            new Set<Id>{ accountId },
            criteria
        ).isEmpty();
    }

    @TestVisible
    static Set<Id> findAccountIdsMatchingContactExclusion(
        Set<Id> accountIds,
        String criteria
    ) {
        Set<Id> result = new Set<Id>();
        if (accountIds == null || accountIds.isEmpty() || String.isBlank(criteria)) {
            return result;
        }

        String normalizedCriteria = validateContactExclusionCriteria(criteria);
        String soql =
            'SELECT Id, AccountId FROM Contact ' +
            'WHERE AccountId IN :accountIds AND (' + normalizedCriteria + ')';

        for (Contact con : Database.query(soql)) {
            result.add(con.AccountId);
        }
        return result;
    }

    @TestVisible
    static String validateContactExclusionCriteria(String criteria) {
        if (String.isBlank(criteria)) {
            return null;
        }

        String trimmed = criteria.trim();
        if (trimmed.length() > 1000) {
            throw new IllegalArgumentException('Contact exclusion criteria cannot exceed 1000 characters.');
        }

        String upper = trimmed.toUpperCase();
        List<String> forbidden = new List<String>{
            'SELECT', 'FROM', 'LIMIT', 'OFFSET', 'ORDER', 'GROUP', 'HAVING',
            'WITH', 'FOR', 'UPDATE', 'USING', 'SCOPE', 'TYPEOF', 'LIKE', 'IN',
            'NOT', 'CLUDES', 'EXCLUDES'
        };
        for (String keyword : forbidden) {
            if (Pattern.compile('(^|[^A-Z0-9_])' + keyword + '([^A-Z0-9_]|$)')
                .matcher(upper).find()) {
                throw new IllegalArgumentException(
                    'Unsupported keyword in Contact exclusion criteria: ' + keyword
                );
            }
        }
        if (trimmed.contains(';') || trimmed.contains('--') ||
            trimmed.contains('/*') || trimmed.contains('*/') ||
            trimmed.contains(':')) {
            throw new IllegalArgumentException('Unsafe token in Contact exclusion criteria.');
        }

        List<String> tokens = tokenizeCriteria(trimmed);
        CriteriaParser parser = new CriteriaParser(tokens);
        parser.parseExpression();
        if (parser.hasMore()) {
            throw new IllegalArgumentException(
                'Unexpected token in Contact exclusion criteria: ' + parser.peek()
            );
        }
        return trimmed;
    }

    private class CriteriaParser {
        private List<String> tokens;
        private Integer position = 0;
        private Map<String, Schema.SObjectField> contactFields =
            Schema.SObjectType.Contact.fields.getMap();

        CriteriaParser(List<String> tokens) {
            this.tokens = tokens;
        }

        Boolean hasMore() {
            return position < tokens.size();
        }

        String peek() {
            return hasMore() ? tokens[position] : null;
        }

        String consume() {
            return tokens[position++];
        }

        void parseExpression() {
            parseTerm();
            while (hasMore() && peek().equalsIgnoreCase('OR')) {
                consume();
                parseTerm();
            }
        }

        void parseTerm() {
            parseFactor();
            while (hasMore() && peek().equalsIgnoreCase('AND')) {
                consume();
                parseFactor();
            }
        }

        void parseFactor() {
            if (hasMore() && peek() == '(') {
                consume();
                parseExpression();
                require(')');
                return;
            }
            parseComparison();
        }

        void parseComparison() {
            if (!hasMore()) {
                throw new IllegalArgumentException('Expected a Contact field name.');
            }
            String fieldName = consume();
            if (!contactFields.containsKey(fieldName)) {
                throw new IllegalArgumentException(
                    'Invalid Contact field in exclusion criteria: ' + fieldName
                );
            }
            if (!contactFields.get(fieldName).getDescribe().isFilterable()) {
                throw new IllegalArgumentException(
                    'Contact field is not filterable: ' + fieldName
                );
            }

            if (!hasMore()) {
                throw new IllegalArgumentException('Expected a comparison operator after ' + fieldName + '.');
            }
            String operatorToken = consume();
            if (!new Set<String>{ '=', '!=', '<', '<=', '>', '>=' }.contains(operatorToken)) {
                throw new IllegalArgumentException('Unsupported comparison operator: ' + operatorToken);
            }

            if (!hasMore()) {
                throw new IllegalArgumentException('Expected a literal value after ' + operatorToken + '.');
            }
            String literal = consume();
            validateLiteral(literal);
        }

        void require(String expected) {
            if (!hasMore() || peek() != expected) {
                throw new IllegalArgumentException('Expected ' + expected + ' in Contact exclusion criteria.');
            }
            consume();
        }

        void validateLiteral(String token) {
            String upperToken = token.toUpperCase();
            if (upperToken == 'NULL' || upperToken == 'TRUE' || upperToken == 'FALSE') {
                return;
            }
            if (token.startsWith('\'') && token.endsWith('\'')) {
                return;
            }
            if (Pattern.matches('^-?[0-9]+(\\.[0-9]+)?$', token)) {
                return;
            }
            if (Pattern.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$', token)) {
                return;
            }
            throw new IllegalArgumentException('Unsupported literal value: ' + token);
        }
    }

    @TestVisible
    static List<String> tokenizeCriteria(String criteria) {
        List<String> tokens = new List<String>();
        Integer i = 0;
        while (i < criteria.length()) {
            String ch = criteria.substring(i, i + 1);
            if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
                i++;
                continue;
            }
            if (ch == '(' || ch == ')') {
                tokens.add(ch);
                i++;
                continue;
            }
            if (ch == '<' || ch == '>' || ch == '!' || ch == '=') {
                String op = ch;
                if (i + 1 < criteria.length() && criteria.substring(i + 1, i + 2) == '=') {
                    op += '=';
                    i++;
                }
                tokens.add(op);
                i++;
                continue;
            }
            if (ch == '\'') {
                Integer start = i;
                i++;
                Boolean closed = false;
                while (i < criteria.length()) {
                    if (criteria.substring(i, i + 1) == '\'') {
                        if (i + 1 < criteria.length() && criteria.substring(i + 1, i + 2) == '\'') {
                            i += 2;
                            continue;
                        }
                        i++;
                        closed = true;
                        break;
                    }
                    i++;
                }
                if (!closed) {
                    throw new IllegalArgumentException('Unterminated string literal in Contact exclusion criteria.');
                }
                tokens.add(criteria.substring(start, i));
                continue;
            }

            Integer start = i;
            while (i < criteria.length()) {
                String current = criteria.substring(i, i + 1);
                if (current == ' ' || current == '\t' || current == '\r' || current == '\n' ||
                    current == '(' || current == ')' || current == '<' || current == '>' ||
                    current == '!' || current == '=') {
                    break;
                }
                i++;
            }
            if (start == i) {
                throw new IllegalArgumentException('Invalid character in Contact exclusion criteria.');
            }
            tokens.add(criteria.substring(start, i));
        }
        if (tokens.isEmpty()) {
            throw new IllegalArgumentException('Contact exclusion criteria is empty.');
        }
        return tokens;
    }

    @TestVisible
    static String findFilterableMatchField(List<String> matchFields) {
        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        for (String fieldName : matchFields) {
            Schema.SObjectField fieldToken = contactFields.get(fieldName);
            if (fieldToken != null && fieldToken.getDescribe().isFilterable()) {
                return fieldName;
            }
        }
        throw new IllegalArgumentException('At least one Contact match field must be filterable.');
    }

    @TestVisible
    static void validateMatchFields(List<String> matchFields) {
        if (matchFields == null || matchFields.isEmpty()) {
            throw new IllegalArgumentException('At least one Contact match field is required.');
        }

        Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
        Set<String> seen = new Set<String>();
        for (String fieldName : matchFields) {
            if (String.isBlank(fieldName) || !contactFields.containsKey(fieldName)) {
                throw new IllegalArgumentException('Invalid Contact match field: ' + fieldName);
            }
            if (seen.contains(fieldName)) {
                throw new IllegalArgumentException('Duplicate Contact match field: ' + fieldName);
            }
            seen.add(fieldName);
        }
    }

    @TestVisible
    static String buildSoqlLiteralList(Set<Object> values) {
        List<String> literals = new List<String>();
        for (Object value : values) {
            literals.add(toSoqlLiteral(value));
        }
        literals.sort();
        return String.join(literals, ',');
    }

    @TestVisible
    static String toSoqlLiteral(Object value) {
        if (value == null) {
            return 'null';
        }
        if (value instanceof Date) {
            return String.valueOf((Date)value);
        }
        if (value instanceof Datetime) {
            return ((Datetime)value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        }
        if (value instanceof Boolean || value instanceof Integer ||
            value instanceof Long || value instanceof Decimal || value instanceof Double) {
            return String.valueOf(value);
        }
        return '\'' + String.escapeSingleQuotes(String.valueOf(value)) + '\'';
    }

    @TestVisible
    static void mergeAccounts(Id targetAccountId, Id sourceAccountId) {
        Account target = [SELECT Id FROM Account WHERE Id = :targetAccountId LIMIT 1];
        Account source = [SELECT Id FROM Account WHERE Id = :sourceAccountId LIMIT 1];

        new DHM_SharedCode_Account().ObjectsMerge(
            target,
            new List<Account>{ source }
        );
    }

    @TestVisible
    static List<String> parseMatchFields(String matchFieldsCsv) {
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
}