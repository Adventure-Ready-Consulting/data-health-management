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


    @IsTest
    static void testSourceRecordIdLimitsAccountBatchToOneSource() {
        Account sourceAcct = new Account(Name = 'Focused Source');
        Account otherAcct = new Account(Name = 'Other Source');
        Account targetAcct = new Account(Name = 'Focused Target');
        insert new List<Account>{ sourceAcct, otherAcct, targetAcct };

        Contact sourceCon = new Contact(
            AccountId = sourceAcct.Id,
            FirstName = 'Focused',
            LastName = 'Match',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        Contact otherCon = new Contact(
            AccountId = otherAcct.Id,
            FirstName = 'Other',
            LastName = 'Match',
            Birthdate = Date.newInstance(1981, 1, 1)
        );
        Contact targetCon = new Contact(
            AccountId = targetAcct.Id,
            FirstName = 'Focused',
            LastName = 'Match',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert new List<Contact>{ sourceCon, otherCon, targetCon };

        DHM_DuplicateRuleCandidateService.setTestCandidates(
            new Map<Id, Set<Id>>{ sourceCon.Id => new Set<Id>{ targetCon.Id } }
        );

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Account',
            false,
            null,
            null,
            1,
            sourceAcct.Id
        );
        Test.stopTest();

        Account refreshedSource = [
            SELECT Duplicate_Check_Candidate__c
            FROM Account WHERE Id = :sourceAcct.Id
        ];
        Account refreshedOther = [
            SELECT Duplicate_Check_Candidate__c
            FROM Account WHERE Id = :otherAcct.Id
        ];

        System.assertEquals(targetAcct.Id, refreshedSource.Duplicate_Check_Candidate__c);
        System.assertEquals(null, refreshedOther.Duplicate_Check_Candidate__c);
        DHM_DuplicateRuleCandidateService.clearTestCandidates();
    }

    @IsTest
    static void testMaxMergesLimitsEvaluationOnlyRun() {
        Account acct = new Account(Name = 'Max Merge Test Household');
        insert acct;

        Contact con1 = new Contact(
            AccountId = acct.Id,
            FirstName = 'Limit',
            LastName = 'Tester',
            Birthdate = Date.newInstance(1990, 1, 1)
        );
        Contact con2 = new Contact(
            AccountId = acct.Id,
            FirstName = 'Limit',
            LastName = 'Tester',
            Birthdate = Date.newInstance(1990, 1, 1)
        );
        insert new List<Contact>{ con1, con2 };

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Contact',
            false,
            'FirstName,LastName,Birthdate',
            null,
            1
        );
        Test.stopTest();

        Set<Id> testContactIds = new Set<Id>{ con1.Id, con2.Id };
        Integer candidateCount = [
            SELECT COUNT()
            FROM Contact
            WHERE Id IN :testContactIds
              AND Duplicate_Check_Candidate__c != null
        ];

        System.assertEquals(
            1,
            candidateCount,
            'maxMerges=1 should stop evaluation after the first eligible merge is discovered.'
        );
    }


    @IsTest
    static void testBatchAccountClearsStaleCandidateWhenAdditionalFieldMismatch() {
        Account sourceAcct = new Account(Name = 'Stale Account Source');
        Account targetAcct = new Account(Name = 'Stale Account Target');
        insert new List<Account>{ sourceAcct, targetAcct };

        Contact sourceCon = new Contact(
            AccountId = sourceAcct.Id,
            FirstName = 'David',
            LastName = 'Boyce',
            Birthdate = Date.newInstance(1972, 1, 1)
        );
        Contact targetCon = new Contact(
            AccountId = targetAcct.Id,
            FirstName = 'David',
            LastName = 'Boyce',
            Birthdate = Date.newInstance(1973, 1, 1)
        );
        insert new List<Contact>{ sourceCon, targetCon };

        sourceAcct.Duplicate_Check_Candidate__c = targetAcct.Id;
        update sourceAcct;

        DHM_DuplicateRuleCandidateService.setTestCandidates(
            new Map<Id, Set<Id>>{
                sourceCon.Id => new Set<Id>{ targetCon.Id }
            }
        );

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Account',
            false,
            'Birthdate',
            null,
            1,
            sourceAcct.Id
        );
        Test.stopTest();

        Account refreshed = [
            SELECT Duplicate_Check_Candidate__c
            FROM Account
            WHERE Id = :sourceAcct.Id
        ];

        System.assertEquals(
            null,
            refreshed.Duplicate_Check_Candidate__c,
            'A stale Account candidate must be cleared when the current additional-field validation rejects the candidate.'
        );

        DHM_DuplicateRuleCandidateService.clearTestCandidates();
    }

    @IsTest
    static void testBatchContactClearsStaleCandidateWhenAdditionalFieldMismatch() {
        Account acct = new Account(Name = 'Stale Contact Household');
        insert acct;

        Contact sourceCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'David',
            LastName = 'Boyce',
            Birthdate = Date.newInstance(1972, 1, 1)
        );
        Contact targetCon = new Contact(
            AccountId = acct.Id,
            FirstName = 'David',
            LastName = 'Boyce',
            Birthdate = Date.newInstance(1973, 1, 1)
        );
        insert new List<Contact>{ sourceCon, targetCon };

        sourceCon.Duplicate_Check_Candidate__c = targetCon.Id;
        update sourceCon;

        DHM_DuplicateRuleCandidateService.setTestCandidates(
            new Map<Id, Set<Id>>{
                sourceCon.Id => new Set<Id>{ targetCon.Id }
            }
        );

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Contact',
            false,
            'Birthdate',
            null,
            1,
            sourceCon.Id
        );
        Test.stopTest();

        Contact refreshed = [
            SELECT Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :sourceCon.Id
        ];

        System.assertEquals(
            null,
            refreshed.Duplicate_Check_Candidate__c,
            'A stale Contact candidate must be cleared when the current additional-field validation rejects the candidate.'
        );

        DHM_DuplicateRuleCandidateService.clearTestCandidates();
    }

}