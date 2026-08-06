public without sharing class DHM_SharedCode_Contact {

    public class DHM_SharedCode_ContactException extends Exception {}

    private void BackfillBlankFields(
        Contact updateRecord,
        Set<String> blankFields,
        List<String> availableFieldValues
    ) {
        for (String fieldName : blankFields) {
            if (availableFieldValues.isEmpty()) {
                break;
            }

            String fieldValue = String.valueOf(updateRecord.get(fieldName));
            if (String.isBlank(fieldValue)) {
                try {
                    String availableFieldValue = availableFieldValues[0];
                    availableFieldValues.remove(availableFieldValues.indexOf(availableFieldValue));
                    updateRecord.put(fieldName, availableFieldValue);
                } catch (Exception e) {
                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.ERROR,
                        '***** DHM_SharedCode_Object::ObjectsFieldMerge_Contact_BackfillFields Update Merge Field - fieldName: ' +
                        fieldName + ' Exception: ' + String.valueOf(e.getMessage())
                    );
                }
            }
        }
    }

    private void BackfillCheckFields(
        String fieldName,
        String updateFieldValue,
        String availableFieldValue,
        Set<String> usedFieldValues,
        Set<String> blankFields,
        List<String> availableFieldValues
    ) {
        if (!String.isBlank(updateFieldValue)) {
            usedFieldValues.add(updateFieldValue);

            while (availableFieldValues.contains(updateFieldValue)) {
                availableFieldValues.remove(availableFieldValues.indexOf(updateFieldValue));
            }
        } else {
            blankFields.add(fieldName);
        }

        if (!String.isBlank(availableFieldValue) && !usedFieldValues.contains(availableFieldValue)) {
            availableFieldValues.add(availableFieldValue);
        }
    }

    public Contact ObjectsFieldMerge(Contact masterObject, List<Contact> duplicateObjects) {

        Set<Id> mergeCandidates = new Set<Id>{ masterObject.Id };
        for (Contact objectItem : duplicateObjects) {
            mergeCandidates.add(objectItem.Id);
        }

        Map<String, Schema.SObjectField> objectFields = Schema.SObjectType.Contact.fields.getMap();
        Map<String, Schema.DescribeFieldResult> fieldMap = new Map<String, Schema.DescribeFieldResult>();

        String strSoql = 'SELECT ';
        for (String fieldName : objectFields.keySet()) {

            Schema.SObjectField f = objectFields.get(fieldName);
            Schema.DescribeFieldResult fResult = f.getDescribe();

            if (DHM_SharedCode.isSafeMergeField(fieldName, fResult)) {
                String relName = fResult.getRelationshipName();
                if (String.isBlank(relName)) {
                    strSoql += (fieldName + ',');
                } else {
                    continue;
                }

                fieldMap.put(fieldName, fResult);
            }
        }

        strSoql += ' Id FROM Contact WHERE Id IN ' + DHM_SharedCode.GetSafeSoqlList(mergeCandidates);
        strSoql += ' LIMIT ' + String.valueOf(DHM_SharedCode.GetMaximumLimitSize(1));

        Contact masterUpdateObject = new Contact(
            Id = masterObject.Id
        );

        Contact masterUniqueObjectQuery = new Contact(
            Id = masterObject.Id
        );

        List<Contact> objectList;
        try {
            objectList = Database.query(strSoql);

            if (objectList == null || objectList.size() != mergeCandidates.size()) {
                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.ERROR,
                    '***** DHM_SharedCode_Contact::ObjectsFieldMerge Query failed to return expected number of objects'
                );
                return null;
            }

            Contact masterObjectQuery = null;
            for (Integer objectIndex = 0; objectIndex < objectList.size(); objectIndex++) {
                if (objectList[objectIndex].Id == masterObject.Id) {
                    masterObjectQuery = objectList[objectIndex];
                    break;
                }
            }

            if (masterObjectQuery == null) {
                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.ERROR,
                    '***** DHM_SharedCode_Contact::ObjectsFieldMerge Query failed to find the master record fields'
                );
                return null;
            }

            List<DHM_Merge_Contact_History__c> insertMergeHistories = new List<DHM_Merge_Contact_History__c>();

            Set<String> masterUsedEmailValues = new Set<String>();
            Set<String> masterBlankEmailFields = new Set<String>();
            List<String> availableEmailValues = new List<String>();
            Set<String> masterUsedPhoneValues = new Set<String>();
            Set<String> masterBlankPhoneFields = new Set<String>();
            List<String> availablePhoneValues = new List<String>();
            Set<String> addressTypesSkip = new Set<String>();

            for (Contact objectItem : objectList) {
                if (masterObjectQuery.Id == objectItem.get('Id')) {
                    for (String addressType : DHM_SharedCode_Object.AddressTypesAvailable) {
                        for (String addressField : DHM_SharedCode_Object.AddressFieldsAvailable) {
                            DHM_SharedCode.OutputDebugLogText(
                                LoggingLevel.DEBUG,
                                '***** DHM_SharedCode_Contact::ObjectsFieldMerge - check address field: ' +
                                addressType + addressField
                            );

                            try {
                                if (masterObjectQuery.get(addressType + addressField) != null &&
                                    !String.isBlank(String.valueOf(masterObjectQuery.get(addressType + addressField)))) {

                                    DHM_SharedCode.OutputDebugLogText(
                                        LoggingLevel.DEBUG,
                                        '***** DHM_SharedCode_Contact::ObjectsFieldMerge - skip address field: ' +
                                        addressType + addressField
                                    );

                                    addressTypesSkip.add(addressType);
                                    break;
                                }
                            } catch (Exception e) {
                                if (!e.getMessage().contains('Invalid field')) {
                                    DHM_SharedCode.OutputDebugLogText(
                                        LoggingLevel.ERROR,
                                        '***** DHM_SharedCode_Contact::ObjectsFieldMerge check address field exception: ' +
                                        String.valueOf(e.getMessage())
                                    );
                                }
                            }
                        }
                    }

                    break;
                }
            }

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_SharedCode_Contact::ObjectsFieldMerge - addressTypesSkip: ' + addressTypesSkip
            );

            DHM_Settings__c massMergeConfigSettings = DHM_Settings__c.getOrgDefaults();
            Boolean writeAllMergeHistoryFields =
                massMergeConfigSettings == null ? false : massMergeConfigSettings.Merge_History_Write_All__c;

            for (Contact objectItem : objectList) {

                if (masterObjectQuery.Id == objectItem.get('Id')) {
                    continue;
                }

                String mergeActionIgnore = 'Ignore Duplicate';
                String mergeActionUse = 'Use Duplicate';
                String mergeActionError = 'Error';

                insertMergeHistories.add(new DHM_Merge_Contact_History__c(
                    Contact__c = masterObjectQuery.Id,
                    Merge_Value__c = masterObjectQuery.Id,
                    Ignore_Value__c = String.valueOf(objectItem.get('Id')),
                    Field__c = 'Id',
                    Action__c = mergeActionIgnore
                ));

                for (String fieldName : fieldMap.keySet()) {

                    String mergeAction = mergeActionIgnore;
                    Boolean skipMasterFieldUpdate = false;
                    String masterFieldValue = String.valueOf(masterObjectQuery.get(fieldName));
                    String duplicateFieldValue = String.valueOf(objectItem.get(fieldName));

                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.DEBUG,
                        '***** DHM_SharedCode_Contact::ObjectsFieldMerge - fieldName: ' +
                        fieldName + ' masterFieldValue: ' + masterFieldValue +
                        ' duplicateFieldValue: ' + duplicateFieldValue
                    );

                    if (DHM_SharedCode_Object.ObjectsFieldMerge_Contact_HandlePhone(fieldName, fieldMap.get(fieldName))) {
                        this.BackfillCheckFields(
                            fieldName,
                            masterFieldValue,
                            duplicateFieldValue,
                            masterUsedPhoneValues,
                            masterBlankPhoneFields,
                            availablePhoneValues
                        );
                    }

                    if (DHM_SharedCode_Object.ObjectsFieldMerge_Contact_HandleEmail(fieldName, fieldMap.get(fieldName))) {
                        this.BackfillCheckFields(
                            fieldName,
                            masterFieldValue,
                            duplicateFieldValue,
                            masterUsedEmailValues,
                            masterBlankEmailFields,
                            availableEmailValues
                        );
                    }

                    for (String addressType : addressTypesSkip) {
                        for (String addressField : DHM_SharedCode.AddressFieldsAvailable) {
                            if (fieldName.equalsIgnoreCase(addressType + addressField)) {
                                DHM_SharedCode.OutputDebugLogText(
                                    LoggingLevel.DEBUG,
                                    '***** DHM_SharedCode_Contact::ObjectsFieldMerge - skip address field: ' +
                                    fieldName
                                );
                                skipMasterFieldUpdate = true;
                            }
                        }
                    }

                    Boolean writeHistoryRecord = false;
                    if (skipMasterFieldUpdate) {
                        if (!String.isBlank(duplicateFieldValue) && masterFieldValue != duplicateFieldValue) {
                            writeHistoryRecord = true;
                        }
                    } else {
                        if (String.isBlank(masterFieldValue) && !String.isBlank(duplicateFieldValue)) {
                            writeHistoryRecord = writeAllMergeHistoryFields;

                            try {
                                if (fieldMap.get(fieldName).isUnique()) {
                                    masterUniqueObjectQuery.put(fieldName, objectItem.get(fieldName));
                                } else {
                                    masterUpdateObject.put(fieldName, objectItem.get(fieldName));
                                }

                                mergeAction = mergeActionUse;

                            } catch (Exception e) {
                                DHM_SharedCode.OutputDebugLogText(
                                    LoggingLevel.ERROR,
                                    '***** DHM_SharedCode_Contact::ObjectsFieldMerge Update Merge Standard Field - fieldName: ' +
                                    fieldName + ' Exception: ' + String.valueOf(e.getMessage())
                                );
                                mergeAction = mergeActionError;
                                return null;
                            }
                        } else if (!String.isBlank(masterFieldValue) &&
                                   !String.isBlank(duplicateFieldValue) &&
                                   masterFieldValue != duplicateFieldValue) {
                            writeHistoryRecord = true;
                        }
                    }

                    if (writeHistoryRecord) {
                        insertMergeHistories.add(new DHM_Merge_Contact_History__c(
                            Contact__c = masterObjectQuery.Id,
                            Merge_Value__c = String.isBlank(masterFieldValue) ? '(blank)' : masterFieldValue,
                            Ignore_Value__c = String.isBlank(duplicateFieldValue) ? '(blank)' : duplicateFieldValue,
                            Field__c = fieldName,
                            Action__c = mergeAction
                        ));
                    }
                }
            }

            this.BackfillBlankFields(masterUpdateObject, masterBlankEmailFields, availableEmailValues);
            this.BackfillBlankFields(masterUpdateObject, masterBlankPhoneFields, availablePhoneValues);

            Map<String, Object> populatedFields = masterUpdateObject.getPopulatedFieldsAsMap();
            Boolean hasStandardFieldUpdates = populatedFields != null && populatedFields.size() > 1;

            if (hasStandardFieldUpdates) {
                Database.SaveResult updateResult = Database.update(masterUpdateObject, false);
                if (!updateResult.isSuccess()) {

                    for (Database.Error resultError : updateResult.getErrors()) {
                        DHM_SharedCode.LogDatabaseError(
                            resultError,
                            String.valueOf(this).substring(0, String.valueOf(this).indexOf(':')) + '::ObjectsFieldMerge'
                        );
                    }

                    DHM_SharedCode.OutputDebugLogText(
                        LoggingLevel.ERROR,
                        '***** DHM_SharedCode_Contact::ObjectsFieldMerge - Database.update: ' + updateResult
                    );
                    return null;
                }
            }

            if (!insertMergeHistories.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(insertMergeHistories, false);
                for (Database.SaveResult insertResult : insertResults) {
                    if (!insertResult.isSuccess()) {
                        for (Database.Error resultError : insertResult.getErrors()) {
                            DHM_SharedCode.LogDatabaseError(
                                resultError,
                                String.valueOf(this).substring(0, String.valueOf(this).indexOf(':')) + '::ObjectsFieldMerge'
                            );
                        }
                    }
                }
            }
        } catch (Exception e) {
            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.ERROR,
                '***** DHM_SharedCode_Contact::ObjectsFieldMerge Update fields exception: ' +
                String.valueOf(e.getMessage())
            );
            return null;
        }

        return masterUniqueObjectQuery;
    }

    public void ObjectsMerge(Contact masterObject, List<Contact> duplicateObjects) {

        if (masterObject == null || duplicateObjects == null || duplicateObjects.isEmpty()) {
            return;
        }

        DHM_SharedCode_Object.ObjectsMerge_Contact(masterObject, duplicateObjects);

        Contact masterObjectUniqueValues = ObjectsFieldMerge(masterObject, duplicateObjects);
        if (masterObjectUniqueValues != null) {

            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_SharedCode_Contact::ObjectsMerge Contact Merge Master: ' +
                masterObject.Id + ' Duplicate: ' + duplicateObjects[0].Id
            );

            Contact mergeMaster = new Contact(Id = masterObject.Id);
            List<Contact> mergeDuplicates = new List<Contact>();

            for (Contact duplicateObject : duplicateObjects) {
                if (duplicateObject != null && duplicateObject.Id != null) {
                    mergeDuplicates.add(new Contact(Id = duplicateObject.Id));
                }
            }

            if (!mergeDuplicates.isEmpty()) {
                Database.MergeResult[] objectResults = Database.merge(mergeMaster, mergeDuplicates, false);

                for (Database.MergeResult res : objectResults) {
                    if (!res.isSuccess()) {
                        for (Database.Error err : res.getErrors()) {
                            DHM_SharedCode.OutputDebugLogText(
                                LoggingLevel.ERROR,
                                '***** DHM_SharedCode_Contact::ObjectsMerge Contact Merge Exception: ' +
                                err.getMessage()
                            );
                        }

                        throw new DHM_SharedCode_ContactException(
                            'Contact Merge Attempt - ' + String.valueOf(res.getErrors())
                        );
                    }
                }
            }

            Database.SaveResult updateResult = Database.update(masterObjectUniqueValues, false);
            if (!updateResult.isSuccess()) {

                for (Database.Error resultError : updateResult.getErrors()) {
                    DHM_SharedCode.LogDatabaseError(
                        resultError,
                        String.valueOf(this).substring(0, String.valueOf(this).indexOf(':')) + '::ObjectsMerge Unique Values'
                    );
                }

                DHM_SharedCode.OutputDebugLogText(
                    LoggingLevel.ERROR,
                    '***** DHM_SharedCode_Contact::ObjectsMerge Unique Values - Database.update: ' + updateResult
                );
            }
        }
    }
}