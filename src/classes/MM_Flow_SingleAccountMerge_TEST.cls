@IsTest
private class MM_Flow_SingleAccountMerge_TEST {

    @IsTest
    static void testCandidateFound() {
        Account source = new Account(Name='Source');
        Account target = new Account(Name='Target');
        insert new List<Account>{source, target};

        insert new List<Contact>{
            new Contact(
                AccountId=source.Id,
                FirstName='John',
                LastName='Smith',
                Birthdate=Date.newInstance(1980,1,1)
            ),
            new Contact(
                AccountId=source.Id,
                FirstName='Mary',
                LastName='Jones',
                Birthdate=Date.newInstance(1990,5,15)
            ),

            new Contact(
                AccountId=target.Id,
                FirstName='John',
                LastName='Smith',
                Birthdate=Date.newInstance(1980,1,1)
            ),
            new Contact(
                AccountId=target.Id,
                FirstName='Mary',
                LastName='Jones',
                Birthdate=Date.newInstance(1990,5,15)
            )
        };

        Test.startTest();
        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.candidateFound);
        System.assertEquals(target.Id, result.targetAccountId);
        System.assertEquals(target.Id, result.masterAccountId);
        System.assertEquals(source.Id, result.duplicateAccountId);
        System.assertEquals(false, result.merged);
    }

    @IsTest
    static void testNoCandidate() {
        Account source = new Account(Name='Source');
        Account target = new Account(Name='Target');
        insert new List<Account>{source, target};

        insert new List<Contact>{
            new Contact(
                AccountId=source.Id,
                FirstName='John',
                LastName='Smith',
                Birthdate=Date.newInstance(1980,1,1)
            ),
            new Contact(
                AccountId=target.Id,
                FirstName='Different',
                LastName='Person',
                Birthdate=Date.newInstance(2000,1,1)
            )
        };

        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false
            );

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.candidateFound);
        System.assertEquals(null, result.targetAccountId);
        System.assertEquals(null, result.masterAccountId);
        System.assertEquals(null, result.duplicateAccountId);
        System.assertEquals(false, result.merged);
    }
}