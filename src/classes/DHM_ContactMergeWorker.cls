public without sharing class DHM_ContactMergeWorker implements Schedulable {

    public static final Integer MERGES_PER_RUN = 10;
    private static final Integer QUERY_LIMIT = 50;
    private static final Integer RESCHEDULE_MINUTES = 2;

    private Id batchJobId;
    private Datetime candidateCutoff;
    private String matchFieldsCsv;
    private Integer remainingMergeLimit;

    public DHM_ContactMergeWorker(
        Id batchJobId,
        Datetime candidateCutoff,
        String matchFieldsCsv,
        Integer remainingMergeLimit
    ) {
        this.batchJobId = batchJobId;
        this.candidateCutoff = candidateCutoff == null ? System.now().addDays(-1) : candidateCutoff;
        this.matchFieldsCsv = matchFieldsCsv;
        this.remainingMergeLimit = (remainingMergeLimit == null || remainingMergeLimit <= 0)
            ? null
            : remainingMergeLimit;
    }

    public void execute(SchedulableContext sc) {
        runOnce();
    }

    public static String scheduleFirstRun(
        Id batchJobId,
        Datetime candidateCutoff,
        String matchFieldsCsv,
        Integer maxMerges
    ) {
        return scheduleAt(
            new DHM_ContactMergeWorker(batchJobId, candidateCutoff, matchFieldsCsv, maxMerges),
            System.now().addMinutes(1),
            'DHM Contact Merge ' + String.valueOf(batchJobId)
        );
    }

    @TestVisible
    private void runOnce() {
        Integer mergesThisRun = 0;
        Integer errorsThisRun = 0;
        Set<String> attemptedPairs = new Set<String>();

        List<Contact> queued = [
            SELECT Id, Duplicate_Check_Candidate__c
            FROM Contact
            WHERE Duplicate_Check_Candidate__c != null
              AND LastModifiedDate >= :candidateCutoff
            ORDER BY LastModifiedDate ASC, Id ASC
            LIMIT :QUERY_LIMIT
        ];

        for (Contact queuedContact : queued) {
            if (mergesThisRun >= MERGES_PER_RUN ||
                (remainingMergeLimit != null && mergesThisRun >= remainingMergeLimit)) {
                break;
            }

            Id candidateId = queuedContact.Duplicate_Check_Candidate__c;
            String pairKey = buildPairKey(queuedContact.Id, candidateId);
            if (attemptedPairs.contains(pairKey)) {
                continue;
            }
            attemptedPairs.add(pairKey);

            try {
                DHM_SingleContactMerge.Result result =
                    DHM_SingleContactMergeService.mergeKnownCandidatePair(
                        queuedContact.Id,
                        candidateId,
                        matchFieldsCsv
                    );

                if (result != null && result.merged) {
                    mergesThisRun++;
                    clearCandidateAndError(result.masterContactId);
                } else {
                    clearCandidateOnly(queuedContact.Id);
                }
            } catch (Exception e) {
                errorsThisRun++;
                setContactError(
                    queuedContact.Id,
                    '***** DHM_ContactMergeWorker Contact Id=' +
                    String.valueOf(queuedContact.Id) +
                    ' Candidate Id=' + String.valueOf(candidateId) +
                    ' Exception: ' + e.getMessage()
                );
            }
        }

        Integer nextRemaining = remainingMergeLimit == null
            ? null
            : Math.max(0, remainingMergeLimit - mergesThisRun);

        Boolean hasMore = nextRemaining == null || nextRemaining > 0;
        if (hasMore) {
            hasMore = [
                SELECT COUNT()
                FROM Contact
                WHERE Duplicate_Check_Candidate__c != null
                  AND LastModifiedDate >= :candidateCutoff
            ] > 0;
        }

        DHM_JobLogService.recordContactMergeWorkerProgress(
            batchJobId,
            mergesThisRun,
            errorsThisRun,
            hasMore
        );

        if (hasMore && !Test.isRunningTest()) {
            scheduleAt(
                new DHM_ContactMergeWorker(
                    batchJobId,
                    candidateCutoff,
                    matchFieldsCsv,
                    nextRemaining
                ),
                System.now().addMinutes(RESCHEDULE_MINUTES),
                'DHM Contact Merge Continue ' + String.valueOf(batchJobId)
            );
        }
    }

    private static String scheduleAt(DHM_ContactMergeWorker worker, Datetime whenToRun, String baseName) {
        String cron = String.valueOf(whenToRun.second()) + ' ' +
            String.valueOf(whenToRun.minute()) + ' ' +
            String.valueOf(whenToRun.hour()) + ' ' +
            String.valueOf(whenToRun.day()) + ' ' +
            String.valueOf(whenToRun.month()) + ' ? ' +
            String.valueOf(whenToRun.year());
        String jobName = baseName + ' ' + String.valueOf(whenToRun.getTime());
        return System.schedule(jobName, cron, worker);
    }

    private static void clearCandidateAndError(Id contactId) {
        if (contactId == null) return;
        Contact updateContact = new Contact(Id = contactId, Duplicate_Check_Candidate__c = null);
        DHM_SharedCode.ClearDuplicateCheckError(updateContact);
        Database.update(updateContact, false);
    }

    private static void clearCandidateOnly(Id contactId) {
        if (contactId == null) return;
        Database.update(new Contact(Id = contactId, Duplicate_Check_Candidate__c = null), false);
    }

    private static void setContactError(Id contactId, String message) {
        if (contactId == null) return;
        Contact updateContact = new Contact(Id = contactId, Duplicate_Check_Candidate__c = null);
        DHM_SharedCode.LogAndSetError(updateContact, message);
        Database.update(updateContact, false);
    }

    private static String buildPairKey(Id firstId, Id secondId) {
        String first = String.valueOf(firstId);
        String second = String.valueOf(secondId);
        return first.compareTo(second) <= 0 ? first + ':' + second : second + ':' + first;
    }
}
