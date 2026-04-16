/*
    Nonprofit Salesforce © 2022 by 501 Commons is licensed under CC BY 4.0
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of 501Commons.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.
 
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/

//
// GENERIC CLASS - modify of the MassMerge_SharedCode_[Object].cls classes then copy to the all the others
//
//      1) Make changes to the class
//      2) Copy/Paste entire class to all other MassMerge_SharedCode_[Object].cls classes
//      3) Search and replace all [Object] references with [Target Object]
//
//  This is a workaround for Generic classes since <T> - Templating not supported in Apex
//

public without sharing class MassMerge_SharedCode_Contact { 

    public class MassMerge_SharedCode_ContactException extends Exception {}

    public static String WhereFilterByMerges(String objectId) {

        // Where update to exclude previously found Contacts
        //
        String strSoqlWhere = '';

        return strSoqlWhere;

        // Disabled exclude to allow different rules to find the same pair because different rules can have different merge settings (e.g., 1 auto merge but the other doesn't)
/*
        Datetime currentDateTime = Datetime.now();
        Integer current24Hour = Integer.valueOf(currentDateTime.format('HH'));
        List<Id> listContactIds = new List<Id>();

        String strSoql = MassMerge_SharedCode.GetC501ContactMergeQuery();
        if (String.isBlank(strSoql)) {
            return '';
        }
        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '*****MassMerge_SharedCode_Contact::WhereFilterByMerges strSoql: ' + strSoql);
        Integer hourMode = math.mod(current24Hour, 3);
        for (Contact_Merge__c mergeRecord :Database.query(strSoql)) {

            Boolean addContact = false;
            Boolean addContactTarget = false;

            switch on hourMode {
                when 1 {
                    addContact = true;
                }
                when 2 {
                    addContactTarget = true;
                }
                when else {
                    addContact = true;
                    addContactTarget = true;
                }
            }

            if (addContact && !listContactIds.contains(mergeRecord.Contact__c)) {
                listContactIds.add(mergeRecord.Contact__c);
            }
            if (addContactTarget && !listContactIds.contains(mergeRecord.Merge_Target_Contact__c)) {
                listContactIds.add(mergeRecord.Merge_Target_Contact__c);
            }
        }

        if (!listContactIds.isEmpty()) {

            Integer offset = (listContactIds.size() <= (24 * 4)) ? listContactIds.size() - 1 : listContactIds.size() / 24;
            Integer startIndex = (listContactIds.size() < (24 * 4)) ? 0 : current24Hour * offset;
            Integer endIndex = startIndex + offset > listContactIds.size() - 1 ? listContactIds.size() - 1 : startIndex + offset;

            Boolean firstItem = true;

            // Salesforce where max length is 4000
            while (startIndex <= endIndex && strSoqlWhere.length() < 3950) {
                if (!firstItem) {
                    strSoqlWhere += ',';
                }
                else {
                    strSoqlWhere += ' and (NOT ' + objectId + ' IN (';
                    firstItem = false;
                }
                strSoqlWhere += '\'' + listContactIds[startIndex++] + '\'';
            }

            if (!firstItem) {
                strSoqlWhere += '))';
            }
        }

        return strSoqlWhere;
*/
    }

    // the list of Contacts
    public List<SelectOption> ListObjects(String mergeRule) {

        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** MassMerge_SharedCode_Contact::ListObjects - mergeRule: ' + mergeRule);

        Map<String, SelectOption> mapSelectOption = new Map<String, SelectOption>();
        mapSelectOption.put('', new SelectOption('', ''));

        String strSoqlFrom = ' FROM Contact_Merge__c';
        String strSoqlWhere = ' WHERE Merge_Action__c = null';
        strSoqlWhere += ' AND isDeleted = false';

        if (!String.isBlank(mergeRule)) {
            strSoqlWhere += ' AND Merge_Metric__r.Name = \'' + mergeRule + '\'';
        }

        String strSoqlSelect = 'SELECT Contact__r.Name, Merge_Target_Contact__r.Name';
        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ListObjects strSoql: ' + strSoqlSelect + strSoqlFrom + strSoqlWhere);
        for (Contact_Merge__c mergeRecord : Database.query(strSoqlSelect + strSoqlFrom + strSoqlWhere)) {

            if (mapSelectOption.size() > MassMerge_SharedCode.MAXIMUM_COLLECTION_SIZE) {
                break;
            }

            try {

                if (String.isBlank(mergeRecord.Contact__c) || String.isBlank(mergeRecord.Contact__r.Name) || String.isBlank(mergeRecord.Merge_Target_Contact__c) || String.isBlank(mergeRecord.Merge_Target_Contact__r.Name)) {
                    continue;
                }
            }
            catch(Exception ex) {

                MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ListObjects Invalid Lookup values to skip - ' + ex.getMessage());
                continue;
            }

            mapSelectOption.put(
                mergeRecord.Contact__r.Name,
                new SelectOption(mergeRecord.Contact__r.Name, mergeRecord.Contact__r.Name));

            mapSelectOption.put(
                mergeRecord.Merge_Target_Contact__r.Name,
                new SelectOption(mergeRecord.Merge_Target_Contact__r.Name, mergeRecord.Merge_Target_Contact__r.Name));
        }

        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ListObjects mapSelectOption: ' + mapSelectOption);

        List<SelectOption> listSOSorted = new List<SelectOption>();
        listSOSorted = MassMerge_SharedCode.SelectOptionSortByLabel(mapSelectOption.values());

        return listSOSorted;
    }

    public void InsertObjectMergeCandidates(List<Contact_Merge__c> mergeObjects) {

        if (mergeObjects == null || mergeObjects.isEmpty()) {
            return;
        }

        //
		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
        //

        Set<String> mergeObjectsExisting = new Set<String>();
        List<Contact_Merge__c> deleteContactMerges = new List<Contact_Merge__c>();

        String strSoql = MassMerge_SharedCode.GetC501ContactMergeQuery();
        if (String.isBlank(strSoql)) {
            return;
        }
        strSoql += ' LIMIT ' + String.valueOf(MassMerge_SharedCode.GetMaximumLimitSize(1));

        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::InsertObjectMergeCandidates strSoql: ' + strSoql);

        for (Contact_Merge__c mergeObject :Database.query(strSoql)) {

            if (mergeObject.Contact__c == null || mergeObject.Merge_Target_Contact__c == null) {

                deleteContactMerges.add(mergeObject);
                continue;
            }

            if (mergeObject.Contact__r.IsDeleted) {

                deleteContactMerges.add(mergeObject);
                continue;
            }

            if (mergeObject.Merge_Target_Contact__r.IsDeleted) {

                deleteContactMerges.add(mergeObject);
                continue;
            }

            mergeObjectsExisting.add(mergeObject.Unique_Id__c);
        }

        if (!deleteContactMerges.isEmpty()) {
           MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::InsertObjectMergeCandidates Remove Invalid Contact Merges: ' + deleteContactMerges);
            Database.delete(deleteContactMerges, false);
        }

		if (mergeObjects <> null && !mergeObjects.isEmpty()) {

            List<Contact_Merge__c> mergeObjectsInsert = new List<Contact_Merge__c>();
            for (Contact_Merge__c mergeObject :mergeObjects) {

                if (!mergeObjectsExisting.contains(mergeObject.Unique_Id__c)) {

                    mergeObjectsInsert.add(mergeObject);
                    mergeObjectsExisting.add(mergeObject.Unique_Id__c);
                }
            }

            if (!mergeObjectsInsert.isEmpty()) {

                Database.UpsertResult[] upsertResults =
                    Database.upsert(
                        mergeObjectsInsert,
                        Contact_Merge__c.Unique_Id__c,
                        false
                    );
            
                for (Database.UpsertResult result : upsertResults) {
                    if (!result.isSuccess()) {
                        for (Database.Error resultError : result.getErrors()) {
                            MassMerge_SharedCode.LogDatabaseError(
                                resultError,
                                String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) +
                                '::InsertObjectMergeCandidates'
                            );
                        }
                    }
                }
            }
        }
    }

    public Integer ProcessObjectMergeCandidates(Merge_Metric__c mergeMetric) {

        //
		// Perform all DML (Data Manipulation Language) calls (insert, update, merge, delete, restore) outside of loop to avoid Salesforce Governor Limits: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
        //

        String mergeMetricName = mergeMetric.Name;

        List<Contact_Merge__c> deleteContactMerges = new List<Contact_Merge__c>();
        List<Contact_Merge__c> pendingMerges = new List<Contact_Merge__c>();
        List<Contact_Merge__c> pendingAutoMerges = new List<Contact_Merge__c>();

        Map<Id, Id> ContactHouseholdMap = new Map<Id, Id>();

        String strSoql = MassMerge_SharedCode.GetC501ContactMergeQuery();
        if (String.isBlank(strSoql)) {
            return 0;
        }
        strSoql += ' AND Merge_Metric__r.Name = :mergeMetricName';
        strSoql += ' LIMIT ' + String.valueOf(MassMerge_SharedCode.GetMaximumLimitSize(1));

        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ProcessObjectMergeCandidates strSoql: ' + strSoql);

        for (Contact_Merge__c mergeObject : Database.Query(strSoql)) {

            if (mergeObject.Contact__c == null || mergeObject.Merge_Target_Contact__c == null ||
                mergeObject.Contact__r.IsDeleted || mergeObject.Merge_Target_Contact__r.IsDeleted) {

                deleteContactMerges.add(mergeObject);
                continue;
            }

            ContactHouseholdMap.put(mergeObject.Contact__c, MassMerge_SharedCode.GetMergeContactHouseholdId(mergeObject));
            ContactHouseholdMap.put(mergeObject.Merge_Target_Contact__c, MassMerge_SharedCode.GetMergeTargetContactHouseholdId(mergeObject));

            if (mergeObject.Merge_Action__c == 'Master') {
                pendingMerges.add(mergeObject);
            }
            else if (String.isBlank(mergeObject.Merge_Action__c)) {
                pendingAutoMerges.add(mergeObject);
            }
        }

        if (!deleteContactMerges.isEmpty()) {
           MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ProcessObjectMergeCandidates Remove Invalid Contact Merges: ' + deleteContactMerges);
            Database.delete(deleteContactMerges, false);
        }

        // Check for batch queued merges
        if (!pendingMerges.isEmpty()) {

            return this.ProcessObjectMerges(new List<Merge_Metric__c> {mergeMetric}, pendingMerges);
        }

        // Check if AutoMerge Enabled
        if (String.isBlank(mergeMetric.AutoMerge_Objects__c)) {
            return 0;
        }

        return MassMerge_SharedCode.ProcessObjectMergeCandidates_Contact(mergeMetric, pendingAutoMerges, ContactHouseholdMap);
    }

    // Legacy Method for Managed Package
    public Integer ProcessObjectMerges(List<Contact_Merge__c> objectMerges)
    {
        return this.ProcessObjectMerges(new List<Merge_Metric__c>(), objectMerges);
    }

    public Integer ProcessObjectMerges(List<Merge_Metric__c> mergeMetrics, List<Contact_Merge__c> objectMerges)
    {
        // Jobs with Status = 'Holding' applies to batch jobs in the Apex flex queue (max allowed 100)
        //  https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/api/sforce_api_objects_asyncapexjob.htm
        List<AsyncApexJob> flexQueueJobs = [SELECT Id FROM AsyncApexJob WHERE Status = 'Holding'];
        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** MassMerge_SharedCode_Contact::ProcessObjectMerges - flexQueueJobs ' + flexQueueJobs);
        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** MassMerge_SharedCode_Contact::ProcessObjectMerges - QueuableJobs ' + Limits.getQueueableJobs() + ' of ' + Limits.getLimitQueueableJobs());
        Integer remainingFlexQueueJobs = Limits.getLimitQueueableJobs() - flexQueueJobs.size();

        Set<String> mergeMetricSet = new Set<String>();
        for (Merge_Metric__c mergeMetric :mergeMetrics) {
            mergeMetricSet.add(mergeMetric.Id);
        }

        Integer numberObjectMerges = 0;
        Set<Id> objectsProcessed = new Set<Id>();
        List<Contact_Merge__c> deleteContactMerges = new List<Contact_Merge__c>();
        for (Contact_Merge__c mergeCandidate : objectMerges) {

            // Check Contact and Target Contact valid
            if (String.isBlank(mergeCandidate.Contact__c) || String.isBlank(mergeCandidate.Merge_Target_Contact__c)) {

                deleteContactMerges.add(mergeCandidate);
                continue;
            }

            // Check Contact and Target Contact same Id
            if (mergeCandidate.Contact__c == mergeCandidate.Merge_Target_Contact__c) {

                deleteContactMerges.add(mergeCandidate);
                continue;
            }

            // Check whether Contact or Target Contact Id merge already attempted
            if (objectsProcessed.contains(mergeCandidate.Contact__c) || objectsProcessed.contains(mergeCandidate.Merge_Target_Contact__c)) {

                deleteContactMerges.add(mergeCandidate);
                continue;
            }

            if (!mergeMetricSet.contains(mergeCandidate.Merge_Metric__c)) {

                String strSoql = MassMerge_SharedCode.GetC501MergeMetricQuery();
                if (String.isBlank(strSoql)) {

                    return numberObjectMerges;
                }

                MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ProcessObjectMerges strSoql: ' + strSoql);

                mergeMetrics = Database.Query(strSoql);

                for (Merge_Metric__c mergeMetric :mergeMetrics) {
                    mergeMetricSet.add(mergeMetric.Id);
                }

                if (!mergeMetricSet.contains(mergeCandidate.Merge_Metric__c)) {
                    throw new MassMerge_SharedCode_ContactException('Contact Merge Data Error - Invalid Merge Metric: ' + mergeCandidate.Merge_Metric__c + ' on Contact Merge Id: ' + mergeCandidate.Id);
                }
            }
            
            objectsProcessed.add(mergeCandidate.Contact__c);
            objectsProcessed.add(mergeCandidate.Merge_Target_Contact__c);

            MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ProcessObjectMerges ObjectsMerge');

            ObjectsMerge( 
                new Contact(
                    Id = mergeCandidate.Contact__c
                ),
                new List<Contact> { new Contact(
                    Id = mergeCandidate.Merge_Target_Contact__c
                )
            } );

            numberObjectMerges++;

            break;
        }

        if (!deleteContactMerges.isEmpty()) {
            MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ProcessObjectMerges Remove Invalid Contact Merges: ' + deleteContactMerges);
            Database.delete(deleteContactMerges, false);
        }

        return numberObjectMerges;
    }

    private void BackfillBlankFields(Contact updateRecord, Set<String> blankFields, List<String> availableFieldValues) {

        for (String fieldName :blankFields) {

            if (availableFieldValues.isEmpty()) {
                break;
            }

            String fieldValue = String.valueOf(updateRecord.get(fieldName));
            if (String.isBlank(fieldValue)) {

                try{
                    String availableFieldValue = availableFieldValues[0];
                    availableFieldValues.remove(availableFieldValues.indexOf(availableFieldValue));
                    updateRecord.put(fieldName, availableFieldValue);
                } catch (Exception e) {
                    MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** MassMerge_SharedCode_Object::ObjectsFieldMerge_Contact_BackfillFields Update Merge Field - fieldName: ' + fieldName + ' Exception: ' + String.valueOf(e.getMessage()));
                }
            }
        }
    }

    private void BackfillCheckFields(String fieldName, String updateFieldValue, String availableFieldValue, Set<String> usedFieldValues, Set<String> blankFields, List<String> availableFieldValues ) {

        if (!String.isBlank(updateFieldValue)) {

            usedFieldValues.add(updateFieldValue);

            while (availableFieldValues.contains(updateFieldValue)) {
                availableFieldValues.remove(availableFieldValues.indexOf(updateFieldValue));
            }
        }
        else {
            blankFields.add(fieldName);
        }

        if (!String.isBlank(availableFieldValue) && !usedFieldValues.contains(availableFieldValue)) {
            availableFieldValues.add(availableFieldValue);
        }
    }

    public Contact ObjectsFieldMerge(Contact masterObject, List<Contact> duplicateObjects) {

        Set<Id> mergeCandidates = new Set<Id> { masterObject.Id };
        for (Contact objectItem : duplicateObjects) {
            mergeCandidates.add(objectItem.Id);
        }

        Map<String, Schema.SObjectField> objectFields = Schema.SObjectType.Contact.fields.getMap();
        Map<String, Schema.DescribeFieldResult> fieldMap = new Map<String, Schema.DescribeFieldResult>();

        String strSoql = 'Select ';
        for (String fieldName : objectFields.keySet()) {

            Schema.SObjectField f = objectFields.get(fieldName);
            Schema.DescribeFieldResult fResult = f.getDescribe();

            if (MassMerge_SharedCode.isSafeMergeField(fieldName, fResult)) {

                String relName = fResult.getRelationshipName();
                if (String.isBlank(relName)) {
                    strSoql += (fieldName + ',');
                } else {
                    continue;
                }

                fieldMap.put(fieldName, fResult);
            }
        }

        strSoql += ' Id FROM Contact WHERE Id IN ' + MassMerge_SharedCode.GetSafeSoqlList(mergeCandidates);
        strSoql += ' LIMIT ' + String.valueOf(MassMerge_SharedCode.GetMaximumLimitSize(1));

        // Sparse update object for normal field updates before merge
        Contact masterUpdateObject = new Contact(
            Id = masterObject.Id
        );

        // Sparse update object for unique fields to attempt after merge
        Contact masterUniqueObjectQuery = new Contact(
            Id = masterObject.Id
        );

        List<Contact> objectList;
        try {

            objectList = Database.query(strSoql);

            if (objectList == null || objectList.size() != mergeCandidates.size()) {
                MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge Query failed to return expected number of objects');
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
                MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge Query failed to find the master record fields');
                return null;
            }

            List<Merge_Contact_History__c> insertMergeHistories = new List<Merge_Contact_History__c>();

            Set<String> masterUsedEmailValues = new Set<String>();
            Set<String> masterBlankEmailFields = new Set<String>();
            List<String> availableEmailValues = new List<String>();
            Set<String> masterUsedPhoneValues = new Set<String>();
            Set<String> masterBlankPhoneFields = new Set<String>();
            List<String> availablePhoneValues = new List<String>();
            Set<String> addressTypesSkip = new Set<String>();

            for (Contact objectItem : objectList) {

                if (masterObjectQuery.Id == objectItem.get('Id')) {

                    for (String addressType : MassMerge_SharedCode_Object.AddressTypesAvailable) {
                        for (String addressField : MassMerge_SharedCode_Object.AddressFieldsAvailable) {

                            MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge - check address field: ' + addressType + addressField);

                            try {
                                if (masterObjectQuery.get(addressType + addressField) != null &&
                                    !String.isBlank(String.valueOf(masterObjectQuery.get(addressType + addressField)))) {

                                    MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge - skip address field: ' + addressType + addressField);

                                    addressTypesSkip.add(addressType);
                                    break;
                                }
                            }
                            catch (Exception e) {
                                if (!e.getMessage().contains('Invalid field')) {
                                    MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge check address field exception: ' + String.valueOf(e.getMessage()));
                                }
                            }
                        }
                    }

                    break;
                }
            }

            MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge - addressTypesSkip: ' + addressTypesSkip);

            Mass_Merge_Config__c massMergeConfigSettings = Mass_Merge_Config__c.getOrgDefaults();
            Boolean writeAllMergeHistoryFields = massMergeConfigSettings == null ? false : massMergeConfigSettings.Merge_History_Write_All__c;

            for (Contact objectItem : objectList) {

                if (masterObjectQuery.Id == objectItem.get('Id')) {
                    continue;
                }

                String mergeActionIgnore = 'Ignore Duplicate';
                String mergeActionUse = 'Use Duplicate';
                String mergeActionError = 'Error';

                insertMergeHistories.add(new Merge_Contact_History__c(
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

                    MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge - fieldName: ' + fieldName + ' masterFieldValue: ' + masterFieldValue + ' duplicateFieldValue: ' + duplicateFieldValue);

                    if (MassMerge_SharedCode_Object.ObjectsFieldMerge_Contact_HandlePhone(fieldName, fieldMap.get(fieldName))) {
                        this.BackfillCheckFields(fieldName, masterFieldValue, duplicateFieldValue, masterUsedPhoneValues, masterBlankPhoneFields, availablePhoneValues);
                    }

                    if (MassMerge_SharedCode_Object.ObjectsFieldMerge_Contact_HandleEmail(fieldName, fieldMap.get(fieldName))) {
                        this.BackfillCheckFields(fieldName, masterFieldValue, duplicateFieldValue, masterUsedEmailValues, masterBlankEmailFields, availableEmailValues);
                    }

                    for (String addressType : addressTypesSkip) {
                        for (String addressField : MassMerge_SharedCode.AddressFieldsAvailable) {
                            if (fieldName.equalsIgnoreCase(addressType + addressField)) {
                                MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge - skip address field: ' + fieldName);
                                skipMasterFieldUpdate = true;
                            }
                        }
                    }

                    Boolean writeHistoryRecord = false;
                    if (skipMasterFieldUpdate) {
                        if (!String.isBlank(duplicateFieldValue) && masterFieldValue <> duplicateFieldValue) {
                            writeHistoryRecord = true;
                        }
                    }
                    else {
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
                                MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge Update Merge Standard Field - fieldName: ' + fieldName + ' Exception: ' + String.valueOf(e.getMessage()));
                                mergeAction = mergeActionError;
                                return null;
                            }
                        }
                        else if (!String.isBlank(masterFieldValue) && !String.isBlank(duplicateFieldValue) && masterFieldValue <> duplicateFieldValue) {
                            writeHistoryRecord = true;
                        }
                    }

                    if (writeHistoryRecord) {
                        insertMergeHistories.add(new Merge_Contact_History__c(
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
                        MassMerge_SharedCode.LogDatabaseError(
                            resultError,
                            String.valueOf(this).substring(0, String.valueOf(this).indexOf(':')) + '::ObjectsFieldMerge'
                        );
                    }

                    MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge - Database.update: ' + updateResult);
                    return null;
                }
            }

            if (!insertMergeHistories.isEmpty()) {
                Database.SaveResult[] insertResults = Database.insert(insertMergeHistories, false);
                for (Database.SaveResult insertResult : insertResults) {
                    if (!insertResult.isSuccess()) {
                        for (Database.Error resultError : insertResult.getErrors()) {
                            MassMerge_SharedCode.LogDatabaseError(resultError, String.valueOf(this).substring(0, String.valueOf(this).indexOf(':')) + '::ObjectsFieldMerge');
                        }
                    }
                }
            }
        } catch (Exception e) {

            MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** MassMerge_SharedCode_Contact::ObjectsFieldMerge Update fields exception: ' + String.valueOf(e.getMessage()));
            return null;
        }

        MassMerge_SharedCode.OutputDebugLogFlush();
        return masterUniqueObjectQuery;
    }

    public void ObjectsMerge(Contact masterObject, List<Contact> duplicateObjects) {

        if (masterObject == null || duplicateObjects == null || duplicateObjects.isEmpty()) {
            return;
        }

        MassMerge_SharedCode_Object.ObjectsMerge_Contact(masterObject, duplicateObjects);

        // Merge fields into master
        Contact masterObjectUniqueValues = ObjectsFieldMerge(masterObject, duplicateObjects);
        if (masterObjectUniqueValues != null) {

            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** MassMerge_SharedCode_Contact::ObjectsMerge Contact Merge Master: ' +
                masterObject.Id + ' Duplicate: ' + duplicateObjects[0].Id
            );

            // IMPORTANT:
            // Use sparse Id-only sObjects for the actual merge DML so readonly/system
            // fields like CreatedDate do not ride along into the merge.
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
                            MassMerge_SharedCode.OutputDebugLogText(
                                LoggingLevel.ERROR,
                                '***** MassMerge_SharedCode_Contact::ObjectsMerge Contact Merge Exception: ' +
                                err.getMessage()
                            );
                        }

                        throw new MassMerge_SharedCode_ContactException(
                            'Contact Merge Attempt - ' + String.valueOf(res.getErrors())
                        );
                    }
                }
            }

            // Attempt to update unique values since the duplicate object is now deleted
            // If any failures in here they can be ignored because just making an attempt
            // to bring over Unique Values after the merge is already over
            Database.SaveResult updateResult = Database.update(masterObjectUniqueValues, false);
            if (!updateResult.isSuccess()) {

                for (Database.Error resultError : updateResult.getErrors()) {
                    MassMerge_SharedCode.LogDatabaseError(
                        resultError,
                        String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ObjectsMerge Unique Values'
                    );
                }

                MassMerge_SharedCode.OutputDebugLogText(
                    LoggingLevel.ERROR,
                    '***** MassMerge_SharedCode_Contact::ObjectsMerge Unique Values - Database.update: ' + updateResult
                );
            }
        }

        Set<Id> objectIds = new Set<Id> { masterObject.Id };
        for (Contact duplicateObject : duplicateObjects) {
            objectIds.add(duplicateObject.Id);
        }

        String strSoql = MassMerge_SharedCode.GetC501ContactMergeQuery();
        if (String.isBlank(strSoql)) {
            return;
        }

        strSoql += ' AND (Contact__c = null OR Merge_Target_Contact__c = null OR Contact__c in ' +
            MassMerge_SharedCode.GetSafeSoqlList(objectIds) +
            ' OR Merge_Target_Contact__c in ' +
            MassMerge_SharedCode.GetSafeSoqlList(objectIds) + ')';

        strSoql += ' LIMIT ' + String.valueOf(MassMerge_SharedCode.GetMaximumLimitSize(1));

        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ObjectsMerge strSoql: ' + strSoql
        );

        List<Contact_Merge__c> deleteContactMerges = Database.query(strSoql);

        if (!deleteContactMerges.isEmpty()) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** ' + String.valueOf(this).substring(0,String.valueOf(this).indexOf(':')) + '::ProcessObjectMerges Remove Invalid Contact Merges: ' + deleteContactMerges
            );
            Database.delete(deleteContactMerges, false);
        }

        MassMerge_SharedCode.OutputDebugLogFlush();
    }
}