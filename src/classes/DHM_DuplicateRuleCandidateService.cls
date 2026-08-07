/**
 * Candidate detection backed by Salesforce active Duplicate Rules.
 * Merge eligibility remains in the Account and Contact merge services.
 */
public without sharing class DHM_DuplicateRuleCandidateService {

    @TestVisible
    private static Map<Id, Set<Id>> testCandidatesBySourceId;

    public class DuplicateRuleException extends Exception {}

    public static Set<Id> findCandidates(Id sourceRecordId) {
        if (sourceRecordId == null) {
            return new Set<Id>();
        }
        Map<Id, Set<Id>> results = findCandidates(new Set<Id>{ sourceRecordId });
        return results.containsKey(sourceRecordId)
            ? results.get(sourceRecordId)
            : new Set<Id>();
    }

    public static Map<Id, Set<Id>> findCandidates(Set<Id> sourceRecordIds) {
        Map<Id, Set<Id>> candidatesBySourceId = new Map<Id, Set<Id>>();
        if (sourceRecordIds == null || sourceRecordIds.isEmpty()) {
            return candidatesBySourceId;
        }

        List<Id> orderedIds = new List<Id>(sourceRecordIds);
        orderedIds.sort();
        for (Id sourceId : orderedIds) {
            candidatesBySourceId.put(sourceId, new Set<Id>());
        }

        if (Test.isRunningTest() && testCandidatesBySourceId != null) {
            for (Id sourceId : orderedIds) {
                if (testCandidatesBySourceId.containsKey(sourceId)) {
                    candidatesBySourceId.get(sourceId).addAll(
                        testCandidatesBySourceId.get(sourceId)
                    );
                    candidatesBySourceId.get(sourceId).remove(sourceId);
                }
            }
            return candidatesBySourceId;
        }

        String objectType;
        for (Id sourceId : orderedIds) {
            String currentType = sourceId.getSObjectType().getDescribe().getName();
            if (objectType == null) {
                objectType = currentType;
            } else if (objectType != currentType) {
                throw new DuplicateRuleException(
                    'Duplicate Rule evaluation requires IDs of one object type per call.'
                );
            }
        }

        for (Integer startIndex = 0; startIndex < orderedIds.size(); startIndex += 50) {
            Integer endIndex = Math.min(startIndex + 50, orderedIds.size());
            List<Id> chunk = new List<Id>();
            for (Integer i = startIndex; i < endIndex; i++) {
                chunk.add(orderedIds[i]);
            }

            List<Datacloud.FindDuplicatesResult> ruleResults;
            try {
                ruleResults = Datacloud.FindDuplicatesByIds.findDuplicatesByIds(chunk);
            } catch (Exception e) {
                throw new DuplicateRuleException(
                    'Salesforce Duplicate Rule evaluation failed for ' + objectType +
                    ': ' + e.getMessage()
                );
            }

            for (Integer resultIndex = 0; resultIndex < chunk.size(); resultIndex++) {
                Id sourceId = chunk[resultIndex];
                if (ruleResults == null || resultIndex >= ruleResults.size()) {
                    continue;
                }

                Datacloud.FindDuplicatesResult findResult = ruleResults[resultIndex];
                if (findResult == null || !findResult.isSuccess()) {
                    continue;
                }

                for (Datacloud.DuplicateResult duplicateResult : findResult.getDuplicateResults()) {
                    if (duplicateResult == null) {
                        continue;
                    }
                    for (Datacloud.MatchResult matchResult : duplicateResult.getMatchResults()) {
                        if (matchResult == null || !matchResult.isSuccess()) {
                            continue;
                        }
                        for (Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
                            if (matchRecord == null || matchRecord.getRecord() == null) {
                                continue;
                            }
                            Id candidateId = (Id)matchRecord.getRecord().get('Id');
                            if (candidateId != null && candidateId != sourceId) {
                                candidatesBySourceId.get(sourceId).add(candidateId);
                            }
                        }
                    }
                }
            }
        }

        return candidatesBySourceId;
    }

    @TestVisible
    static void setTestCandidates(Map<Id, Set<Id>> candidatesBySourceId) {
        testCandidatesBySourceId = candidatesBySourceId;
    }

    @TestVisible
    static void clearTestCandidates() {
        testCandidatesBySourceId = null;
    }

    public static Boolean hasTestCandidates() {
        return testCandidatesBySourceId != null;
    }
}