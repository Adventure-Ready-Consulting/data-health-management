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


    /**
     * Applies DHM exact-match validation to Contact candidates returned by Salesforce
     * Duplicate Rules. Blank CSV means no additional DHM filtering. For configured
     * fields, both values must be non-null and exactly equal; two blanks do not match.
     */
    public static Map<Id, Set<Id>> filterContactCandidatesByAdditionalFields(
        Map<Id, Set<Id>> candidatesBySourceId,
        String additionalMatchFieldsCsv
    ) {
        if (candidatesBySourceId == null || candidatesBySourceId.isEmpty() ||
            String.isBlank(additionalMatchFieldsCsv)) {
            return candidatesBySourceId == null
                ? new Map<Id, Set<Id>>()
                : candidatesBySourceId;
        }

        List<String> fieldNames = parseAndValidateContactFields(additionalMatchFieldsCsv);
        if (fieldNames.isEmpty()) {
            return candidatesBySourceId;
        }

        Set<Id> allContactIds = new Set<Id>();
        allContactIds.addAll(candidatesBySourceId.keySet());
        for (Set<Id> candidateIds : candidatesBySourceId.values()) {
            if (candidateIds != null) {
                allContactIds.addAll(candidateIds);
            }
        }

        if (allContactIds.isEmpty()) {
            return candidatesBySourceId;
        }

        List<String> selectFields = new List<String>{ 'Id' };
        selectFields.addAll(fieldNames);
        List<Contact> contacts = (List<Contact>) Database.query(
            'SELECT ' + String.join(selectFields, ',') +
            ' FROM Contact WHERE Id IN :allContactIds'
        );
        Map<Id, Contact> contactsById = new Map<Id, Contact>(contacts);

        Map<Id, Set<Id>> filtered = new Map<Id, Set<Id>>();
        for (Id sourceId : candidatesBySourceId.keySet()) {
            Set<Id> eligible = new Set<Id>();
            Contact sourceContact = contactsById.get(sourceId);
            Set<Id> candidateIds = candidatesBySourceId.get(sourceId);

            if (sourceContact != null && candidateIds != null) {
                for (Id candidateId : candidateIds) {
                    Contact candidateContact = contactsById.get(candidateId);
                    if (candidateContact != null &&
                        contactsMatchOnAdditionalFields(sourceContact, candidateContact, fieldNames)) {
                        eligible.add(candidateId);
                    }
                }
            }
            filtered.put(sourceId, eligible);
        }
        return filtered;
    }

    public static Set<Id> filterContactCandidatesByAdditionalFields(
        Id sourceContactId,
        Set<Id> candidateIds,
        String additionalMatchFieldsCsv
    ) {
        Map<Id, Set<Id>> inputMap = new Map<Id, Set<Id>>{
            sourceContactId => candidateIds == null ? new Set<Id>() : new Set<Id>(candidateIds)
        };
        Map<Id, Set<Id>> result = filterContactCandidatesByAdditionalFields(
            inputMap,
            additionalMatchFieldsCsv
        );
        return result.containsKey(sourceContactId) ? result.get(sourceContactId) : new Set<Id>();
    }

    @TestVisible
    static List<String> parseAndValidateContactFields(String fieldsCsv) {
        List<String> fieldNames = new List<String>();
        if (String.isBlank(fieldsCsv)) {
            return fieldNames;
        }

        Map<String, Schema.SObjectField> contactFields = Contact.SObjectType.getDescribe().fields.getMap();
        Set<String> seen = new Set<String>();
        for (String rawName : fieldsCsv.split(',')) {
            String fieldName = rawName == null ? '' : rawName.trim();
            if (String.isBlank(fieldName)) {
                continue;
            }
            if (!contactFields.containsKey(fieldName)) {
                throw new DuplicateRuleException(
                    'Invalid Contact field in Additional Match Fields: ' + fieldName
                );
            }
            if (!seen.contains(fieldName)) {
                seen.add(fieldName);
                fieldNames.add(fieldName);
            }
        }
        return fieldNames;
    }

    @TestVisible
    static Boolean contactsMatchOnAdditionalFields(
        Contact sourceContact,
        Contact candidateContact,
        List<String> fieldNames
    ) {
        if (sourceContact == null || candidateContact == null) {
            return false;
        }
        if (fieldNames == null || fieldNames.isEmpty()) {
            return true;
        }

        for (String fieldName : fieldNames) {
            Object sourceValue = sourceContact.get(fieldName);
            Object candidateValue = candidateContact.get(fieldName);

            // Identity validation is intentionally conservative: two blanks do not match.
            if (sourceValue == null || candidateValue == null) {
                return false;
            }
            if (String.valueOf(sourceValue) != String.valueOf(candidateValue)) {
                return false;
            }
        }
        return true;
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


    public static Boolean hasAllRequiredAdditionalMatchFieldValues(
        Contact contactRecord,
        String additionalMatchFieldsCsv
    ) {
        List<String> fieldNames = parseAndValidateContactFields(additionalMatchFieldsCsv);

        if (fieldNames.isEmpty()) {
            return true;
        }

        Map<String, Schema.SObjectField> contactFields =
            Schema.SObjectType.Contact.fields.getMap();

        for (String fieldName : fieldNames) {
            Schema.DescribeFieldResult describeResult =
                contactFields.get(fieldName).getDescribe();

            Object value = contactRecord.get(fieldName);

            if (!isPopulatedForAdditionalMatch(value, describeResult.getType())) {
                return false;
            }
        }

        return true;
    }

    private static Boolean isPopulatedForAdditionalMatch(
        Object value,
        Schema.DisplayType fieldType
    ) {
        if (value == null) {
            return false;
        }

        // Text-like fields must contain at least one non-whitespace character.
        if (
            fieldType == Schema.DisplayType.String ||
            fieldType == Schema.DisplayType.TextArea ||
            fieldType == Schema.DisplayType.Email ||
            fieldType == Schema.DisplayType.Phone ||
            fieldType == Schema.DisplayType.Url ||
            fieldType == Schema.DisplayType.EncryptedString
        ) {
            return !String.isBlank(String.valueOf(value));
        }

        // Date, DateTime, Time, Boolean, numeric, Id/reference, picklist, and
        // other strongly typed field values are considered populated when non-null.
        return true;
    }

}