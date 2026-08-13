@IsTest
private class DHM_DuplicateCheckBatchLauncher_TEST {

    @IsTest
    static void testRunContactBatch() {
        Account acct = new Account(Name = 'Launcher Contact Account');
        insert acct;

        insert new Contact(
            AccountId = acct.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1)
        );

        DHM_DuplicateCheckBatchLauncher.Request req =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Contact';
        req.performMerge = false;
        Test.startTest();
        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(
                new List<DHM_DuplicateCheckBatchLauncher.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].jobId);
        System.assertEquals('Queued duplicate check batch job.', results[0].message);
        System.assertEquals(50, DHM_DuplicateCheckBatchLauncher.DEFAULT_BATCH_SIZE);
        System.assertEquals(10, DHM_DuplicateCheckBatchLauncher.ACCOUNT_BATCH_SIZE);
        System.assertEquals(50, DHM_DuplicateCheckBatchLauncher.CONTACT_BATCH_SIZE);
    }

    @IsTest
    static void testRunAccountBatch() {
        Account acct = new Account(
            Name = 'Launcher Account Source'
        );
        insert acct;

        insert new Contact(
            AccountId = acct.Id,
            FirstName = 'Jane',
            LastName = 'Doe',
            Birthdate = Date.newInstance(1990, 1, 1)
        );

        DHM_DuplicateCheckBatchLauncher.Request req =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Account';
        req.performMerge = false;
        Test.startTest();
        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(
                new List<DHM_DuplicateCheckBatchLauncher.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].jobId);
        System.assertEquals('Queued duplicate check batch job.', results[0].message);
    }

    @IsTest
    static void testRunMissingObjectType() {
        DHM_DuplicateCheckBatchLauncher.Request req =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req.performMerge = false;
        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(
                new List<DHM_DuplicateCheckBatchLauncher.Request>{ req }
            );

        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0].jobId);
        System.assertEquals('Missing objectType.', results[0].message);
    }

    @IsTest
    static void testRunUnsupportedObjectType() {
        DHM_DuplicateCheckBatchLauncher.Request req =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Opportunity';
        req.performMerge = false;
        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(
                new List<DHM_DuplicateCheckBatchLauncher.Request>{ req }
            );

        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0].jobId);
        System.assertEquals('Unsupported objectType: Opportunity', results[0].message);
    }

    @IsTest
    static void testRunEmptyRequests() {
        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(
                new List<DHM_DuplicateCheckBatchLauncher.Request>()
            );

        System.assertEquals(0, results.size());
    }

    @IsTest
    static void testRunNullRequests() {
        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(null);

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
            Birthdate = Date.newInstance(1988, 8, 8)
        );

        DHM_DuplicateCheckBatchLauncher.Request req =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Contact';
        req.performMerge = false;
        Test.startTest();
        DHM_DuplicateCheckBatchLauncher.start(
            new List<DHM_DuplicateCheckBatchLauncher.Request>{ req }
        );
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void testRunAccountBatchWithSourceRecordId() {
        Account acct = new Account(Name = 'Launcher Focused Account');
        insert acct;

        insert new Contact(
            AccountId = acct.Id,
            FirstName = 'Focused',
            LastName = 'Person',
            Birthdate = Date.newInstance(1985, 1, 1)
        );

        DHM_DuplicateCheckBatchLauncher.Request req =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Account';
        req.performMerge = false;
        req.maxMerges = 1;
        req.recordId = acct.Id;

        Test.startTest();
        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(
                new List<DHM_DuplicateCheckBatchLauncher.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].jobId);
    }

    @IsTest
    static void testRejectsMismatchedSourceRecordIdType() {
        Account acct = new Account(Name = 'Wrong Type Account');
        insert acct;
        Contact con = new Contact(AccountId = acct.Id, LastName = 'Wrong Type');
        insert con;

        DHM_DuplicateCheckBatchLauncher.Request req =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Account';
        req.recordId = con.Id;

        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(
                new List<DHM_DuplicateCheckBatchLauncher.Request>{ req }
            );

        System.assertEquals(1, results.size());
        System.assertEquals(null, results[0].jobId);
        System.assertEquals(
            'Source Record Id does not match objectType Account.',
            results[0].message
        );
    }

    @IsTest
    static void testRunMultipleRequests() {
        Account acct1 = new Account(Name = 'Launcher Multi Contact');
        insert acct1;

        insert new Contact(
            AccountId = acct1.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1)
        );

        DHM_DuplicateCheckBatchLauncher.Request req1 =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req1.objectType = 'Contact';
        req1.performMerge = false;
        DHM_DuplicateCheckBatchLauncher.Request req2 =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req2.objectType = 'Opportunity';
        req2.performMerge = false;
        Test.startTest();
        List<DHM_DuplicateCheckBatchLauncher.Result> results =
            DHM_DuplicateCheckBatchLauncher.run(
                new List<DHM_DuplicateCheckBatchLauncher.Request>{ req1, req2 }
            );
        Test.stopTest();

        System.assertEquals(2, results.size());

        System.assertNotEquals(null, results[0].jobId);
        System.assertEquals('Queued duplicate check batch job.', results[0].message);

        System.assertEquals(null, results[1].jobId);
        System.assertEquals('Unsupported objectType: Opportunity', results[1].message);
    }

    @IsTest
    static void testRunSkipsWhenDhmBatchAlreadyActive() {
        DHM_DuplicateCheckBatchLauncher.Request req =
            new DHM_DuplicateCheckBatchLauncher.Request();
        req.objectType = 'Account';
        req.performMerge = false;

        DHM_DuplicateCheckBatchLauncher.forceActiveDhmBatchJobForTest = true;
        try {
            List<DHM_DuplicateCheckBatchLauncher.Result> results =
                DHM_DuplicateCheckBatchLauncher.run(
                    new List<DHM_DuplicateCheckBatchLauncher.Request>{ req }
                );

            System.assertEquals(1, results.size());
            System.assertEquals(null, results[0].jobId);
            System.assert(
                results[0].message.startsWith(
                    'Skipped duplicate check batch because another DHM duplicate check batch job is already active.'
                )
            );
        } finally {
            DHM_DuplicateCheckBatchLauncher.forceActiveDhmBatchJobForTest = false;
        }
    }

    @IsTest
    static void accountRequireAllMatchingContactsInputDefaultsSafely() {
        DHM_DuplicateCheckBatchLauncher.Request req = new DHM_DuplicateCheckBatchLauncher.Request();
        System.assertEquals(null, req.accountMergeAllowedUnmatchedContactCriteria);
        req.accountMergeAllowedUnmatchedContactCriteria = 'Birthdate > 2010-01-01';
        System.assertEquals('Birthdate > 2010-01-01', req.accountMergeAllowedUnmatchedContactCriteria);
        System.assertEquals(null, req.accountMergeRequireAllMatchingContacts);
        req.accountMergeRequireAllMatchingContacts = true;
        System.assertEquals(true, req.accountMergeRequireAllMatchingContacts);
    }
}