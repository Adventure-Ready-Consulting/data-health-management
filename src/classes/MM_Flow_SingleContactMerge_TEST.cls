@IsTest
private class MM_Flow_SingleContactMerge_TEST {

    @IsTest
    static void testMatchFound() {
        Account acct = new Account(Name = 'Household');
        insert acct;

        Contact c1 = new Contact(
            AccountId = acct.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert c1;

        Contact c2 = new Contact(
            AccountId = acct.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert c2;

        Test.startTest();
        MM_Flow_SingleContactMerge.Result result =
            MM_Flow_SingleContactMergeService.evaluateAndMerge(
                c2.Id,
                false
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.candidateFound);
        System.assertEquals(1, result.duplicateCount);
        System.assertEquals(c1.Id, result.masterContactId);
        System.assertEquals(c2.Id, result.duplicateContactId);
        System.assertEquals(false, result.merged);
    }

    @IsTest
    static void testNoMatch() {
        Account acct = new Account(Name = 'Household');
        insert acct;

        Contact c1 = new Contact(
            AccountId = acct.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert c1;

        MM_Flow_SingleContactMerge.Result result =
            MM_Flow_SingleContactMergeService.evaluateAndMerge(
                c1.Id,
                false
            );

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.candidateFound);
        System.assertEquals(c1.Id, result.masterContactId);
        System.assertEquals(0, result.duplicateCount);
        System.assertEquals(false, result.merged);
        System.assertEquals('No matching contacts found within the same account.', result.message);
    }

    @IsTest
    static void testMissingBirthdateReturnsNoCandidate() {
        Account acct = new Account(Name = 'Missing Birthdate Household');
        insert acct;

        Contact c1 = new Contact(
            AccountId = acct.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = null
        );
        insert c1;

        MM_Flow_SingleContactMerge.Result result =
            MM_Flow_SingleContactMergeService.evaluateAndMerge(
                c1.Id,
                false
            );

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals(null, result.duplicateContactId);
        System.assertEquals('Input contact is missing one or more required match fields.', result.message);
    }

    @IsTest
    static void testNoAccountReturnsNoCandidate() {
        Contact c1 = new Contact(
            FirstName = 'Standalone',
            LastName = 'Person',
            Birthdate = Date.newInstance(1985, 5, 5)
        );
        insert c1;
    
        Contact queried = [
            SELECT Id, AccountId, FirstName, LastName, Birthdate
            FROM Contact
            WHERE Id = :c1.Id
            LIMIT 1
        ];
    
        MM_Flow_SingleContactMerge.Result result =
            MM_Flow_SingleContactMergeService.evaluateAndMerge(
                queried.Id,
                false
            );
    
        System.assertNotEquals(null, result);
        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
    
        if (queried.AccountId == null) {
            System.assertEquals(
                'Input contact is not associated with an Account.',
                result.message
            );
            System.assertEquals(null, result.masterContactId);
            System.assertEquals(0, result.duplicateCount);
        } else {
            System.assertEquals(
                queried.Id,
                result.masterContactId
            );
            System.assertEquals(
                0,
                result.duplicateCount
            );
            System.assertEquals(
                'No matching contacts found within the same account.',
                result.message
            );
        }
    }
    
    @IsTest
    static void testCustomMatchFieldsCsvUsesTwoFields() {
        Account acct = new Account(Name = 'Custom CSV Household');
        insert acct;

        Contact c1 = new Contact(
            AccountId = acct.Id,
            FirstName = 'Casey',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert c1;

        Contact c2 = new Contact(
            AccountId = acct.Id,
            FirstName = 'Casey',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1999, 9, 9)
        );
        insert c2;

        MM_Flow_SingleContactMerge.Result result =
            MM_Flow_SingleContactMergeService.evaluateAndMerge(
                c2.Id,
                false,
                'FirstName,LastName'
            );

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(c1.Id, result.masterContactId);
        System.assertEquals(c2.Id, result.duplicateContactId);
        System.assertEquals(false, result.merged);
    }

    @IsTest
    static void testNormalizeAndHelpers() {
        System.assertEquals('john', MM_Flow_SingleContactMergeService.normalizeName('  John  '));
        System.assertEquals(null, MM_Flow_SingleContactMergeService.normalizeName('   '));

        List<String> parsed = MM_Flow_SingleContactMergeService.parseMatchFields(' FirstName , LastName , Birthdate ');
        System.assertEquals(3, parsed.size());
        System.assertEquals('FirstName', parsed[0]);
        System.assertEquals('LastName', parsed[1]);
        System.assertEquals('Birthdate', parsed[2]);

        List<String> parsedDefault = MM_Flow_SingleContactMergeService.parseMatchFields(null);
        System.assertEquals(3, parsedDefault.size());
        System.assertEquals('FirstName', parsedDefault[0]);
        System.assertEquals('LastName', parsedDefault[1]);
        System.assertEquals('Birthdate', parsedDefault[2]);

        String key = MM_Flow_SingleContactMergeService.buildMatchKey(
            ' John ',
            ' Smith ',
            Date.newInstance(1980, 1, 1)
        );
        System.assertEquals('john|smith|1980-01-01', key);

        String nullKey = MM_Flow_SingleContactMergeService.buildMatchKey(
            'John',
            'Smith',
            null
        );
        System.assertEquals(null, nullKey);
    }

    @IsTest
    static void testBuildMatchKeyFromRecordAndSelectFields() {
        Account acct = new Account(Name = 'Helper Household');
        insert acct;

        Contact c1 = new Contact(
            AccountId = acct.Id,
            FirstName = 'Amy',
            LastName = 'Adams',
            Birthdate = Date.newInstance(1991, 2, 3)
        );
        insert c1;

        List<String> fields = new List<String>{ 'FirstName', 'LastName', 'Birthdate' };

        Contact queried = [
            SELECT Id, AccountId, FirstName, LastName, Birthdate, CreatedDate
            FROM Contact
            WHERE Id = :c1.Id
            LIMIT 1
        ];

        String key = MM_Flow_SingleContactMergeService.buildMatchKeyFromRecord(queried, fields);
        System.assert(key.startsWith('amy|adams|'));
        System.assert(key.contains('1991-02-03'));

        String selectFields = MM_Flow_SingleContactMergeService.buildContactSelectFields(fields);
        System.assert(selectFields.contains('Id'));
        System.assert(selectFields.contains('AccountId'));
        System.assert(selectFields.contains('CreatedDate'));
        System.assert(selectFields.contains('FirstName'));
        System.assert(selectFields.contains('LastName'));
        System.assert(selectFields.contains('Birthdate'));
    }

    @IsTest
    static void testBuildContactEqualityWhereClause() {
        Account acct = new Account(Name = 'Where Clause Household');
        insert acct;

        Contact c1 = new Contact(
            AccountId = acct.Id,
            FirstName = 'Taylor',
            LastName = 'Swift',
            Birthdate = Date.newInstance(1989, 12, 13)
        );
        insert c1;

        Contact queried = [
            SELECT Id, AccountId, FirstName, LastName, Birthdate, CreatedDate
            FROM Contact
            WHERE Id = :c1.Id
            LIMIT 1
        ];

        String clause = MM_Flow_SingleContactMergeService.buildContactEqualityWhereClause(
            queried,
            new List<String>{ 'FirstName', 'LastName', 'Birthdate' }
        );

        System.assert(clause.contains('FirstName'));
        System.assert(clause.contains('LastName'));
        System.assert(clause.contains('Birthdate'));
    }

    @IsTest
    static void testFindMatchesWithinAccountNullAndNoAccount() {
        System.assertEquals(
            null,
            MM_Flow_SingleContactMergeService.findMatchesWithinAccount((Contact)null)
        );

        Contact c1 = new Contact(
            FirstName = 'NoAcct',
            LastName = 'Person',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert c1;

        Contact queried = [
            SELECT Id, AccountId, FirstName, LastName, Birthdate, CreatedDate
            FROM Contact
            WHERE Id = :c1.Id
            LIMIT 1
        ];

        System.assertEquals(
            null,
            MM_Flow_SingleContactMergeService.findMatchesWithinAccount(
                queried,
                new List<String>{ 'FirstName', 'LastName', 'Birthdate' }
            )
        );
    }

    @IsTest
    static void testFindMatchesWithinAccountReturnsBundle() {
        Account acct = new Account(Name = 'Bundle Household');
        insert acct;

        Contact c1 = new Contact(
            AccountId = acct.Id,
            FirstName = 'Pat',
            LastName = 'Lee',
            Birthdate = Date.newInstance(1975, 4, 5)
        );
        Contact c2 = new Contact(
            AccountId = acct.Id,
            FirstName = 'Pat',
            LastName = 'Lee',
            Birthdate = Date.newInstance(1975, 4, 5)
        );
        insert new List<Contact>{ c1, c2 };

        Contact queried = [
            SELECT Id, AccountId, FirstName, LastName, Birthdate, CreatedDate
            FROM Contact
            WHERE Id = :c2.Id
            LIMIT 1
        ];

        MM_Flow_SingleContactMergeService.MatchBundle bundle =
            MM_Flow_SingleContactMergeService.findMatchesWithinAccount(
                queried,
                new List<String>{ 'FirstName', 'LastName', 'Birthdate' }
            );

        System.assertNotEquals(null, bundle);
        System.assertEquals(acct.Id, bundle.accountId);
        System.assertEquals(2, bundle.allMatchingContacts.size());
        System.assertEquals(1, bundle.duplicateContacts.size());
        System.assertNotEquals(null, bundle.masterContact);
    }

    @IsTest
    static void testMergeContactsNoOpAndDeletedSourceHandled() {
        MM_Flow_SingleContactMergeService.mergeContacts(null);
    
        MM_Flow_SingleContactMergeService.MatchBundle emptyBundle =
            new MM_Flow_SingleContactMergeService.MatchBundle();
        MM_Flow_SingleContactMergeService.mergeContacts(emptyBundle);
    
        MM_Flow_SingleContactMerge.Result result =
            MM_Flow_SingleContactMergeService.evaluateAndMerge(
                null,
                false
            );
    
        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals('Source contact Id is null.', result.message);
    }
}