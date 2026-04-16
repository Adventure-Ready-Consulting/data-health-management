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

public without sharing class C501_MassMerge_SharedCode { 

    public enum MergeObjectScenarios { Account, Contacts_Within_Account, Contacts_Across_Accounts }

    public static final Integer INCREMENT_MERGE_CANDIDATE_GROUPBY = 5;
    public static final Integer SALESFORCE_MAXIMUM_COLLECTION_SIZE = 250;

    // Actual Maximum Collection Size is 1000
    public static final Integer MAXIMUM_COLLECTION_SIZE = 990;
    
    // Available Fields for merging
    //
    public static Set<String> AddressTypesAvailable = new Set<String> {'Mailing', 'Shipping', 'Other', 'Billing'};
    public static Set<String> AddressFieldsAvailable = new Set<String> {'City', 'Country', 'GeocodeAccuracy', 'Latitude', 'Longitude', 'PostalCode', 'State', 'Street'};

    public static Boolean isSafeMergeField(String fieldName, Schema.DescribeFieldResult fResult) {
        if (String.isBlank(fieldName) || fResult == null) {
            return false;
        }
    
        Set<String> blockedFields = new Set<String>{
            'Id',
            'IsDeleted',
            'CreatedDate',
            'CreatedById',
            'LastModifiedDate',
            'LastModifiedById',
            'SystemModstamp',
            'LastActivityDate',
            'LastViewedDate',
            'LastReferencedDate',
            'MasterRecordId'
        };
    
        if (blockedFields.contains(fieldName)) {
            return false;
        }
    
        if (!fResult.isAccessible() || !fResult.isUpdateable()) {
            return false;
        }
    
        if (fResult.isCalculated()) {
            return false;
        }
    
        if (fResult.isAutoNumber()) {
            return false;
        }
    
        if (!String.isBlank(fResult.getRelationshipName())) {
            return false;
        }
    
        if (C501_MassMerge_SharedCode.isNPSPHiddenField(fieldName)) {
            return false;
        }
    
        return true;
    }
            
    public static Integer MaximumDiscoverHavingCount {
        get {
            Mass_Merge_Config__c massMergeConfigSettings = Mass_Merge_Config__c.getOrgDefaults();
            if (massMergeConfigSettings <> null && massMergeConfigSettings.Maximum_Discover_Having_Count__c > 0) {
                return Integer.valueOf(massMergeConfigSettings.Maximum_Discover_Having_Count__c);
            }
    
            return 10;
        }
        set;
    }   

    private static boolean fCheckedForMaximumSalesforceLimitsToUse = false;
    public static Integer MaximumSalesforceLimitsToUse {
        get {

            if (!fCheckedForMaximumSalesforceLimitsToUse) {
                Mass_Merge_Config__c massMergeConfigSettings = Mass_Merge_Config__c.getOrgDefaults();
                if (massMergeConfigSettings <> null && massMergeConfigSettings.Maximum_Salesforce_Limits_to_Use__c <> null) {

                    MaximumSalesforceLimitsToUse = Integer.valueOf(massMergeConfigSettings.Maximum_Salesforce_Limits_to_Use__c);
                    fCheckedForMaximumSalesforceLimitsToUse = true; 
                } else {
                    MaximumSalesforceLimitsToUse = 50;
                }
            }

            return MaximumSalesforceLimitsToUse;
        }
        set;
    }   

    // public utility used to detect whether the Non Profit Starter Pack is installed in this instance.
    private static boolean fCheckedForNPSP = false;
    public static boolean IsNPSPInstalled {
        get {
            if (!fCheckedForNPSP) {
                Schema.SObjectType token = Schema.getGlobalDescribe().get('npe01__OppPayment__c');
                IsNPSPInstalled = (token != null);
                fCheckedForNPSP = true;
            }
            return IsNPSPInstalled;
        }
        set;
    }   

    // public utility used to get current namespace
    private static boolean fCheckedForCurrentNamespace = false;
    public static String CurrentNamespace {
        get {
            if (!fCheckedForCurrentNamespace) {
                String thisClassName = C501_MassMerge_SharedCode.class.getName();
                if (thisClassName.contains('.')) {
                    CurrentNamespace = thisClassName.split('\\.')[0] + '__';
                }
                fCheckedForCurrentNamespace = true;
            }
            return CurrentNamespace;
        }
        set;
    }   

    private static Boolean fCheckedIsSandbox = false;
    public static Boolean IsSandbox {
        get {
            if (!fCheckedIsSandbox) {
                IsSandbox = true;
                List<Organization> organizations = [SELECT IsSandbox FROM Organization LIMIT 1];
                if (!organizations.isEmpty()) {
                    IsSandbox = Boolean.valueOf(organizations[0].IsSandbox);
                }
                fCheckedIsSandbox = true;
            }

            return IsSandbox;
        }

        set;
    }

    public static List<String> MultiSelectPickListToList(String multiSelectPickList) {

        List<String> multiSelectList = new List<String>();
        
        if (String.isBlank(multiSelectPickList)) {
            return multiSelectList;
        }

        if (multiSelectPickList.contains(';')) {
            multiSelectList = multiSelectPickList.split(';');
        }
        else {
            multiSelectList.add(multiSelectPickList);
        }

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '*****C501_MassMerge_SharedCode::MultiSelectPickListToList multiSelectList: ' + multiSelectList);
        return multiSelectList;
    }

    public static final Integer MAX_RETRY_DATABASE = 5;
    public static Boolean RetryDatabaseError(Database.Error resultError) {

        String statusCode = String.valueOf(resultError.getStatusCode());

        // UNABLE_TO_LOCK_ROW because can happen with all the event firing so retry
        if (statusCode.contains('UNABLE_TO_LOCK_ROW')) {
            return true;
        }

        return false;
    }

    public static Boolean LogDatabaseError(Database.Error resultError, String callingMethod) {

        String statusCode = String.valueOf(resultError.getStatusCode());

        // Sandbox ignore the INVALID_CROSS_REFERENCE_KEY expection because there is partial data in Sandbox
        if (C501_MassMerge_SharedCode.IsSandbox && (statusCode.contains('INVALID_CROSS_REFERENCE_KEY') || statusCode.contains('INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY'))) {
            return false;
        }

        // Ignore Duplicate Value on Unique_Id__c because just inserting and using DB to filter what is already in the table
        if (resultError.getMessage().containsIgnoreCase('DUPLICATE_VALUE') && resultError.getMessage().containsIgnoreCase('Unique_Id__c')) {
            return false;
        }

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** ' + callingMethod + ' Database.SaveResult Error');
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, statusCode + ': ' + resultError.getMessage());
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, 'Fields that affected this error: ' + resultError.getFields());

        return true;
    }

    public static String GetMergeContactHouseholdId(C501_Contact_Merge__c mergeObject) {
        return mergeObject.Contact__r.AccountId;
    }

    public static String GetMergeTargetContactHouseholdId(C501_Contact_Merge__c mergeObject) {
        return mergeObject.Merge_Target_Contact__r.AccountId;
    }

    public static String GetMergeAccountHouseholdId(C501_Account_Merge__c mergeObject) {
        return mergeObject.Account__c;
    }

    public static String GetMergeTargetAccountHouseholdId(C501_Account_Merge__c mergeObject) {
        return mergeObject.Merge_Target_Account__c;
    }

    //
    //  Logging Thread: https://salesforce.stackexchange.com/questions/10624/can-i-prevent-an-insert-to-be-rolled-back-even-if-my-class-later-runs-into-an/10626
    //      Ideas on how to structure for future improvement ideas
    //

    private static List<C501_Debug_Log__c> insertDebugLogs = new List<C501_Debug_Log__c>();

    private static Boolean fLogConfigLoaded = false;
    private static Boolean fEnableDebugLogging = false;
    private static Boolean fEnableErrorLogging = false;
    private static String fLogFilters = '';

    static final Integer MAX_DEBUG_LOG_TEXT_SIZE = 32768;

    private static void LoadLogConfig() {
        if (fLogConfigLoaded) {
            return;
        }

        Mass_Merge_Config__c massMergeConfigSettings = Mass_Merge_Config__c.getOrgDefaults();

        fEnableDebugLogging =
            (massMergeConfigSettings == null)
            ? false
            : massMergeConfigSettings.Enable_Debug_Logging__c;

        fEnableErrorLogging =
            (massMergeConfigSettings == null)
            ? false
            : massMergeConfigSettings.Enable_Error_Logging__c;

        fLogFilters =
            (massMergeConfigSettings == null || String.isBlank(massMergeConfigSettings.Log_Filter__c))
            ? ''
            : massMergeConfigSettings.Log_Filter__c;

        fLogConfigLoaded = true;
    }

    private static Boolean ShouldIgnoreLogMessage(String logMessage) {
        if (String.isBlank(fLogFilters) || String.isBlank(logMessage)) {
            return false;
        }

        for (String logFilter : fLogFilters.split(',')) {
            String trimmedFilter = logFilter == null ? '' : logFilter.trim();
            if (!String.isBlank(trimmedFilter) && logMessage.containsIgnoreCase(trimmedFilter)) {
                return false;
            }
        }

        return true;
    }

    public static void OutputDebugLogFlush() {

        if (Test.isRunningTest()) {
            return;
        }

        // Clear out logs > 24 hours
        List<C501_Debug_Log__c> deleteDebugLogs = [
            SELECT Id
            FROM C501_Debug_Log__c
            WHERE isDeleted = false
            AND CreatedDate < TODAY
            LIMIT :GetMaximumDMLLimitSize()
        ];

        if (!deleteDebugLogs.isEmpty()) {
            Database.DeleteResult[] deleteResults = Database.delete(deleteDebugLogs, false);

            for (Database.DeleteResult deleteResult : deleteResults) {
                if (!deleteResult.isSuccess()) {
                    for (Database.Error resultError : deleteResult.getErrors()) {
                        System.debug(
                            LoggingLevel.ERROR,
                            '***** C501_MassMerge_SharedCode::OutputDebugLogFlush delete Debug Logs ERROR ' +
                            String.valueOf(resultError.getStatusCode()) + ': ' +
                            resultError.getMessage()
                        );
                    }
                }
            }
        }

        if (!insertDebugLogs.isEmpty()) {

            List<C501_Debug_Log__c> logsToInsert = new List<C501_Debug_Log__c>();
            logsToInsert.addAll(insertDebugLogs);

            Boolean insertError = false;

            Database.SaveResult[] insertResults = Database.insert(logsToInsert, false);
            for (Integer i = 0; i < insertResults.size(); i++) {
                if (!insertResults[i].isSuccess()) {
                    insertError = true;

                    for (Database.Error resultError : insertResults[i].getErrors()) {
                        System.debug(
                            LoggingLevel.ERROR,
                            '***** C501_MassMerge_SharedCode::OutputDebugLogFlush insert Debug Logs ERROR ' +
                            'index=' + String.valueOf(i) + ', ' +
                            String.valueOf(resultError.getStatusCode()) + ': ' +
                            resultError.getMessage()
                        );
                    }
                }
            }

            // Clear buffer if successful, or if buffer is getting too large
            if (!insertError || (insertDebugLogs.size() > (C501_MassMerge_SharedCode.GetMaximumCollectionSize() / 2))) {
                insertDebugLogs.clear();
            }
        }
    }

    public static void OutputDebugLogText(LoggingLevel logLevel, String logMessage) {

        // Always emit to native Salesforce log first.
        System.debug(logLevel, logMessage);

        if (Test.isRunningTest()) {
            return;
        }

        LoadLogConfig();

        Boolean ignoreLogMessage = ShouldIgnoreLogMessage(logMessage);

        if (fEnableDebugLogging && logLevel == LoggingLevel.DEBUG && !ignoreLogMessage) {
            insertDebugLogs.add(
                new C501_Debug_Log__c(
                    Log_Level__c = logLevel.name(),
                    Debug_Text_Long__c = String.isBlank(logMessage)
                        ? ''
                        : logMessage.left(MAX_DEBUG_LOG_TEXT_SIZE)
                )
            );
        }

        if (fEnableErrorLogging && logLevel == LoggingLevel.ERROR && !ignoreLogMessage) {
            insertDebugLogs.add(
                new C501_Debug_Log__c(
                    Log_Level__c = logLevel.name(),
                    Debug_Text_Long__c = String.isBlank(logMessage)
                        ? ''
                        : logMessage.left(MAX_DEBUG_LOG_TEXT_SIZE)
                )
            );
        }

        if (insertDebugLogs.size() > 199) {
            OutputDebugLogFlush();
        }
    }
    
    public static String GetSafeSoql(String strSoql) {
        
        // Escape Apostrophe
        if (strSoql.containsIgnoreCase('\'')) {
            strSoql = strSoql.replace('\'', '\\\'');
        }

        return strSoql;
    }

    public static String GetSafeSoqlList(List<String> strList) {

        List<String> strCleanList = new List<String>();
        for (String strToken :strList) {
            if (String.isBlank(strToken)) {
                continue;
            }
            strCleanList.add(String.valueOf(strToken));
        }

        if (strCleanList.isEmpty()) {
            return '(\'\')';
        }

        String safeSoqlList = '(\'' + String.join(strCleanList, '\',\'') + '\')';

        return safeSoqlList;
    }

    public static String GetSafeSoqlList(Set<String> strSet) {

        if (strSet.isEmpty()) {
            return '(\'\')';
        }

        List<String> strList = new List<String>();
        for (String strToken :strSet) {
            strList.add(String.valueOf(strToken));
        }

        return C501_MassMerge_SharedCode.GetSafeSoqlList(strList);
    }

    public static String GetSafeSoqlList(Set<Id> idSet) {

        if (idSet.isEmpty()) {
            return '(\'\')';
        }

        List<String> strList = new List<String>();
        for (Id idToken :idSet) {
            strList.add(String.valueOf(idToken));
        }

        return C501_MassMerge_SharedCode.GetSafeSoqlList(strList);
    }

    /*******************************************************************************************************
    * @description returns whether the field should be treated as an NPSP hidden field, typically one
    * of our deprecated or system fields
    * @return boolean true if should be treated as hidden, false if not.
    */
    public static boolean isNPSPHiddenField(string strField) {
        list<string> listStrField = new list<string>{
            'npe01__SystemAccountProcessor__c',
            'npo02__SystemHouseholdProcessor__c',
            'npe01__SystemIsIndividual__c',
            'Current_Address__c'
        };

        for (string strF : listStrField) {
           if (strField.equalsIgnoreCase(strF))
               return true;
        }
        return false;
    }

    public static String GetAllIterableFields(String sObjectType) {

        Set<String> fieldNames = schema.describeSObjects(new String[] { sObjectType })[0].fields.getMap().keyset();
        List<String> iterableFields = new List<String>(fieldNames);

        return String.join(iterableFields, ',');
    }

    public static String GetC501MergeMetricQuery() {

        if (NearSalesforceLimits()) {
            return '';
        }

        String strSoql = 'SELECT';
        strSoql += ' Id, Name,';
        strSoql += ' Total_Unassigned_Accounts__c, Total_Unassigned_Contacts__c,';
        strSoql += ' Source_Report__c, Source_Report_LastModifiedDate__c, Source_Object__c, Source_Object_Account_Id__c, Source_Object_Contact_Id__c,';
        strSoql += ' AutoMerge_Objects__c,';
        strSoql += ' Last_Discover_Date__c, Last_ContactsAccount_Discover_Date__c, Last_ContactsAccounts_Discover_Date__c, Last_Merge_Date__c,';
        strSoql += ' Last_Account_Discover_GroupByHavingCount__c, Last_Contact_Discover_GroupByHavingCount__c,Last_ContactsAcross_Discover_HavingCount__c,';
        strSoql += ' Discovery_Objects__c';
        strSoql += ' FROM C501_Merge_Metric__c';
        strSoql += ' WHERE isDeleted = false';
        strSoql += ' AND Source_Object__c <> NULL AND Source_Report__c <> NULL AND (Source_Object_Account_Id__c <> NULL OR Source_Object_Contact_Id__c <> NULL)';

        if (Test.isRunningTest()) {        
            strSoql += ' AND Name LIKE \'TESTDATA%\'';
        }

        return strSoql;
    }

    public static String GetC501AccountMergeQuery() {

        if (NearSalesforceLimits()) {
            return '';
        }

        String strSoql = 'SELECT';
        strSoql += ' Id, Unique_Id__c,';
        strSoql += ' Account__c, Account__r.IsDeleted,';
        strSoql += ' Merge_Target_Account__c, Merge_Target_Account__r.IsDeleted,';
        strSoql += ' Merge_Action__c,';
        strSoql += ' Merge_Metric__c, Merge_Metric__r.Name';
        strSoql += ' FROM C501_Account_Merge__c';
        strSoql += ' WHERE isDeleted = false';
        strSoql += ' AND Merge_Action__c <> \'Ignore\'';

        if (Test.isRunningTest()) {        
            strSoql += ' AND Merge_Metric__r.Name LIKE \'TESTDATA%\'';
        }

        return strSoql;
    }

    public static String GetMergeQueries() {

        if (NearSalesforceLimits()) {
            return '';
        }

        String strSoql = 'SELECT';
        strSoql += ' Id, Unique_Id__c,';
        strSoql += ' SOQL_Query__c, Object_Type__c,';
        strSoql += ' Merge_Metric__c, Merge_Criteria_Values__c, Source_Object_Id__c';
        strSoql += ' FROM Merge_Query__c';
        strSoql += ' WHERE isDeleted = false AND';
        strSoql += '  isTest__c = ' + (Test.isRunningTest() ? 'true' : 'false');

        return strSoql;
    }

    public static String GetC501ContactMergeQuery() {

        if (NearSalesforceLimits()) {
            return '';
        }

        String strSoql = 'SELECT';
        strSoql += ' Id, Unique_Id__c,';
        strSoql += ' Contact__c, Contact__r.AccountId, Contact__r.Name, Contact__r.IsDeleted,';
        strSoql += ' Merge_Target_Contact__c, Merge_Target_Contact__r.AccountId, Merge_Target_Contact__r.Name, Merge_Target_Contact__r.IsDeleted,';
        strSoql += ' Merge_Action__c,';
        strSoql += ' Merge_Metric__c, Merge_Metric__r.Name';
        strSoql += ' FROM C501_Contact_Merge__c';
        strSoql += ' WHERE isDeleted = false';
        strSoql += ' AND Merge_Action__c <> \'Ignore\'';

        if (Test.isRunningTest()) {        
            strSoql += ' AND Merge_Metric__r.Name LIKE \'TESTDATA%\'';
        }

        return strSoql;
    }

    public static void InitializeMassMergeInstances() {

        C501_MassMerge_SharedCode.ScheduleJobs();

        String reportFolder = 'Mass Merge Rules';
        if (Test.isRunningTest()) {
            reportFolder = 'Mass Merge Tests';
        }
        
        String strSoql = C501_MassMerge_SharedCode.GetC501MergeMetricQuery();
        if (String.isBlank(strSoql)) {
            return;
        }

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '*****C501_MassMerge_SharedCode::GetC501MergeMetricQuery strSoql: ' + strSoql);

        List<C501_Merge_Metric__c> mergeMetrics = Database.Query(strSoql);

        // Initialize Merge Metrics - make sure there is a merge metric for each report in Mass Merge folder
        List<C501_Merge_Metric__c> mergeMetricsInsert = new List<C501_Merge_Metric__c>();
        for (Report report :[
            SELECT Id, DeveloperName, FolderName, Name
            FROM Report
            WHERE FolderName = :reportFolder]) {

                Boolean foundMergeMetric = false;
                for (C501_Merge_Metric__c mergeMetric :mergeMetrics) {

                    if (mergeMetric.Source_Report__c == (String)report.Id || mergeMetric.Source_Report__c == report.DeveloperName) {

                        foundMergeMetric = true;
                        break;
                    }
                }

                if (!foundMergeMetric) {

                    mergeMetricsInsert.add( new C501_Merge_Metric__c (
                        Name = (Test.isRunningTest() ? ('TESTDATA ' + report.Name) : report.Name),
                        Source_Report__c = report.Id,
                        Source_Object__c = (report.DeveloperName.contains('Account') ? 'Account' : 'Contact'),
                        Source_Object_Account_Id__c = (report.DeveloperName.contains('Account') ? 'Id' : 'AccountId'),
                        Source_Object_Contact_Id__c = (report.DeveloperName.contains('Contact') ? 'Id' : 'Id'),
                        Unique_Id__c = report.Id
                    ));
                }
        }

        if (!mergeMetricsInsert.isEmpty()) {

            // Upsert by external id field: Unique_Id__c
            Database.UpsertResult[] upsertResults =
                Database.upsert(mergeMetricsInsert, C501_Merge_Metric__c.Unique_Id__c, false);
        
            for (Database.UpsertResult result : upsertResults) {
                if (!result.isSuccess()) {
                    for (Database.Error resultError : result.getErrors()) {
                        C501_MassMerge_SharedCode.LogDatabaseError(
                            resultError,
                            'C501_MassMerge_SharedCode::InitializeMassMergeInstances'
                        );
                    }
                }
            }
        }
    }

    public static void DeleteMergeMetricChildren(Set<Id> mergeMetricIds) {

        // Delete Account Merge Candidates
        //
        String strSoqlDeleteAccountMerges = C501_MassMerge_SharedCode.GetC501AccountMergeQuery();
        if (String.isBlank(strSoqlDeleteAccountMerges)) {
            return;
        }
        strSoqlDeleteAccountMerges += ' AND Merge_Metric__c in ' + C501_MassMerge_SharedCode.GetSafeSoqlList(mergeMetricIds);

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::DeleteMergeMetricChildren strSoqlDeleteAccountMerges: ' + strSoqlDeleteAccountMerges);
        List<C501_Account_Merge__c> deleteAccountMerges = Database.query(strSoqlDeleteAccountMerges);
        if (!deleteAccountMerges.isEmpty()) {
            Database.delete(deleteAccountMerges, false);
        }

        // Delete Contact Merge Candidates
        //
        String strSoqlDeleteContactMerges = C501_MassMerge_SharedCode.GetC501ContactMergeQuery();
        if (String.isBlank(strSoqlDeleteContactMerges)) {
            return;
        }
        strSoqlDeleteContactMerges += ' AND Merge_Metric__c in ' + C501_MassMerge_SharedCode.GetSafeSoqlList(mergeMetricIds);

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::DeleteMergeMetricChildren strSoqlDeleteContactMerges: ' + strSoqlDeleteContactMerges);

        List<C501_Contact_Merge__c> deleteContactMerges = Database.query(strSoqlDeleteContactMerges);
        if (!deleteContactMerges.isEmpty()) {
            Database.delete(deleteContactMerges, false);
        }

        // Delete Merge Query Candidates
        //
        String strSoqlDeleteMergeQueries = C501_MassMerge_SharedCode.GetMergeQueries();
        if (String.isBlank(strSoqlDeleteMergeQueries)) {
            return;
        }
        strSoqlDeleteMergeQueries += ' AND Merge_Metric__c in ' + C501_MassMerge_SharedCode.GetSafeSoqlList(mergeMetricIds);

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::DeleteMergeMetricChildren strSoqlDeleteMergeQueries: ' + strSoqlDeleteMergeQueries);

        List<Merge_Query__c> deleteMergeQueries = Database.query(strSoqlDeleteMergeQueries);
        if (!deleteMergeQueries.isEmpty()) {
            Database.delete(deleteMergeQueries, false);
        }
    }
   
    /*
        @Param:List of selectOption to be sort.
        @Return: Sorted list of selectOptions by Label
    */

    public static List<selectOption> SelectOptionSortByLabel(List<selectOption> selectOptionsToSort) {

        if (selectOptionsToSort == null || selectOptionsToSort.size() <= 1) {
            return selectOptionsToSort;
        }

        List<SelectOption> lessSelectOption = new List<SelectOption>();
        List<SelectOption> greaterSelectOption = new List<SelectOption>();
        Integer pivot = selectOptionsToSort.size() / 2;
        
        //save the pivot and remove it FROM the selectOption list
        SelectOption pivotValue = selectOptionsToSort[pivot];
        selectOptionsToSort.remove(pivot);
        for(selectOption SO : selectOptionsToSort){
            if(SO.getLabel() <= pivotValue.getLabel()){
                lessSelectOption.add(SO);
            }else if(SO.getLabel() > pivotValue.getLabel()){
                greaterSelectOption.add(SO);   
            }
        }

        List<selectOption> sortedSelectOptions = new List<selectOption>(); 
        sortedSelectOptions.addAll(SelectOptionSortByLabel(lessSelectOption));
        sortedSelectOptions.add(pivotValue);
        sortedSelectOptions.addAll(SelectOptionSortByLabel(greaterSelectOption));

        return SortedSelectOptions;
    }

    public static Integer GetCountMergeQueries(String objectType) {

        Integer numberMergeQueries = 0;

        String strSoql = 'SELECT Count(Id) NumberOfQueries FROM Merge_Query__c';

        if (!String.isBlank(objectType)) {
            strSoql += ' WHERE Object_Type__c = \'' + objectType + '\'';
        }

        for (AggregateResult result : Database.query(strSoql)) {

            numberMergeQueries = Integer.valueOf(result.get('NumberOfQueries'));
            break;
        }

        return numberMergeQueries;
    }       

    public static Integer GetCountMergeCandidates() {

        return C501_MassMerge_SharedCode.GetCountAccountMergeCandidates() + C501_MassMerge_SharedCode.GetCountContactMergeCandidates();
    }       

    public static Integer GetCountAccountMergeCandidates() {


        Integer numberMergeCandidates = 0;
        String strSoql = 'SELECT Count(Id) NumberOfCandidates FROM C501_Account_Merge__c WHERE Merge_Action__c = \'Master\' OR (Merge_Action__c <> \'Ignore\' AND Merge_Metric__r.AutoMerge_Objects__c includes (\'Account\'))';

        for (AggregateResult result : Database.query(strSoql)) {

            numberMergeCandidates += Integer.valueOf(result.get('NumberOfCandidates'));
            break;
        }

        return numberMergeCandidates;
    }       

    public static Integer GetCountContactMergeCandidates() {

        Integer numberMergeCandidates = 0;
        String strSoql = 'SELECT Count(Id) NumberOfCandidates FROM C501_Contact_Merge__c WHERE Merge_Action__c = \'Master\' OR (Merge_Action__c <> \'Ignore\' AND (Merge_Metric__r.AutoMerge_Objects__c includes (\'Contacts_Within_Account\') OR Merge_Metric__r.AutoMerge_Objects__c includes (\'Contacts_Across_Accounts\')))';

        for (AggregateResult result : Database.query(strSoql)) {

            numberMergeCandidates += Integer.valueOf(result.get('NumberOfCandidates'));
            break;
        }

        return numberMergeCandidates;
    }       
    
    public static void ProcessMergeCandidates(C501_Merge_Metric__c mergeMetric, List<C501_Account_Merge__c> mergeAccounts) {

        C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
        c501MassMerge_SharedCode_Account.InsertObjectMergeCandidates(mergeAccounts);

        c501MassMerge_SharedCode_Account.ProcessObjectMergeCandidates(mergeMetric);
    }

    public static Integer ProcessObjectMergeCandidates_Account(C501_Merge_Metric__c mergeMetric, List<C501_Account_Merge__c> pendingAutoMerges, Map<Id, Id> contactHouseholdMap) {

        List<String> automergeObjects = C501_MassMerge_SharedCode.MultiSelectPickListToList(mergeMetric.AutoMerge_Objects__c);
        if (automergeObjects.contains(C501_MassMerge_SharedCode.MergeObjectScenarios.Account.name())) {

            if (!pendingAutoMerges.isEmpty()) {
                C501_MassMerge_SharedCode_Account c501MassMerge_SharedCode_Account = new C501_MassMerge_SharedCode_Account();
                return c501MassMerge_SharedCode_Account.ProcessObjectMerges(new List<C501_Merge_Metric__c> {mergeMetric}, pendingAutoMerges);
            }
        }

        return 0;
    }

    public static Integer ProcessObjectMergeCandidates_Contact(C501_Merge_Metric__c mergeMetric, List<C501_Contact_Merge__c> pendingAutoMerges, Map<Id, Id> contactHouseholdMap) {

        List<String> automergeObjects = C501_MassMerge_SharedCode.MultiSelectPickListToList(mergeMetric.AutoMerge_Objects__c);
        if (automergeObjects.contains(C501_MassMerge_SharedCode.MergeObjectScenarios.Contacts_Within_Account.name()) || automergeObjects.contains(C501_MassMerge_SharedCode.MergeObjectScenarios.Contacts_Across_Accounts.name())) {

            List<C501_Contact_Merge__c> pendingAutoMergeCandidates = new List<C501_Contact_Merge__c>();
            for (C501_Contact_Merge__c pendingAutoMerge :pendingAutoMerges) {

                if (!contactHouseholdMap.containsKey(pendingAutoMerge.Contact__c) || !contactHouseholdMap.containsKey(pendingAutoMerge.Merge_Target_Contact__c)) {
                    continue;
                }

                // Check for valid household - for instance might not be NPSP households so Account could be null for a contact
                if (contactHouseholdMap.get(pendingAutoMerge.Contact__c) == null || contactHouseholdMap.get(pendingAutoMerge.Merge_Target_Contact__c) == null) {
                    continue;
                }

                if (automergeObjects.contains(C501_MassMerge_SharedCode.MergeObjectScenarios.Contacts_Within_Account.name()) && contactHouseholdMap.get(pendingAutoMerge.Contact__c) == contactHouseholdMap.get(pendingAutoMerge.Merge_Target_Contact__c)) {
                    pendingAutoMergeCandidates.add(pendingAutoMerge);
                }
                
                if (automergeObjects.contains(C501_MassMerge_SharedCode.MergeObjectScenarios.Contacts_Across_Accounts.name()) && contactHouseholdMap.get(pendingAutoMerge.Contact__c) != contactHouseholdMap.get(pendingAutoMerge.Merge_Target_Contact__c)) {
                    pendingAutoMergeCandidates.add(pendingAutoMerge);
                }
            }

            if (!pendingAutoMergeCandidates.isEmpty()) {
                C501_MassMerge_SharedCode_Contact c501MassMerge_SharedCode_Contact = new C501_MassMerge_SharedCode_Contact();
                return c501MassMerge_SharedCode_Contact.ProcessObjectMerges(new List<C501_Merge_Metric__c> {mergeMetric}, pendingAutoMergeCandidates);
            }
        }

        return 0;
    }

    public static void ScheduleJobs() {

        if (Test.isRunningTest()) {
            return;
        }

        List<CronJobDetail> cronJobDetails = [SELECT Id, JobType, Name FROM CronJobDetail WHERE Name like '%C501_MM_%'];
        Set<String> scheduledJobs = new Set<String>();
        String jobVersion = '_v5';
        for (CronJobDetail jobDetail :cronJobDetails) {

            System.debug(LoggingLevel.DEBUG, 'C501_MassMerge_SharedCode:ScheduleJobs - jobDetail: ' + jobDetail);

            if (!jobDetail.Name.contains(jobVersion)) {

                System.debug(LoggingLevel.DEBUG, 'C501_MassMerge_SharedCode:ScheduleJobs - abortJob');

                Id jobId = [SELECT Id FROM CronTrigger WHERE CronJobDetailId = :jobDetail.Id].Id;
                System.abortJob(jobId);
            }
            else {
                scheduledJobs.add(jobDetail.Name);
            }
        }

        // Create core scheduled job - the rest of the jobs are batch chained off this core job
        String scheduleJobName = 'C501_MM_Scheduled_Automation' + jobVersion;

        System.debug(LoggingLevel.DEBUG, 'C501_MassMerge_SharedCode:ScheduleJobs - scheduledJobs: ' + scheduledJobs);

        if (!scheduledJobs.contains(scheduleJobName)) {

            // Cron expression for top of every hour
            String cronExpression = '0 0 * * * ?';

            System.schedule(scheduleJobName, cronExpression, new C501_MM_Rule_Discover_Accounts());
        }

        // Cron expression for every 5 minutes from top of the hour
        String cronExpressionPre = '0 ';
        String cronExpressionPost = ' * * * ?';

        for (Integer minuteValue = 0; minuteValue < 60; minuteValue += 10) {

            scheduleJobName = 'C501_MM_Scheduled_Merging' + jobVersion + '-' + String.valueOf(minuteValue);

            if (!scheduledJobs.contains(scheduleJobName)) {
                System.schedule(scheduleJobName, cronExpressionPre + String.valueOf(minuteValue) + cronExpressionPost, new C501_MM_Rule_Merge());
            }
        }
    }

    public static void TestSetupMerge() {

        C501_MassMerge_SharedCode.InitializeMassMergeInstances();

        List<Account> listAccounts = new List<Account>();   
        Integer cAccounts = 2;
        for (Integer i = 0; i < cAccounts; i++) {

            Account account = new Account(
                
                Name='TESTDATA Flintstone Household',
                BillingStreet = 'BillingStreet',
                BillingCity = 'BillingCity',
                BillingState = 'WA',
                BillingPostalCode =  '12345',
                ShippingStreet = 'BillingStreet',
                ShippingCity = 'BillingCity',
                ShippingState = 'WA',
                ShippingPostalCode =  '12345',
                Website = 'https://www.flintstone.org'
            );

            listAccounts.add(account);
        }                      

        insert listAccounts;

        Map<Id, Opportunity> listOpportunityHouseholds = new Map<Id, Opportunity>();
        List<Contact> listContacts = new List<Contact>();
        for (Integer i = 0; i < cAccounts; i++) {

            listOpportunityHouseholds.put(listAccounts[i].Id, new Opportunity(
                Name = 'TESTDATA Name ' + listAccounts[i].Id,
                StageName = 'Closed Won',
                CloseDate = System.today()
            ));

            listContacts.add( new Contact(
                LastName = 'TESTDATA Flintstone',
                FirstName = 'Fred',
                AccountId = listAccounts[i].Id,
                Birthdate = date.today().addYears(-21),
                Email = 'fred@bedrock.org'
            ));

            listContacts.add( new Contact(
                LastName = 'TESTDATA Flintstone',
                FirstName = 'Fred',
                AccountId = listAccounts[i].Id,
                Birthdate = date.today().addYears(-21),
                Email = 'fred@bedrock.org'
            ));

            listContacts.add( new Contact(
                LastName = 'TESTDATA Flintstone',
                FirstName = 'Wilma',
                AccountId = listAccounts[i].Id,
                Birthdate = date.today().addYears(-21),
                Email = 'wilma@bedrock.org'
            ));
        }

        if (!listOpportunityHouseholds.isEmpty() && !listOpportunityHouseholds.values().isEmpty()) {
            insert listOpportunityHouseholds.values();
        }

        if (!listContacts.isEmpty()) {
            insert listContacts;
        }

        //C501_MassMerge_SharedCode.PrintSalesforceStructure();
    }

    public static List<C501_Merge_Metric__c> TestDiscoverHelper(String queryNameCriteria) {

        C501_MassMerge_CodeCoverage.CodeCoverageHack();

        C501_MassMerge_SharedCode.TestSetupMerge();

        // Reset report change detected during a merge process call
        C501_MM_Rule_Merge.get().execute(null);

        String strSoql = C501_MassMerge_SharedCode.GetC501MergeMetricQuery();
        if (String.isBlank(strSoql)) {
            return new List<C501_Merge_Metric__c>();
        }
        strSoql += ' AND Name LIKE \'%' + queryNameCriteria + '%\'';

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '*****C501_MassMerge_SharedCode::TestDiscoverHelper strSoql: ' + strSoql);

        Boolean accountTesting = queryNameCriteria.containsIgnoreCase('Account');

        List<C501_Merge_Metric__c> mergeMetrics = Database.Query(strSoql);
        System.Assert(mergeMetrics.size() > 0);
        for (C501_Merge_Metric__c mergeMetric :mergeMetrics) {

            if (accountTesting) {
                mergeMetric.Discovery_Objects__c = 'Account';
                mergeMetric.AutoMerge_Objects__c = 'Account';
            } else {
                mergeMetric.Discovery_Objects__c = 'Contacts_Within_Account;Contacts_Across_Accounts';
                mergeMetric.AutoMerge_Objects__c = 'Contacts_Within_Account;Contacts_Across_Accounts';
            }

            // Set groupby to 4 because TestSetupMerge creates 4 accounts and 4 contacts per account
            mergeMetric.Last_Account_Discover_GroupByHavingCount__c = 0.0;
            mergeMetric.Last_Contact_Discover_GroupByHavingCount__c = 0.0;
            mergeMetric.Last_ContactsAcross_Discover_HavingCount__c = 0.0;
        }

        Database.SaveResult[] updateResults = Database.update(mergeMetrics, false);
        for (Database.SaveResult updateResult :updateResults) {
            if (!updateResult.isSuccess()) {
                for(Database.Error resultError : updateResult.getErrors()) {
                    C501_MassMerge_SharedCode.LogDatabaseError(resultError, 'C501_MassMerge_SharedCode::TestDiscoverHelper');
                }                        
            }
        }

        for (C501_Merge_Metric__c mergeMetric :mergeMetrics) {

            if (accountTesting) {
                C501_MM_Rule_Discover_Accounts.get().executeMetricById(mergeMetric.Id);
            } else {
                C501_MM_Rule_Discover_ContactsAccount.get().executeMetricById(mergeMetric.Id);
                C501_MM_Rule_Discover_ContactsAccounts.get().executeMetricById(mergeMetric.Id);
            }
        }

        //C501_MassMerge_SharedCode.PrintSalesforceStructure();

        // Expand Merge Queries
        C501_MM_Process_Merge_Queries.get().execute(null);

        //C501_MassMerge_SharedCode.PrintSalesforceStructure();

        return mergeMetrics;
    }

    public static String TestHelperAutoMergeObjects(String sourceObject, String autoMergeType) {

        if (sourceObject.equals('Account')) {
            if (autoMergeType.equals('Object')) {
                return C501_MassMerge_SharedCode.MergeObjectScenarios.Account.name();
            }
        }
        else if (sourceObject.equals('Contact')) {
            if (autoMergeType.equals('ObjectsWithinObject')) {
                return C501_MassMerge_SharedCode.MergeObjectScenarios.Contacts_Within_Account.name();
            }
            else if (autoMergeType.equals('ObjectsAcrossObjects')) {
                return C501_MassMerge_SharedCode.MergeObjectScenarios.Contacts_Across_Accounts.name();
            }
        }

        return null;
    }

    public static void PrintSalesforceLimits() {

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceLimits - Aggregate Queries ' + Limits.getAggregateQueries() + ' of ' + Limits.getLimitAggregateQueries());
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceLimits - DML Rows ' + Limits.getDMLRows() + ' of ' + Limits.getLimitDMLRows());
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceLimits - DML Statments ' + Limits.getDMLStatements() + ' of ' + Limits.getLimitDMLStatements());
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceLimits - Queries ' + Limits.getQueries() + ' of ' + Limits.getLimitQueries());
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceLimits - Query Rows ' + Limits.getQueryRows() + ' of ' + Limits.getLimitQueryRows());
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceLimits - Sosl Queries ' + Limits.getSoslQueries() + ' of ' + Limits.getLimitSoslQueries());
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceLimits - Queuable Jobs ' + Limits.getQueueableJobs() + ' of ' + Limits.getLimitQueueableJobs());
    }

    public static Integer GetMaximumDMLLimitSize() {

        Integer percentageMultiple = 98;
        Integer maximumLimitSize = ((Limits.getLimitQueryRows() - Limits.getQueryRows()) / 100) * percentageMultiple;
        Integer maximumDMLLimitSize = ((Limits.getLimitDMLRows() - Limits.getDMLRows()) / 100) * percentageMultiple;


        return maximumDMLLimitSize < maximumLimitSize ? maximumDMLLimitSize : maximumLimitSize;
    }

    public static Integer GetMaximumLimitSize(Integer groupByHavingCountMax) {

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::GetMaximumLimitSize - groupByHavingCountMax: ' + groupByHavingCountMax);

        Integer percentageMultiple = 98;
        Integer maximumLimitSize = ((Limits.getLimitQueryRows() - Limits.getQueryRows()) / 100) * percentageMultiple;
        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::GetMaximumLimitSize - Limits.getLimitQueryRows(): ' + Limits.getLimitQueryRows() + ' Limits.getQueryRows(): ' + Limits.getQueryRows());

        // Check for groupByHavingCountMax because each aggregate row is a count of all the rows to create the aggregate
        //  https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_SOQL_agg_fns.htm
        if (groupByHavingCountMax > 1) {
            return maximumLimitSize / groupByHavingCountMax;
        }

        return maximumLimitSize;
    }

    public static Integer GetMaximumCollectionSize() {

        // Salesforce max collection size is 1000
        return C501_MassMerge_SharedCode.GetMaximumLimitSize(1) < 999 ? C501_MassMerge_SharedCode.GetMaximumLimitSize(1) : 999;
    }

    public static Boolean NearSalesforceLimits() {

        Boolean nearLimit = false;
        Integer percentageMultiple = C501_MassMerge_SharedCode.MaximumSalesforceLimitsToUse;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_methods_system_limits.htm

        if (Limits.getAggregateQueries() > ((Limits.getLimitAggregateQueries() / 100) * percentageMultiple)) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** C501_MassMerge_SharedCode::NearSalesforceLimits - Aggregate Queries ' + String.valueOf(percentageMultiple) + '% of Limit - ' + Limits.getAggregateQueries() + ' of ' + Limits.getLimitAggregateQueries());
            nearLimit = true;
        }

        if (Limits.getDMLRows() > ((Limits.getLimitDMLRows() / 100) * percentageMultiple)) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** C501_MassMerge_SharedCode::NearSalesforceLimits - DML Rows ' + String.valueOf(percentageMultiple) + '% of Limit - ' + Limits.getDMLRows() + ' of ' + Limits.getLimitDMLRows());
            nearLimit = true;
        }

        if (Limits.getDMLStatements() > ((Limits.getLimitDMLStatements() / 100) * percentageMultiple)) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** C501_MassMerge_SharedCode::NearSalesforceLimits - DML Statments ' + String.valueOf(percentageMultiple) + '% of Limit - ' + Limits.getDMLStatements() + ' of ' + Limits.getLimitDMLStatements());
            nearLimit = true;
        }

        if (Limits.getQueries() > ((Limits.getLimitQueries() / 100) * percentageMultiple)) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** C501_MassMerge_SharedCode::NearSalesforceLimits - Queies ' + String.valueOf(percentageMultiple) + '% of Limit - ' + Limits.getQueries() + ' of ' + Limits.getLimitQueries());
            nearLimit = true;
        }

        if (Limits.getQueryRows() > ((Limits.getLimitQueryRows() / 100) * percentageMultiple)) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** C501_MassMerge_SharedCode::NearSalesforceLimits - Query Rows ' + String.valueOf(percentageMultiple) + '% of Limit - ' + Limits.getQueryRows() + ' of ' + Limits.getLimitQueryRows());
            nearLimit = true;
        }

        if (Limits.getSoslQueries() > ((Limits.getLimitSoslQueries() / 100) * percentageMultiple)) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** C501_MassMerge_SharedCode::NearSalesforceLimits - Sosl Queries ' + String.valueOf(percentageMultiple) + '% of Limit - ' + Limits.getSoslQueries() + ' of ' + Limits.getLimitSoslQueries());
            nearLimit = true;
        }

        if (Limits.getCpuTime() > ((Limits.getLimitCpuTime() / 100) * percentageMultiple)) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, '***** C501_MassMerge_SharedCode::NearSalesforceLimits - Cpu Time ' + String.valueOf(percentageMultiple) + '% of Limit - ' + Limits.getCpuTime() + ' of ' + Limits.getLimitCpuTime());
            nearLimit = true;
        }

        //C501_MassMerge_SharedCode.PrintSalesforceLimits();

        return nearLimit;
    }


    public static void PrintSalesforceStructure() {

        C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure');

        C501_MassMerge_SharedCode.PrintSalesforceLimits();
/*
        for (Account account :[SELECT Id, Name, Website, BillingStreet FROM Account WHERE Name LIKE 'TESTDATA%']) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Account ' + String.valueOf(account));
        }
        for (Contact contact :[SELECT Id, Account.Name, LastName, FirstName, Birthdate, Email FROM Contact WHERE LastName LIKE 'TESTDATA%']) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Contact ' + String.valueOf(contact));
        }
        for (Opportunity opportunity :[SELECT Id, Name FROM Opportunity WHERE Name LIKE 'TESTDATA%']) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Opportunity ' + String.valueOf(opportunity));
        }
*/        for (Merge_Query__c mergeQuery :Database.query(C501_MassMerge_SharedCode.GetMergeQueries())) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Merge Query: ' + String.valueOf(mergeQuery));
        }
/*    
        for (C501_Merge_Metric__c mergeMetric :Database.query(C501_MassMerge_SharedCode.GetC501MergeMetricQuery())) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Merge Metrics: ' + String.valueOf(mergeMetric));
        }
*/        
        for (C501_Account_Merge__c mergeAccount :Database.query(C501_MassMerge_SharedCode.GetC501AccountMergeQuery() + ' ORDER BY Merge_Metric__c DESC')) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Merge Accounts: ' + String.valueOf(mergeAccount));
        }
        
        for (C501_Contact_Merge__c mergeContact :Database.query(C501_MassMerge_SharedCode.GetC501ContactMergeQuery() + ' ORDER BY Merge_Metric__c DESC')) {
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Merge Contacts: ' + String.valueOf(mergeContact));
            C501_MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, '***** C501_MassMerge_SharedCode::PrintSalesforceStructure - Merge Contacts - Contact__r.Name: ' + mergeContact.Contact__r.Name + ' Merge_Target_Contact__r.Name: ' + mergeContact.Merge_Target_Contact__r.Name);
        }
    }    
}