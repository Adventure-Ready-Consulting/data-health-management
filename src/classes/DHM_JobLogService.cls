public without sharing class DHM_JobLogService {

    private static final Integer ERROR_MESSAGE_MAX = 32768;

    public static void createStartedLog(
        Id batchJobId,
        String objectType,
        Boolean performMerge,
        Integer maxMerges,
        Integer scopeSize
    ) {
        if (batchJobId == null) {
            return;
        }

        try {
            DHM_Job_Log__c logRow = new DHM_Job_Log__c(
                Batch_Job_Id__c = String.valueOf(batchJobId),
                Process__c = 'Duplicate Check - ' + objectType,
                Source_Object_Type__c = objectType,
                Status__c = 'Started',
                Started__c = System.now(),
                Perform_Merge__c = performMerge == true,
                Max_Merges__c = maxMerges,
                Scope_Size__c = scopeSize
            );
            insert logRow;
        } catch (Exception e) {
            // Job logging must never prevent duplicate management from running.
            System.debug(LoggingLevel.ERROR,
                '***** DHM JOB LOG CREATE FAILED ***** jobId=' + String.valueOf(batchJobId) +
                ', message=' + e.getMessage()
            );
        }
    }

    public static void markStoppedForMergeLimit(
        Id batchJobId,
        Integer processedCount,
        Integer updatedCount,
        Integer candidateCount,
        Integer mergeCount,
        Integer applicationErrorCount
    ) {
        updateLog(
            batchJobId,
            'Stopped - Merge Limit',
            'Aborted',
            processedCount,
            updatedCount,
            candidateCount,
            mergeCount,
            applicationErrorCount,
            null,
            null,
            null,
            null
        );
    }

    public static void completeFromAsyncApexJob(
        Id batchJobId,
        Integer processedCount,
        Integer updatedCount,
        Integer candidateCount,
        Integer mergeCount,
        Integer applicationErrorCount
    ) {
        if (batchJobId == null) {
            return;
        }

        try {
            AsyncApexJob job = [
                SELECT Id, Status, NumberOfErrors, ExtendedStatus,
                       TotalJobItems, JobItemsProcessed
                FROM AsyncApexJob
                WHERE Id = :batchJobId
                LIMIT 1
            ];

            Integer platformErrors = job.NumberOfErrors == null ? 0 : job.NumberOfErrors;
            Integer totalErrors = (applicationErrorCount == null ? 0 : applicationErrorCount) + platformErrors;
            String status = totalErrors > 0 ? 'Completed with Errors' : 'Completed';
            String errorMessage = null;

            if (platformErrors > 0) {
                errorMessage = String.isBlank(job.ExtendedStatus)
                    ? 'One or more Batch Apex scopes failed. Review Setup > Apex Jobs for Job ID ' + String.valueOf(batchJobId) + '.'
                    : job.ExtendedStatus;
            }

            updateLog(
                batchJobId,
                status,
                job.Status,
                processedCount,
                updatedCount,
                candidateCount,
                mergeCount,
                totalErrors,
                errorMessage,
                job.ExtendedStatus,
                job.TotalJobItems,
                job.JobItemsProcessed
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '***** DHM JOB LOG FINISH UPDATE FAILED ***** jobId=' + String.valueOf(batchJobId) +
                ', message=' + e.getMessage()
            );
        }
    }

    @TestVisible
    private static void updateLog(
        Id batchJobId,
        String status,
        String apexJobStatus,
        Integer processedCount,
        Integer updatedCount,
        Integer candidateCount,
        Integer mergeCount,
        Integer errorCount,
        String errorMessage,
        String extendedStatus,
        Integer totalJobItems,
        Integer jobItemsProcessed
    ) {
        if (batchJobId == null) {
            return;
        }

        try {
            String batchJobIdText = String.valueOf(batchJobId);
            List<DHM_Job_Log__c> rows = [
                SELECT Id
                FROM DHM_Job_Log__c
                WHERE Batch_Job_Id__c = :batchJobIdText
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            if (rows.isEmpty()) {
                rows.add(new DHM_Job_Log__c(
                    Batch_Job_Id__c = String.valueOf(batchJobId),
                    Process__c = 'Duplicate Check Batch',
                    Started__c = System.now()
                ));
            }

            DHM_Job_Log__c row = rows[0];
            row.Status__c = status;
            row.Apex_Job_Status__c = apexJobStatus;
            row.Completed__c = System.now();
            row.Records_Processed__c = processedCount;
            row.Records_Updated__c = updatedCount;
            row.Candidates_Found__c = candidateCount;
            row.Merges__c = mergeCount;
            row.Error_Count__c = errorCount;
            row.Error_Message__c = truncate(errorMessage, ERROR_MESSAGE_MAX);
            row.Extended_Status__c = truncate(extendedStatus, ERROR_MESSAGE_MAX);
            row.Total_Job_Items__c = totalJobItems;
            row.Job_Items_Processed__c = jobItemsProcessed;
            upsert row;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '***** DHM JOB LOG UPDATE FAILED ***** jobId=' + String.valueOf(batchJobId) +
                ', message=' + e.getMessage()
            );
        }
    }

    @TestVisible
    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value) || maxLength == null || maxLength <= 0) {
            return value;
        }
        return value.length() <= maxLength ? value : value.substring(0, maxLength);
    }
}