public with sharing class DHM_DuplicateCheckBatchLauncher {

    public static final Integer DEFAULT_BATCH_SIZE = 50;

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
            description='Validated Contact WHERE criteria. If any Contact in either Account matches, the Account merge is skipped. Example: C501_Age_Calculate__c < 18'
        )
        public String contactExclusionCriteria;

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
                ', additionalMatchFieldsCsv=' + req.additionalMatchFieldsCsv +
                ', contactExclusionCriteria=' + req.contactExclusionCriteria +
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

            System.debug(LoggingLevel.ERROR,
                '***** DHM LAUNCHER ENTER ***** ' +
                'objectType=' + req.objectType +
                ', recordId=' + String.valueOf(req.recordId) +
                ', maxMerges=' + String.valueOf(req.maxMerges) +
                ', performMerge=' + String.valueOf(req.performMerge) +
                ', additionalMatchFields=' + req.additionalMatchFieldsCsv +
                ', contactExclusionCriteria=' + req.contactExclusionCriteria
            );
            Id batchJobId = Database.executeBatch(
                new DHM_DuplicateCheckBatch(
                    req.objectType,
                    req.performMerge,
                    req.additionalMatchFieldsCsv,
                    req.contactExclusionCriteria,
                    req.maxMerges,
                    req.recordId
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
}