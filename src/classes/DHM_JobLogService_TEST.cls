@IsTest
private class DHM_JobLogService_TEST {
    @IsTest
    static void createsAndUpdatesJobLog() {
        Id fakeJobId = (Id)'707000000000001AAA';
        String fakeJobIdText = String.valueOf(fakeJobId);

        Test.startTest();
        DHM_JobLogService.createStartedLog(fakeJobId, 'Account', true, 1, 10);
        Test.stopTest();

        DHM_Job_Log__c row = [
            SELECT Batch_Job_Id__c, Process__c, Source_Object_Type__c, Status__c,
                   Perform_Merge__c, Max_Merges__c, Scope_Size__c
            FROM DHM_Job_Log__c
            WHERE Batch_Job_Id__c = :fakeJobIdText
            LIMIT 1
        ];
        System.assertEquals('Started', row.Status__c);
        System.assertEquals('Account', row.Source_Object_Type__c);
        System.assertEquals(10, row.Scope_Size__c);

        DHM_JobLogService.updateLog(
            fakeJobId,
            'Completed with Errors',
            'Completed',
            10,
            2,
            1,
            1,
            1,
            'Too many SOQL queries: 201',
            'First error: Too many SOQL queries: 201',
            5,
            5
        );

        row = [
            SELECT Status__c, Apex_Job_Status__c, Records_Processed__c,
                   Error_Count__c, Error_Message__c, Extended_Status__c
            FROM DHM_Job_Log__c
            WHERE Batch_Job_Id__c = :fakeJobIdText
            LIMIT 1
        ];
        System.assertEquals('Completed with Errors', row.Status__c);
        System.assertEquals(1, row.Error_Count__c);
        System.assert(row.Error_Message__c.contains('Too many SOQL queries'));
    }

    @IsTest
    static void truncatesLongText() {
        System.assertEquals('abcd', DHM_JobLogService.truncate('abcdef', 4));
    }

    @IsTest
    static void mergeLimitStopDoesNotCreateAnErrorByItself() {
        Id fakeJobId = (Id)'707000000000002AAA';
        String fakeJobIdText = String.valueOf(fakeJobId);
        DHM_JobLogService.createStartedLog(fakeJobId, 'Account', true, 1, 10);

        DHM_JobLogService.markStoppedForMergeLimit(
            fakeJobId,
            10,
            0,
            1,
            1,
            0
        );

        DHM_Job_Log__c row = [
            SELECT Status__c, Apex_Job_Status__c, Error_Count__c
            FROM DHM_Job_Log__c
            WHERE Batch_Job_Id__c = :fakeJobIdText
            LIMIT 1
        ];
        System.assertEquals('Stopped - Merge Limit', row.Status__c);
        System.assertEquals('Aborted', row.Apex_Job_Status__c);
        System.assertEquals(0, row.Error_Count__c);
    }

    @IsTest
    static void intentionalAbortErrorIsNotCountedButRealErrorsRemain() {
        System.assertEquals(0, DHM_JobLogService.normalizePlatformErrors(1, true));
        System.assertEquals(1, DHM_JobLogService.normalizePlatformErrors(2, true));
        System.assertEquals(1, DHM_JobLogService.normalizePlatformErrors(1, false));
        System.assertEquals(0, DHM_JobLogService.normalizePlatformErrors(null, true));
    }

}
