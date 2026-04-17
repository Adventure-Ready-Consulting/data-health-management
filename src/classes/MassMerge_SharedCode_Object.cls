public without sharing class MassMerge_SharedCode_Object {

    public static Set<String> AddressTypesAvailable = new Set<String>{
        'Mailing', 'Shipping', 'Other', 'Billing'
    };

    public static Set<String> AddressFieldsAvailable = new Set<String>{
        'City', 'Country', 'GeocodeAccuracy', 'Latitude', 'Longitude', 'PostalCode', 'State', 'Street'
    };

    public static Boolean ObjectsFieldMerge_Account_HandlePhone(
        String fieldName,
        Schema.DescribeFieldResult fieldDescribeResult
    ) {
        Boolean handlePhoneField = false;

        if (fieldName.containsIgnoreCase('Phone') &&
            fieldDescribeResult.getType() == Schema.DisplayType.PHONE) {
            handlePhoneField = true;
        }

        return handlePhoneField;
    }

    public static Boolean ObjectsFieldMerge_Contact_HandlePhone(
        String fieldName,
        Schema.DescribeFieldResult fieldDescribeResult
    ) {
        Boolean handlePhoneField = false;

        if (fieldName.containsIgnoreCase('Phone') &&
            fieldDescribeResult.getType() == Schema.DisplayType.PHONE) {

            if (MassMerge_SharedCode.IsNPSPInstalled && fieldName.equalsIgnoreCase('Phone')) {
                MassMerge_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** MassMerge_SharedCode::ObjectsFieldMerge_Contact_HandlePhone Phone Field Skip since NPSP installed'
                );
            } else {
                handlePhoneField = true;
            }
        }

        return handlePhoneField;
    }

    public static Boolean ObjectsFieldMerge_Account_HandleEmail(
        String fieldName,
        Schema.DescribeFieldResult fieldDescribeResult
    ) {
        Boolean handleEmailField = false;

        if (fieldName.containsIgnoreCase('Email') &&
            fieldDescribeResult.getType() == Schema.DisplayType.EMAIL) {
            handleEmailField = true;
        }

        return handleEmailField;
    }

    public static Boolean ObjectsFieldMerge_Contact_HandleEmail(
        String fieldName,
        Schema.DescribeFieldResult fieldDescribeResult
    ) {
        Boolean handleEmailField = false;

        if (fieldName.containsIgnoreCase('Email') &&
            fieldDescribeResult.getType() == Schema.DisplayType.EMAIL) {

            if (MassMerge_SharedCode.IsNPSPInstalled && fieldName.equalsIgnoreCase('Email')) {
                MassMerge_SharedCode.OutputDebugLogText(
                    LoggingLevel.DEBUG,
                    '***** MassMerge_SharedCode::ObjectsFieldMerge_Contact_HandleEmail Email Field Skip since NPSP installed'
                );
            } else {
                handleEmailField = true;
            }
        }

        return handleEmailField;
    }

    public static void ObjectsMerge_Account(Account masterAccount, List<Account> duplicateAccounts) {
    }

    public static void ObjectsMerge_Contact(Contact masterContact, List<Contact> duplicateContacts) {
    }
}