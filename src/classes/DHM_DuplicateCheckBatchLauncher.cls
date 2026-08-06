public with sharing class DHM_DuplicateCheckBatchLauncher {

    public static final Integer DEFAULT_BATCH_SIZE = 1;

    public class Request {
        @InvocableVariable(required=true)
        public String objectType;

        @InvocableVariable
        public Boolean performMerge;

        @InvocableVariable(
            label='Contact Exclusion Criteria'
            description='Validated Contact WHERE criteria. If any Contact in either Account matches, the Account merge is skipped. Example: C501_Age_Calculate__c < 18'
        )
        public String contactExclusionCriteria;
    }

    public class Result {
        @InvocableVariable
        public String message;

        @InvocableVariable
        public Id jobId;
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

            Integer scopeSize = DEFAULT_BATCH_SIZE;

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                ' objectType=' + req.objectType +
                ', performMerge=' + String.valueOf(req.performMerge) +
                ', contactExclusionCriteria=' + req.contactExclusionCriteria +
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

            Id batchJobId = Database.executeBatch(
                new DHM_DuplicateCheckBatch(
                    req.objectType,
                    req.performMerge,
                    null,
                    req.contactExclusionCriteria
                ),
                scopeSize
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
}