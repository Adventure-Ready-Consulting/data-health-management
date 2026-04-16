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
            Birthdate = Date.newInstance(1980,1,1)
        );
        insert c1;

        Contact c2 = new Contact(
            AccountId = acct.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980,1,1)
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
            Birthdate = Date.newInstance(1980,1,1)
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
    }
}