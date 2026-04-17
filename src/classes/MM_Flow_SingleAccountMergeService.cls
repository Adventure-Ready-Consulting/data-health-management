public without sharing class MM_Flow_SingleAccountMergeService {

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

    public static MM_Flow_SingleAccountMerge.Result evaluateAndMerge(
        Id sourceAccountId,
        Boolean performMerge
    ) {
        return evaluateAndMerge(sourceAccountId, performMerge, DEFAULT_MATCH_FIELDS_CSV);
    }

    public static MM_Flow_SingleAccountMerge.Result evaluateAndMerge(
        Id sourceAccountId,
        Boolean performMerge,
        String matchFieldsCsv
    ) {
        MM_Flow_SingleAccountMerge.Result res = new MM_Flow_SingleAccountMerge.Result();
        res.sourceAccountId = sourceAccountId;
        res.targetAccountId = null;
        res.masterAccountId = null;
        res.duplicateAccountId = null;
        res.candidateFound = false;
        res.merged = false;

        List<String> matchFields = parseMatchFields(matchFieldsCsv);

        Account sourceAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :sourceAccountId
            LIMIT 1
        ];

        String sourceContactSelect =
            MM_Flow_SingleContactMergeService.buildContactSelectFields(matchFields);

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

        MatchBundle matchBundle = findTargetAccountForSource(sourceAccount, sourceContacts, matchFields);

        if (matchBundle == null) {
            res.message = 'No target account found where all source contacts match on required fields.';
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

        // 🔥 CHANGED: no more contact merge
        moveMatchedContactsToMaster(matchBundle);

        // Account merge still happens
        mergeAccounts(matchBundle.targetAccountId, matchBundle.sourceAccountId);

        res.merged = true;
        res.message =
            'Merged account ' + String.valueOf(res.duplicateAccountId) +
            ' into master account ' + String.valueOf(res.masterAccountId) + '.';

        return res;
    }

    // 🔥 NEW METHOD (replaces mergeMatchedContacts)
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
            parseMatchFields(DEFAULT_MATCH_FIELDS_CSV)
        );
    }

    @TestVisible
    static MatchBundle findTargetAccountForSource(
        Account sourceAccount,
        List<Contact> sourceContacts,
        List<String> matchFields
    ) {
        if (sourceAccount == null || sourceAccount.Id == null || sourceContacts == null || sourceContacts.isEmpty()) {
            return null;
        }

        Set<String> sourceKeys = new Set<String>();
        for (Contact con : sourceContacts) {
            String key = MM_Flow_SingleContactMergeService.buildMatchKeyFromRecord(con, matchFields);
            if (key == null) {
                return null;
            }
            sourceKeys.add(key);
        }

        Set<String> firstNames = new Set<String>();
        Set<String> lastNames = new Set<String>();
        Set<Date> birthdates = new Set<Date>();

        for (Contact con : sourceContacts) {
            firstNames.add(MM_Flow_SingleContactMergeService.normalizeName((String)con.get('FirstName')));
            lastNames.add(MM_Flow_SingleContactMergeService.normalizeName((String)con.get('LastName')));
            birthdates.add((Date)con.get('Birthdate'));
        }

        List<Contact> possibleTargetContacts = [
            SELECT Id, AccountId, FirstName, LastName, Birthdate, CreatedDate, Account.CreatedDate
            FROM Contact
            WHERE AccountId != :sourceAccount.Id
            AND AccountId != null
            AND FirstName IN :firstNames
            AND LastName IN :lastNames
            AND Birthdate IN :birthdates
            ORDER BY Account.CreatedDate ASC, AccountId ASC, CreatedDate ASC, Id ASC
        ];

        Map<Id, Map<String, Contact>> targetContactsByAccountAndKey = new Map<Id, Map<String, Contact>>();

        for (Contact con : possibleTargetContacts) {
            String key = MM_Flow_SingleContactMergeService.buildMatchKeyFromRecord(con, matchFields);
            if (!sourceKeys.contains(key)) {
                continue;
            }

            if (!targetContactsByAccountAndKey.containsKey(con.AccountId)) {
                targetContactsByAccountAndKey.put(con.AccountId, new Map<String, Contact>());
            }

            Map<String, Contact> keyed = targetContactsByAccountAndKey.get(con.AccountId);

            if (!keyed.containsKey(key)) {
                keyed.put(key, con);
            }
        }

        Id winningTargetAccountId;

        List<Id> candidateAccountIds = new List<Id>(targetContactsByAccountAndKey.keySet());
        candidateAccountIds.sort();

        for (Id candidateAccountId : candidateAccountIds) {
            if (targetContactsByAccountAndKey.get(candidateAccountId).size() == sourceKeys.size()) {
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

        Map<String, Contact> winningContactsByKey = targetContactsByAccountAndKey.get(winningTargetAccountId);

        for (Contact sourceCon : sourceContacts) {
            String key = MM_Flow_SingleContactMergeService.buildMatchKeyFromRecord(sourceCon, matchFields);

            ContactMatch cm = new ContactMatch();
            cm.sourceContact = sourceCon;
            cm.targetContact = winningContactsByKey.get(key);

            bundle.contactMatches.add(cm);
        }

        return bundle;
    }

    @TestVisible
    static void mergeAccounts(Id targetAccountId, Id sourceAccountId) {
        Account target = [SELECT Id FROM Account WHERE Id = :targetAccountId LIMIT 1];
        Account source = [SELECT Id FROM Account WHERE Id = :sourceAccountId LIMIT 1];

        new MassMerge_SharedCode_Account().ObjectsMerge(
            target,
            new List<Account>{ source }
        );
    }

    @TestVisible
    static List<String> parseMatchFields(String matchFieldsCsv) {
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
}