@IsTest
private class MM_Flow_DuplicateCheckBatch_TEST {

    @IsTest
    static void testBatchContactCandidateFound() {
        Account acct = new Account(Name = 'Batch Household A');
        insert acct;

        Contact masterCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Mary',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1990, 5, 15),
            Duplicate_Check__c = false
        );
        insert masterCon;

        Contact flaggedCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Mary',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1990, 5, 15),
            Duplicate_Check__c = true
        );
        insert flaggedCon;

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Contact',
                false,
                'FirstName,LastName,Birthdate'
            ),
            50
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check__c, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];

        System.assertEquals(false, refreshed.Duplicate_Check__c);
        System.assertEquals(masterCon.Id, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchContactNoCandidate() {
        Account acct = new Account(Name = 'Batch Household B');
        insert acct;

        Contact flaggedCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Alice',
            LastName = 'Brown',
            Birthdate = Date.newInstance(1988, 3, 10),
            Duplicate_Check__c = true
        );
        insert flaggedCon;

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Contact',
                false,
                'FirstName,LastName,Birthdate'
            ),
            50
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check__c, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];

        System.assertEquals(false, refreshed.Duplicate_Check__c);
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchContactSkipsMissingBirthdate() {
        Account acct = new Account(Name = 'Batch Household Missing Birthdate');
        insert acct;

        Contact flaggedCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Skip',
            LastName = 'Me',
            Birthdate = null,
            Duplicate_Check__c = true
        );
        insert flaggedCon;

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Contact',
                false,
                'FirstName,LastName,Birthdate'
            ),
            50
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check__c, Duplicate_Check_Candidate__c, Birthdate
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];

        System.assertEquals(null, refreshed.Birthdate);
        System.assertEquals(false, refreshed.Duplicate_Check__c);
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchContactDoesNotOverwriteExistingCandidate() {
        Account acct = new Account(Name = 'Batch Household Existing Candidate');
        insert acct;

        Contact existingCandidate = new Contact(
            AccountId = acct.Id,
            FirstName = 'Target',
            LastName = 'Person',
            Birthdate = Date.newInstance(1975, 6, 1),
            Duplicate_Check__c = false
        );
        insert existingCandidate;

        Contact actualMatch = new Contact(
            AccountId = acct.Id,
            FirstName = 'Jane',
            LastName = 'Doe',
            Birthdate = Date.newInstance(1992, 7, 4),
            Duplicate_Check__c = false
        );
        insert actualMatch;

        Contact flaggedCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Jane',
            LastName = 'Doe',
            Birthdate = Date.newInstance(1992, 7, 4),
            Duplicate_Check__c = true,
            Duplicate_Check_Candidate__c = existingCandidate.Id
        );
        insert flaggedCon;

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Contact',
                false,
                'FirstName,LastName,Birthdate'
            ),
            50
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check__c, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];

        System.assertEquals(false, refreshed.Duplicate_Check__c);
        System.assertEquals(existingCandidate.Id, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchAccountCandidateFound() {
        Account sourceAcct = new Account(
            Name = 'Batch Source Household',
            Duplicate_Check__c = true
        );
        Account targetAcct = new Account(
            Name = 'Batch Target Household',
            Duplicate_Check__c = false
        );
        insert new List<Account>{ sourceAcct, targetAcct };

        insert new List<Contact>{
            new Contact(
                AccountId = sourceAcct.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = Date.newInstance(1980, 1, 1)
            ),
            new Contact(
                AccountId = sourceAcct.Id,
                FirstName = 'Mary',
                LastName = 'Jones',
                Birthdate = Date.newInstance(1990, 5, 15)
            ),
            new Contact(
                AccountId = targetAcct.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = Date.newInstance(1980, 1, 1)
            ),
            new Contact(
                AccountId = targetAcct.Id,
                FirstName = 'Mary',
                LastName = 'Jones',
                Birthdate = Date.newInstance(1990, 5, 15)
            )
        };

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Account',
                false,
                'FirstName,LastName,Birthdate'
            ),
            50
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id, Duplicate_Check__c, Duplicate_Check_Candidate__c
            FROM Account
            WHERE Id = :sourceAcct.Id
            LIMIT 1
        ];

        System.assertEquals(false, refreshed.Duplicate_Check__c);
        System.assertEquals(targetAcct.Id, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchAccountNoCandidate() {
        Account sourceAcct = new Account(
            Name = 'Batch Source Only',
            Duplicate_Check__c = true
        );
        insert sourceAcct;

        insert new Contact(
            AccountId = sourceAcct.Id,
            FirstName = 'Only',
            LastName = 'Person',
            Birthdate = Date.newInstance(1977, 7, 7)
        );

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Account',
                false,
                'FirstName,LastName,Birthdate'
            ),
            50
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id, Duplicate_Check__c, Duplicate_Check_Candidate__c
            FROM Account
            WHERE Id = :sourceAcct.Id
            LIMIT 1
        ];

        System.assertEquals(false, refreshed.Duplicate_Check__c);
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchAccountSkipsWhenNoMatchableContacts() {
        Account sourceAcct = new Account(
            Name = 'Batch Source Unmatchable',
            Duplicate_Check__c = true
        );
        insert sourceAcct;

        insert new Contact(
            AccountId = sourceAcct.Id,
            FirstName = 'NoBirth',
            LastName = 'Person',
            Birthdate = null
        );

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Account',
                false,
                'FirstName,LastName,Birthdate'
            ),
            50
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id, Duplicate_Check__c, Duplicate_Check_Candidate__c
            FROM Account
            WHERE Id = :sourceAcct.Id
            LIMIT 1
        ];

        System.assertEquals(false, refreshed.Duplicate_Check__c);
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchUnsupportedObjectTypeDoesNothing() {
        Account acct = new Account(
            Name = 'Unsupported Object Type Account',
            Duplicate_Check__c = true
        );
        insert acct;

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Opportunity',
                false,
                'Name'
            ),
            50
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id, Duplicate_Check__c
            FROM Account
            WHERE Id = :acct.Id
            LIMIT 1
        ];

        // Unsupported object type means batch should not process the account.
        System.assertEquals(true, refreshed.Duplicate_Check__c);
    }

    @IsTest
    static void testBatchBlankMatchFieldsCsvSkipsContact() {
        Account acct = new Account(Name = 'Blank CSV Contact Account');
        insert acct;

        Contact flaggedCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Blank',
            LastName = 'Csv',
            Birthdate = Date.newInstance(1999, 9, 9),
            Duplicate_Check__c = true
        );
        insert flaggedCon;

        Test.startTest();
        Database.executeBatch(
            new MM_Flow_DuplicateCheckBatch(
                'Contact',
                false,
                ''
            ),
            50
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check__c, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];

        System.assertEquals(false, refreshed.Duplicate_Check__c);
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }
}