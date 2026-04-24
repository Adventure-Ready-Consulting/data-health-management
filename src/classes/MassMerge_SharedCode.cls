public without sharing class MassMerge_SharedCode {

    public enum MergeObjectScenarios { Account, Contacts_Within_Account, Contacts_Across_Accounts }

    public static Set<String> AddressFieldsAvailable = new Set<String>{
        'City', 'Country', 'GeocodeAccuracy', 'Latitude', 'Longitude', 'PostalCode', 'State', 'Street'
    };

    private static Boolean fCheckedForMaximumSalesforceLimitsToUse = false;
    public static Integer MaximumSalesforceLimitsToUse {
        get {
            if (!fCheckedForMaximumSalesforceLimitsToUse) {
                Mass_Merge_Config__c massMergeConfigSettings = Mass_Merge_Config__c.getOrgDefaults();
                if (massMergeConfigSettings != null &&
                    massMergeConfigSettings.Maximum_Salesforce_Limits_to_Use__c != null) {

                    MaximumSalesforceLimitsToUse =
                        Integer.valueOf(massMergeConfigSettings.Maximum_Salesforce_Limits_to_Use__c);
                    fCheckedForMaximumSalesforceLimitsToUse = true;
                } else {
                    MaximumSalesforceLimitsToUse = 50;
                    fCheckedForMaximumSalesforceLimitsToUse = true;
                }
            }

            return MaximumSalesforceLimitsToUse;
        }
        set;
    }

    private static Boolean fCheckedForNPSP = false;
    public static Boolean IsNPSPInstalled {
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

        if (MassMerge_SharedCode.isNPSPHiddenField(fieldName)) {
            return false;
        }

        return true;
    }

    public static Boolean isNPSPHiddenField(String strField) {
        List<String> listStrField = new List<String>{
            'npe01__SystemAccountProcessor__c',
            'npo02__SystemHouseholdProcessor__c',
            'npe01__SystemIsIndividual__c',
            'Current_Address__c'
        };

        for (String strF : listStrField) {
            if (strField.equalsIgnoreCase(strF)) {
                return true;
            }
        }
        return false;
    }

    public static Boolean LogDatabaseError(Database.Error resultError, String callingMethod) {

        String statusCode = String.valueOf(resultError.getStatusCode());

        if (MassMerge_SharedCode.IsSandbox &&
            (statusCode.contains('INVALID_CROSS_REFERENCE_KEY') ||
             statusCode.contains('INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY'))) {
            return false;
        }

        if (resultError.getMessage().containsIgnoreCase('DUPLICATE_VALUE') &&
            resultError.getMessage().containsIgnoreCase('Unique_Id__c')) {
            return false;
        }

        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.ERROR,
            '***** ' + callingMethod + ' Database.SaveResult Error'
        );
        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.ERROR,
            statusCode + ': ' + resultError.getMessage()
        );
        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.ERROR,
            'Fields that affected this error: ' + resultError.getFields()
        );

        return true;
    }

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

    public static final Integer DUPLICATE_CHECK_ERROR_MAX_LENGTH = 4096;

    public static String TruncateDuplicateCheckError(String message) {
        if (message == null) {
            return null;
        }

        if (message.length() > DUPLICATE_CHECK_ERROR_MAX_LENGTH) {
            return message.substring(0, DUPLICATE_CHECK_ERROR_MAX_LENGTH);
        }

        return message;
    }

    public static void SetDuplicateCheckError(SObject record, String message) {
        if (record == null) {
            return;
        }

        record.put('Duplicate_Check_Error__c', TruncateDuplicateCheckError(message));
    }

    public static void ClearDuplicateCheckError(SObject record) {
        if (record == null) {
            return;
        }

        record.put('Duplicate_Check_Error__c', null);
    }

    public static void LogAndSetError(SObject record, String message) {
        OutputDebugLogText(LoggingLevel.ERROR, message);
        SetDuplicateCheckError(record, message);
    }
    
    public static void OutputDebugLogText(LoggingLevel logLevel, String logMessage) {

        System.debug(logLevel, logMessage);

        if (Test.isRunningTest()) {
            return;
        }
    }

    public static String GetSafeSoqlList(List<String> strList) {

        List<String> strCleanList = new List<String>();
        for (String strToken : strList) {
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
        for (String strToken : strSet) {
            strList.add(String.valueOf(strToken));
        }

        return MassMerge_SharedCode.GetSafeSoqlList(strList);
    }

    public static String GetSafeSoqlList(Set<Id> idSet) {

        if (idSet.isEmpty()) {
            return '(\'\')';
        }

        List<String> strList = new List<String>();
        for (Id idToken : idSet) {
            strList.add(String.valueOf(idToken));
        }

        return MassMerge_SharedCode.GetSafeSoqlList(strList);
    }

    public static Integer GetMaximumCollectionSize() {
        return MassMerge_SharedCode.GetMaximumLimitSize(1) < 999
            ? MassMerge_SharedCode.GetMaximumLimitSize(1)
            : 999;
    }

    public static Integer GetMaximumDMLLimitSize() {

        Integer percentageMultiple = 98;
        Integer maximumLimitSize =
            ((Limits.getLimitQueryRows() - Limits.getQueryRows()) / 100) * percentageMultiple;
        Integer maximumDMLLimitSize =
            ((Limits.getLimitDMLRows() - Limits.getDMLRows()) / 100) * percentageMultiple;

        return maximumDMLLimitSize < maximumLimitSize
            ? maximumDMLLimitSize
            : maximumLimitSize;
    }

    public static Integer GetMaximumLimitSize(Integer groupByHavingCountMax) {

        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** MassMerge_SharedCode::GetMaximumLimitSize - groupByHavingCountMax: ' +
            groupByHavingCountMax
        );

        Integer percentageMultiple = 98;
        Integer maximumLimitSize =
            ((Limits.getLimitQueryRows() - Limits.getQueryRows()) / 100) * percentageMultiple;

        MassMerge_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** MassMerge_SharedCode::GetMaximumLimitSize - Limits.getLimitQueryRows(): ' +
            Limits.getLimitQueryRows() + ' Limits.getQueryRows(): ' + Limits.getQueryRows()
        );

        if (groupByHavingCountMax > 1) {
            return maximumLimitSize / groupByHavingCountMax;
        }

        return maximumLimitSize;
    }

    public static Boolean NearSalesforceLimits() {

        Boolean nearLimit = false;
        Integer percentageMultiple = MassMerge_SharedCode.MaximumSalesforceLimitsToUse;

        if (Limits.getAggregateQueries() > ((Limits.getLimitAggregateQueries() / 100) * percentageMultiple)) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.ERROR,
                '***** MassMerge_SharedCode::NearSalesforceLimits - Aggregate Queries ' +
                String.valueOf(percentageMultiple) + '% of Limit - ' +
                Limits.getAggregateQueries() + ' of ' + Limits.getLimitAggregateQueries()
            );
            nearLimit = true;
        }

        if (Limits.getDMLRows() > ((Limits.getLimitDMLRows() / 100) * percentageMultiple)) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.ERROR,
                '***** MassMerge_SharedCode::NearSalesforceLimits - DML Rows ' +
                String.valueOf(percentageMultiple) + '% of Limit - ' +
                Limits.getDMLRows() + ' of ' + Limits.getLimitDMLRows()
            );
            nearLimit = true;
        }

        if (Limits.getDMLStatements() > ((Limits.getLimitDMLStatements() / 100) * percentageMultiple)) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.ERROR,
                '***** MassMerge_SharedCode::NearSalesforceLimits - DML Statments ' +
                String.valueOf(percentageMultiple) + '% of Limit - ' +
                Limits.getDMLStatements() + ' of ' + Limits.getLimitDMLStatements()
            );
            nearLimit = true;
        }

        if (Limits.getQueries() > ((Limits.getLimitQueries() / 100) * percentageMultiple)) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.ERROR,
                '***** MassMerge_SharedCode::NearSalesforceLimits - Queies ' +
                String.valueOf(percentageMultiple) + '% of Limit - ' +
                Limits.getQueries() + ' of ' + Limits.getLimitQueries()
            );
            nearLimit = true;
        }

        if (Limits.getQueryRows() > ((Limits.getLimitQueryRows() / 100) * percentageMultiple)) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.ERROR,
                '***** MassMerge_SharedCode::NearSalesforceLimits - Query Rows ' +
                String.valueOf(percentageMultiple) + '% of Limit - ' +
                Limits.getQueryRows() + ' of ' + Limits.getLimitQueryRows()
            );
            nearLimit = true;
        }

        if (Limits.getSoslQueries() > ((Limits.getLimitSoslQueries() / 100) * percentageMultiple)) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.ERROR,
                '***** MassMerge_SharedCode::NearSalesforceLimits - Sosl Queries ' +
                String.valueOf(percentageMultiple) + '% of Limit - ' +
                Limits.getSoslQueries() + ' of ' + Limits.getLimitSoslQueries()
            );
            nearLimit = true;
        }

        if (Limits.getCpuTime() > ((Limits.getLimitCpuTime() / 100) * percentageMultiple)) {
            MassMerge_SharedCode.OutputDebugLogText(
                LoggingLevel.ERROR,
                '***** MassMerge_SharedCode::NearSalesforceLimits - Cpu Time ' +
                String.valueOf(percentageMultiple) + '% of Limit - ' +
                Limits.getCpuTime() + ' of ' + Limits.getLimitCpuTime()
            );
            nearLimit = true;
        }

        return nearLimit;
    }
}