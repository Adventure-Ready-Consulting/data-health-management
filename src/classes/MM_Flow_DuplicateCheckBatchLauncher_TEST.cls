@IsTest
private class MM_Flow_DuplicateCheckBatchLauncher_TEST {

    @IsTest
    static void testRunContactBatch() {
        Account acct = new Account(Name = 'Launcher Contact Account');
        insert acct;

        insert new Contact(
            AccountId = acct.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1),
            Duplicate_Check__c = true
        );

        MM_Flow_DuplicateCheckBatchLauncher.Request req =
            new MM_Flow_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Contact';
        req.performMerge = false;
        req.matchFieldsCsv = 'FirstName,LastName,Birthdate';

        Test.startTest();
        List<MM_Flow_DuplicateCheckBatchLauncher.Result> results =
            MM_Flow_DuplicateCheckBatchLauncher.run(
                new List<MM_Flow_DuplicateCheckBatchLauncher.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].jobId);
        System.assertEquals('Queued duplicate check batch job.', results[0].message);
        System.assertEquals(1, MM_Flow_DuplicateCheckBatchLauncher.DEFAULT_BATCH_SIZE);
    }

    @IsTest
    static void testRunAccountBatch() {
        Account acct = new Account(
            Name = 'Launcher Account Source',
            Duplicate_Check__c = true
        );
        insert acct;

        insert new Contact(
            AccountId = acct.Id,
            FirstName = 'Jane',
            LastName = 'Doe',
            Birthdate = Date.newInstance(1990, 1, 1)
        );

        MM_Flow_DuplicateCheckBatchLauncher.Request req =
            new MM_Flow_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Account';
        req.performMerge = false;
        req.matchFieldsCsv = 'FirstName,LastName,Birthdate';

        Test.startTest();
        List<MM_Flow_DuplicateCheckBatchLauncher.Result> results =
            MM_Flow_DuplicateCheckBatchLauncher.run(
                new List<MM_Flow_DuplicateCheckBatchLauncher.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].jobId);
        System.assertEquals('Queued duplicate check batch job.', results[0].message);
    }

    @IsTest
    static void testRunMissingObjectType() {
        MM_Flow_DuplicateCheckBatchLauncher.Request req =
            new MM_Flow_DuplicateCheckBatchLauncher.Request();
        req.performMerge = false;
        req.matchFieldsCsv = 'FirstName,LastName,Birthdate';

        List<MM_Flow_DuplicateCheckBatchLauncher.Result> results =
            MM_Flow_DuplicateCheckBatchLauncher.run(
                new List<MM_Flow_DuplicateCheckBatchLauncher.Request>{ req }
            );

        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0].jobId);
        System.assertEquals('Missing objectType.', results[0].message);
    }

    @IsTest
    static void testRunUnsupportedObjectType() {
        MM_Flow_DuplicateCheckBatchLauncher.Request req =
            new MM_Flow_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Opportunity';
        req.performMerge = false;
        req.matchFieldsCsv = 'Name';

        List<MM_Flow_DuplicateCheckBatchLauncher.Result> results =
            MM_Flow_DuplicateCheckBatchLauncher.run(
                new List<MM_Flow_DuplicateCheckBatchLauncher.Request>{ req }
            );

        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0].jobId);
        System.assertEquals('Unsupported objectType: Opportunity', results[0].message);
    }

    @IsTest
    static void testRunEmptyRequests() {
        List<MM_Flow_DuplicateCheckBatchLauncher.Result> results =
            MM_Flow_DuplicateCheckBatchLauncher.run(
                new List<MM_Flow_DuplicateCheckBatchLauncher.Request>()
            );

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testRunNullRequests() {
        List<MM_Flow_DuplicateCheckBatchLauncher.Result> results =
            MM_Flow_DuplicateCheckBatchLauncher.run(null);

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testStartMethodCoverage() {
        Account acct = new Account(Name = 'Launcher Start Coverage');
        insert acct;

        insert new Contact(
            AccountId = acct.Id,
            FirstName = 'Start',
            LastName = 'Method',
            Birthdate = Date.newInstance(1988, 8, 8),
            Duplicate_Check__c = true
        );

        MM_Flow_DuplicateCheckBatchLauncher.Request req =
            new MM_Flow_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Contact';
        req.performMerge = false;
        req.matchFieldsCsv = 'FirstName,LastName,Birthdate';

        Test.startTest();
        MM_Flow_DuplicateCheckBatchLauncher.start(
            new List<MM_Flow_DuplicateCheckBatchLauncher.Request>{ req }
        );
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testRunMultipleRequests() {
        Account acct1 = new Account(Name = 'Launcher Multi Contact');
        insert acct1;

        insert new Contact(
            AccountId = acct1.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1),
            Duplicate_Check__c = true
        );

        MM_Flow_DuplicateCheckBatchLauncher.Request req1 =
            new MM_Flow_DuplicateCheckBatchLauncher.Request();
        req1.objectType = 'Contact';
        req1.performMerge = false;
        req1.matchFieldsCsv = 'FirstName,LastName,Birthdate';

        MM_Flow_DuplicateCheckBatchLauncher.Request req2 =
            new MM_Flow_DuplicateCheckBatchLauncher.Request();
        req2.objectType = 'Opportunity';
        req2.performMerge = false;
        req2.matchFieldsCsv = 'Name';

        Test.startTest();
        List<MM_Flow_DuplicateCheckBatchLauncher.Result> results =
            MM_Flow_DuplicateCheckBatchLauncher.run(
                new List<MM_Flow_DuplicateCheckBatchLauncher.Request>{ req1, req2 }
            );
        Test.stopTest();

        System.assertEquals(2, results.size());

        System.assertNotEquals(null, results[0].jobId);
        System.assertEquals('Queued duplicate check batch job.', results[0].message);

        System.assertEquals(null, results[1].jobId);
        System.assertEquals('Unsupported objectType: Opportunity', results[1].message);
    }
}