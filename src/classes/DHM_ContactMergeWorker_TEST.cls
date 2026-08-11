@IsTest
private class DHM_ContactMergeWorker_TEST {

    @IsTest
    static void testWorkerMergesQueuedContactOutsideBatch() {
        Account acct = new Account(Name = 'Worker Household');
        insert acct;

        Contact olderContact = new Contact(
            AccountId = acct.Id,
            FirstName = 'Worker',
            LastName = 'Merge',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert olderContact;

        Contact newerContact = new Contact(
            AccountId = acct.Id,
            FirstName = 'Worker',
            LastName = 'Merge',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert newerContact;

        Test.setCreatedDate(olderContact.Id, Datetime.newInstance(2026, 1, 1, 0, 0, 0));
        Test.setCreatedDate(newerContact.Id, Datetime.newInstance(2026, 1, 2, 0, 0, 0));

        olderContact.Duplicate_Check_Candidate__c = newerContact.Id;
        update olderContact;

        Test.startTest();
        DHM_ContactMergeWorker worker = new DHM_ContactMergeWorker(
            null,
            System.now().addMinutes(-5),
            'Birthdate',
            1
        );
        worker.runOnce();
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Contact WHERE Id = :olderContact.Id],
            'Older queued Contact should be merged away.'
        );

        Contact survivor = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :newerContact.Id
            LIMIT 1
        ];
        System.assertEquals(newerContact.Id, survivor.Id);
        System.assertEquals(null, survivor.Duplicate_Check_Candidate__c);
    }

    @IsTest
    static void testKnownPairRejectsDifferentAccounts() {
        Account firstAcct = new Account(Name = 'First Worker Household');
        Account secondAcct = new Account(Name = 'Second Worker Household');
        insert new List<Account>{ firstAcct, secondAcct };

        Contact firstContact = new Contact(AccountId = firstAcct.Id, LastName = 'Same');
        Contact secondContact = new Contact(AccountId = secondAcct.Id, LastName = 'Same');
        insert new List<Contact>{ firstContact, secondContact };

        DHM_SingleContactMerge.Result result =
            DHM_SingleContactMergeService.mergeKnownCandidatePair(
                firstContact.Id,
                secondContact.Id,
                null
            );

        System.assertEquals(false, result.merged);
        System.assert(result.message.contains('same Account'));
    }

    @IsTest
    static void testContactBatchDefersActualMerge() {
        Account acct = new Account(Name = 'Deferred Batch Household');
        insert acct;

        Contact firstContact = new Contact(
            AccountId = acct.Id,
            FirstName = 'Deferred',
            LastName = 'Merge',
            Birthdate = Date.newInstance(1985, 2, 2)
        );
        Contact secondContact = new Contact(
            AccountId = acct.Id,
            FirstName = 'Deferred',
            LastName = 'Merge',
            Birthdate = Date.newInstance(1985, 2, 2)
        );
        insert new List<Contact>{ firstContact, secondContact };

        DHM_DuplicateRuleCandidateService.setTestCandidates(
            new Map<Id, Set<Id>>{
                firstContact.Id => new Set<Id>{ secondContact.Id },
                secondContact.Id => new Set<Id>{ firstContact.Id }
            }
        );

        Test.startTest();
        DHM_DuplicateCheckBatch.startBatch(
            'Contact',
            true,
            'Birthdate',
            null,
            1,
            firstContact.Id,
            false
        );
        Test.stopTest();

        Set<Id> pairIds = new Set<Id>{ firstContact.Id, secondContact.Id };
        System.assertEquals(
            2,
            [SELECT COUNT() FROM Contact WHERE Id IN :pairIds],
            'Batch discovery must not call Database.merge for Contacts.'
        );
        Contact refreshed = [
            SELECT Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Id = :firstContact.Id
        ];
        System.assertEquals(secondContact.Id, refreshed.Duplicate_Check_Candidate__c);

        DHM_DuplicateRuleCandidateService.clearTestCandidates();
    }

}
