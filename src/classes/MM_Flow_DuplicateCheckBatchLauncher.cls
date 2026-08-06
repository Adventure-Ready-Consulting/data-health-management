public with sharing class MM_Flow_DuplicateCheckBatchLauncher {

    public static final Integer DEFAULT_BATCH_SIZE = 1;

    public class Request {
        @InvocableVariable(required=true)
        public String objectType;

        @InvocableVariable
        public Boolean performMerge;

        @InvocableVariable
        public String matchFieldsCsv;

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
        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** MM_Flow_DuplicateCheckBatchLauncher::start ENTER requests size=' +
            (requests == null ? 'null' : String.valueOf(requests.size()))
        );

        run(requests);

        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** MM_Flow_DuplicateCheckBatchLauncher::start EXIT'
        );
    }

    public static List<Result> run(List<Request> requests) {
        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** MM_Flow_DuplicateCheckBatchLauncher::run ENTER requests size=' +
            (requests == null ? 'null' : String.valueOf(requests.size()))
        );

        List<Result> results = new List<Result>();

        if (requests == null || requests.isEmpty()) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** MM_Flow_DuplicateCheckBatchLauncher::run EXIT no requests'
            );
            return results;
        }

        Integer reqIndex = 0;

        for (Request req : requests) {
            reqIndex++;

            Integer scopeSize = DEFAULT_BATCH_SIZE;

            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** MM_Flow_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                ' objectType=' + req.objectType +
                ', performMerge=' + String.valueOf(req.performMerge) +
                ', matchFieldsCsv=' + req.matchFieldsCsv +
                ', contactExclusionCriteria=' + req.contactExclusionCriteria +
                ', batchSize=' + String.valueOf(scopeSize)
            );

            Result res = new Result();

            if (String.isBlank(req.objectType)) {
                res.message = 'Missing objectType.';
                res.jobId = null;
                results.add(res);

                MassMerge_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** MM_Flow_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                    ' skipped - Missing objectType'
                );
                continue;
            }

            if (req.objectType != 'Contact' && req.objectType != 'Account') {
                res.message = 'Unsupported objectType: ' + req.objectType;
                res.jobId = null;
                results.add(res);

                MassMerge_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** MM_Flow_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                    ' skipped - Unsupported objectType=' + req.objectType
                );
                continue;
            }

            Id batchJobId = Database.executeBatch(
                new MM_Flow_DuplicateCheckBatch(
                    req.objectType,
                    req.performMerge,
                    req.matchFieldsCsv,
                    req.contactExclusionCriteria
                ),
                scopeSize
            );

            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** MM_Flow_DuplicateCheckBatchLauncher::run Request #' + reqIndex +
                ' queued Batch JobId=' + String.valueOf(batchJobId)
            );

            res.jobId = batchJobId;
            res.message = 'Queued duplicate check batch job.';
            results.add(res);
        }

        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** MM_Flow_DuplicateCheckBatchLauncher::run EXIT results size=' +
            String.valueOf(results.size())
        );

        return results;
    }
}