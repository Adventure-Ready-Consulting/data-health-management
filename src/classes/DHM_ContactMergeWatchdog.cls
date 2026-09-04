public without sharing class DHM_ContactMergeWatchdog implements Schedulable {
    private Id batchJobId;

    public DHM_ContactMergeWatchdog(Id batchJobId) {
        this.batchJobId = batchJobId;
    }

    public void execute(SchedulableContext sc) {
        if (batchJobId == null) return;

        String batchIdText = String.valueOf(batchJobId);
        String workerName = 'DHM Contact Merge%' + batchIdText + '%';
        Integer activeWorkers = [
            SELECT COUNT()
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :workerName
              AND State IN ('WAITING', 'ACQUIRED')
              AND Id != :sc.getTriggerId()
        ];

        if (activeWorkers == 0 && DHM_JobLogService.isContactMergePending(batchJobId)) {
            DHM_JobLogService.markContactMergeWorkerFailed(
                batchJobId,
                'The deferred Contact merge worker stopped before completing all candidates. ' +
                'Review Setup > Apex Jobs for scheduled Apex failures. The most common NPSP ' +
                'cause is an uncatchable governor-limit exception.'
            );
        }
    }
}
