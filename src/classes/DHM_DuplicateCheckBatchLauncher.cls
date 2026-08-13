public with sharing class DHM_DuplicateCheckBatchLauncher {

    public static final Integer ACCOUNT_BATCH_SIZE = 10;
    public static final Integer CONTACT_BATCH_SIZE = 50;
    // Backward-compatible alias used by older tests/integrations.
    public static final Integer DEFAULT_BATCH_SIZE = CONTACT_BATCH_SIZE;

    @TestVisible
    private static Boolean forceActiveDhmBatchJobForTest = false;

    private static final Set<String> ACTIVE_BATCH_STATUSES = new Set<String>{
        'Holding',
        'Queued',
        'Preparing',
        'Processing'
    };

    public class Request {
        @InvocableVariable(label='Source Object Type' required=true)
        public String objectType;

        @InvocableVariable(
            label='Source Record Id'
            description='Optional source Account or Contact Id. When supplied, DHM evaluates only this source record while duplicate candidates can still be found anywhere in Salesforce. Leave blank for a full production scan.'
        )
        public Id recordId;

        @InvocableVariable(label='Perform Merge')
        public Boolean performMerge;

        @InvocableVariable(
            label='Contact Additional Match Fields'
            description='Optional comma-separated Contact field API names that DHM must match exactly after Salesforce Duplicate Rules return candidates. All configured fields must be populated and equal on both Contacts. Example: Custom_Date_Field__c'
        )
        public String additionalMatchFieldsCsv;

        @InvocableVariable(
            label='Contact Exclusion Criteria'
            description='Validated Contact WHERE criteria. If any Contact in either Account matches, the Account merge is skipped. Use this only for hard-stop conditions; leave blank when no Contact condition should disqualify the household. Example: Do_Not_Auto_Merge__c = true'
        )
        public String contactExclusionCriteria;

        @InvocableVariable(
            label='Account Merge Allowed Unmatched Contact Criteria'
            description='Account merges only. Optional validated Contact criteria identifying Contacts that may remain unmatched without blocking an Account merge. Example: C501_Age_Calculate__c < 18. Leave blank for the existing asymmetric household behavior. Ignored when Account Merge Require All Matching Contacts is true.'
        )
        public String accountMergeAllowedUnmatchedContactCriteria;

        @InvocableVariable(
            label='Account Merge Require All Matching Contacts'
            description='Account merges only. Default false allows the smaller household to merge into the larger household when every Contact in the smaller Account has a distinct match. When true, both Accounts must contain the same number of Contacts and every Contact must have a distinct match.'
        )
        public Boolean accountMergeRequireAllMatchingContacts;

        @InvocableVariable(
            label='Maximum Merges'
            description='Optional testing limit. When greater than 0, DHM stops evaluating new records after this many eligible merges are discovered (performMerge=false) or completed (performMerge=true). Leave blank or set to 0 for no limit.'
        )
        public Integer maxMerges;
    }

    public class Result {
        @InvocableVariable
        public String message;

        @InvocableVariable
        public Id jobId;
    }

    private class ActiveBatchJobInfo {
        public Id jobId;
        public String status;

        public ActiveBatchJobInfo(Id jobId, String status) {
            this.jobId = jobId;
            this.status = status;
        }
    }

    @InvocableMethod(label='Start Duplicate Check Batch')
    public static void start(List<Request> requests) {
        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatchLauncher::start ENTER requests size=' +
            (requests == null ? 'null' : String.valueOf(requests.size()))
        );

        run(requests);

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatchLauncher::start EXIT'
        );
    }

    public static List<Result> run(List<Request> requests) {
        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatchLauncher::run ENTER requests size=' +
            (requests == null ? 'null' : String.valueOf(requests.size()))
        );

        List<Result> results = new List<Result>();

        if (requests == null || requests.isEmpty()) {
            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatchLauncher::run EXIT no requests'
            );
            return results;
        }

        Integer reqIndex = 0;

        for (Request req : requests) {
            reqIndex++;

            Integer scopeSize = req.objectType == 'Account' ? ACCOUNT_BATCH_SIZE : CONTACT_BATCH_SIZE;

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                ' objectType=' + req.objectType +
                ', performMerge=' + String.valueOf(req.performMerge) +
                ', additionalMatchFieldsCsv=' + req.additionalMatchFieldsCsv +
                ', contactExclusionCriteria=' + req.contactExclusionCriteria +
                ', accountMergeAllowedUnmatchedContactCriteria=' + req.accountMergeAllowedUnmatchedContactCriteria +
                ', accountMergeRequireAllMatchingContacts=' + String.valueOf(req.accountMergeRequireAllMatchingContacts) +
                ', maxMerges=' + String.valueOf(req.maxMerges) +
                ', recordId=' + String.valueOf(req.recordId) +
                ', batchSize=' + String.valueOf(scopeSize)
            );

            Result res = new Result();

            if (String.isBlank(req.objectType)) {
                res.message = 'Missing objectType.';
                res.jobId = null;
                results.add(res);

                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                    ' skipped - Missing objectType'
                );
                continue;
            }

            if (req.objectType != 'Contact' && req.objectType != 'Account') {
                res.message = 'Unsupported objectType: ' + req.objectType;
                res.jobId = null;
                results.add(res);

                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                    ' skipped - Unsupported objectType=' + req.objectType
                );
                continue;
            }

            if (req.recordId != null) {
                Schema.SObjectType expectedType =
                    req.objectType == 'Account' ? Account.SObjectType : Contact.SObjectType;

                if (req.recordId.getSObjectType() != expectedType) {
                    res.message = 'Source Record Id does not match objectType ' + req.objectType + '.';
                    res.jobId = null;
                    results.add(res);

                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.DEBUG,
                        '***** DHM_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                        ' skipped - recordId=' + String.valueOf(req.recordId) +
                        ' does not match objectType=' + req.objectType
                    );
                    continue;
                }
            }

            ActiveBatchJobInfo activeJob = findActiveDhmBatchJob();
            if (activeJob != null) {
                res.message =
                    'Skipped duplicate check batch because another DHM duplicate check batch job is already active. ' +
                    'Existing JobId=' + String.valueOf(activeJob.jobId) +
                    ', Status=' + activeJob.status + '.';
                res.jobId = null;
                results.add(res);

                System.debug(LoggingLevel.WARN,
                    '***** DHM BATCH NOT QUEUED - ACTIVE JOB EXISTS ***** ' +
                    'ExistingJobId=' + String.valueOf(activeJob.jobId) +
                    ', Status=' + activeJob.status +
                    ', RequestedObjectType=' + req.objectType +
                    ', RequestedRecordId=' + String.valueOf(req.recordId)
                );

                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** DHM_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                    ' skipped - active DHM batch exists JobId=' +
                    String.valueOf(activeJob.jobId) +
                    ', Status=' + activeJob.status
                );
                continue;
            }

            System.debug(LoggingLevel.ERROR,
                '***** DHM LAUNCHER ENTER ***** ' +
                'objectType=' + req.objectType +
                ', recordId=' + String.valueOf(req.recordId) +
                ', maxMerges=' + String.valueOf(req.maxMerges) +
                ', performMerge=' + String.valueOf(req.performMerge) +
                ', additionalMatchFields=' + req.additionalMatchFieldsCsv +
                ', contactExclusionCriteria=' + req.contactExclusionCriteria +
                ', accountMergeAllowedUnmatchedContactCriteria=' + req.accountMergeAllowedUnmatchedContactCriteria +
                ', accountMergeRequireAllMatchingContacts=' + String.valueOf(req.accountMergeRequireAllMatchingContacts)
            );
            Id batchJobId = Database.executeBatch(
                new DHM_DuplicateCheckBatch(
                    req.objectType,
                    req.performMerge,
                    req.additionalMatchFieldsCsv,
                    req.contactExclusionCriteria,
                    req.accountMergeAllowedUnmatchedContactCriteria,
                    req.maxMerges,
                    req.recordId,
                    req.accountMergeRequireAllMatchingContacts
                ),
                scopeSize
            );
            System.debug(LoggingLevel.ERROR,
                '***** DHM BATCH QUEUED ***** JobId=' + batchJobId
            );

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                ' queued Batch JobId=' + String.valueOf(batchJobId)
            );

            res.jobId = batchJobId;
            res.message = 'Queued duplicate check batch job.';
            results.add(res);
        }

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_DuplicateCheckBatchLauncher::run EXIT results size=' +
            String.valueOf(results.size())
        );

        return results;
    }

    @TestVisible
    private static ActiveBatchJobInfo findActiveDhmBatchJob() {
        if (Test.isRunningTest() && forceActiveDhmBatchJobForTest) {
            return new ActiveBatchJobInfo(
                '707000000000001AAA',
                'Processing'
            );
        }

        List<AsyncApexJob> activeJobs = [
            SELECT Id, Status, ApexClass.Name, CreatedDate
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'DHM_DuplicateCheckBatch'
            AND Status IN :ACTIVE_BATCH_STATUSES
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        if (activeJobs.isEmpty()) {
            return null;
        }

        AsyncApexJob activeJob = activeJobs[0];
        return new ActiveBatchJobInfo(activeJob.Id, activeJob.Status);
    }
}