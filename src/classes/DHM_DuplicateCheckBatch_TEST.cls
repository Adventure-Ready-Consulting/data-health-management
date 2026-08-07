@IsTest
private class DHM_DuplicateCheckBatch_TEST {

    @IsTest
    static void testBatchContactCandidateFound() {
        Account acct = new Account(Name = 'Batch Household A');
        insert acct;

        Contact masterCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Mary',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1990, 5, 15)
        );
        insert masterCon;

        Contact flaggedCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Mary',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1990, 5, 15)
        );
        insert flaggedCon;

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Contact',
            false,
            'FirstName,LastName,Birthdate'
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];
        System.assertEquals(masterCon.Id, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchContactCandidateOverwritesExistingValue() {
        Account acct = new Account(Name = 'Batch Household Overwrite');
        insert acct;

        Contact existingCandidate = new Contact(
            AccountId = acct.Id,
            FirstName = 'Other',
            LastName = 'Person',
            Birthdate = Date.newInstance(1970, 1, 1)
        );
        insert existingCandidate;

        Contact masterCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Mary',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1990, 5, 15)
        );
        insert masterCon;

        Contact flaggedCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Mary',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1990, 5, 15),
            Duplicate_Check_Candidate__c = existingCandidate.Id
        );
        insert flaggedCon;

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Contact',
            false,
            'FirstName,LastName,Birthdate'
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];
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
            Birthdate = Date.newInstance(1988, 3, 10)
        );
        insert flaggedCon;

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Contact',
            false,
            'FirstName,LastName,Birthdate'
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];
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
            Birthdate = null
        );
        insert flaggedCon;

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Contact',
            false,
            'FirstName,LastName,Birthdate'
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check_Candidate__c, Birthdate
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];

        System.assertEquals(null, refreshed.Birthdate);
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchAccountCandidateFound() {
        Account sourceAcct = new Account(
            Name = 'Batch Source Household'
        );
        Account targetAcct = new Account(
            Name = 'Batch Target Household'
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
        DHM_DuplicateCheckBatch.startBatch(
            'Account',
            false,
            'FirstName,LastName,Birthdate'
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Account
            WHERE Id = :sourceAcct.Id
            LIMIT 1
        ];
        System.assertEquals(targetAcct.Id, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchAccountNoCandidate() {
        Account sourceAcct = new Account(
            Name = 'Batch Source Only'
        );
        insert sourceAcct;

        insert new Contact(
            AccountId = sourceAcct.Id,
            FirstName = 'Only',
            LastName = 'Person',
            Birthdate = Date.newInstance(1977, 7, 7)
        );

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Account',
            false,
            'FirstName,LastName,Birthdate'
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Account
            WHERE Id = :sourceAcct.Id
            LIMIT 1
        ];
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchAccountSkipsWhenNoMatchableContacts() {
        Account sourceAcct = new Account(
            Name = 'Batch Source Unmatchable'
        );
        insert sourceAcct;

        insert new Contact(
            AccountId = sourceAcct.Id,
            FirstName = 'NoBirth',
            LastName = 'Person',
            Birthdate = null
        );

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Account',
            false,
            'FirstName,LastName,Birthdate'
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Account
            WHERE Id = :sourceAcct.Id
            LIMIT 1
        ];
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testBatchUnsupportedObjectTypeDoesNothing() {
        Account acct = new Account(
            Name = 'Unsupported Object Type Account'
        );
        insert acct;

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Opportunity',
            false,
            'Name'
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Id
            FROM Account
            WHERE Id = :acct.Id
            LIMIT 1
        ];
    }

    @IsTest
    static void testBatchBlankMatchFieldsCsvSkipsContact() {
        Account acct = new Account(Name = 'Blank CSV Contact Account');
        insert acct;

        Contact flaggedCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'Blank',
            LastName = 'Csv',
            Birthdate = Date.newInstance(1999, 9, 9)
        );
        insert flaggedCon;

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Contact',
            false,
            ''
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :flaggedCon.Id
            LIMIT 1
        ];
        System.assertEquals(null, refreshed.Duplicate_Check_Candidate__c);
    }
}