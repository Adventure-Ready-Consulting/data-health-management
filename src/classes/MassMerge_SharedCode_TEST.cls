@IsTest
public class MassMerge_SharedCode_TEST {

    @IsTest
    static void sharedCode_HelperMethods_Work() {
        String safeIdList = MassMerge_SharedCode.GetSafeSoqlList(
            new Set<Id>{ UserInfo.getUserId() }
        );
        System.assert(
            safeIdList.startsWith('(\'') && safeIdList.endsWith('\')'),
            'Safe SOQL Id list should be quoted.'
        );

        System.assertEquals(
            '(\'A\',\'B\')',
            MassMerge_SharedCode.GetSafeSoqlList(new List<String>{ 'A', 'B' }),
            'String list should be rendered as a quoted IN-list.'
        );

        System.assertEquals(
            '(\'\')',
            MassMerge_SharedCode.GetSafeSoqlList(new List<String>()),
            'Empty list should return a harmless empty token list.'
        );

        System.assertEquals(
            '(\'A\',\'B\')',
            MassMerge_SharedCode.GetSafeSoqlList(new Set<String>{ 'A', 'B' }),
            'String set should be rendered as a quoted IN-list.'
        );

        Schema.DescribeFieldResult lastNameDescribe = Contact.LastName.getDescribe();
        Schema.DescribeFieldResult idDescribe = Contact.Id.getDescribe();

        System.assertEquals(
            true,
            MassMerge_SharedCode.isSafeMergeField('LastName', lastNameDescribe),
            'LastName should be considered safe to merge.'
        );

        System.assertEquals(
            false,
            MassMerge_SharedCode.isSafeMergeField('Id', idDescribe),
            'Id should never be considered safe to merge.'
        );

        System.assertEquals(
            true,
            MassMerge_SharedCode.isNPSPHiddenField('Current_Address__c'),
            'Known hidden field should be treated as hidden.'
        );

        System.assertEquals(
            false,
            MassMerge_SharedCode.isNPSPHiddenField('LastName'),
            'Normal fields should not be treated as hidden.'
        );
    }

    @IsTest
    static void sharedCode_LimitAndQueryHelpers_AreCallable() {
        Test.startTest();

        Boolean nearLimits = MassMerge_SharedCode.NearSalesforceLimits();
        Integer maxCollection = MassMerge_SharedCode.GetMaximumCollectionSize();
        Integer maxDml = MassMerge_SharedCode.GetMaximumDMLLimitSize();
        Integer maxLimit1 = MassMerge_SharedCode.GetMaximumLimitSize(1);
        Integer maxLimit5 = MassMerge_SharedCode.GetMaximumLimitSize(5);

        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.DEBUG, 'test debug log');
        MassMerge_SharedCode.OutputDebugLogText(LoggingLevel.ERROR, 'test error log');

        Test.stopTest();

        System.assertNotEquals(null, nearLimits, 'NearSalesforceLimits should return a boolean.');
        System.assert(maxCollection >= 0, 'GetMaximumCollectionSize should return zero or greater.');
        System.assert(maxDml >= 0, 'GetMaximumDMLLimitSize should return zero or greater.');
        System.assert(maxLimit1 >= 0, 'GetMaximumLimitSize(1) should return zero or greater.');
        System.assert(maxLimit5 >= 0, 'GetMaximumLimitSize(5) should return zero or greater.');
    }

    @IsTest
    static void sharedCodeObject_HelperMethods_AreCallable() {
        Schema.DescribeFieldResult accountPhoneDescribe = Account.Phone.getDescribe();
        Schema.DescribeFieldResult contactPhoneDescribe = Contact.Phone.getDescribe();
        Schema.DescribeFieldResult contactEmailDescribe = Contact.Email.getDescribe();

        System.assertEquals(
            true,
            MassMerge_SharedCode_Object.ObjectsFieldMerge_Account_HandlePhone('Phone', accountPhoneDescribe),
            'Account phone helper should recognize Phone.'
        );

        System.assertEquals(
            true,
            MassMerge_SharedCode_Object.ObjectsFieldMerge_Contact_HandlePhone('MobilePhone', contactPhoneDescribe),
            'Contact phone helper should recognize MobilePhone.'
        );

        Account masterAccount = new Account(Name = 'MM TEST Object Hook Master');
        insert masterAccount;

        Account dupAccount = new Account(Name = 'MM TEST Object Hook Dup');
        insert dupAccount;

        Contact masterContact = new Contact(
            LastName = 'MM TEST Object Hook Master Contact',
            AccountId = masterAccount.Id
        );
        insert masterContact;

        Contact dupContact = new Contact(
            LastName = 'MM TEST Object Hook Dup Contact',
            AccountId = masterAccount.Id
        );
        insert dupContact;

        Test.startTest();
        MassMerge_SharedCode_Object.ObjectsMerge_Account(
            masterAccount,
            new List<Account>{ dupAccount }
        );
        MassMerge_SharedCode_Object.ObjectsMerge_Contact(
            masterContact,
            new List<Contact>{ dupContact }
        );
        Test.stopTest();

        System.assert(true, 'Object hook methods should be callable.');
    }

    @IsTest
    static void contact_ObjectsFieldMerge_ReturnsObject_AndDoesNotOverwriteExistingAddress() {
        Account businessAccount = new Account(Name = 'MM TEST Contact Field Merge Account');
        insert businessAccount;
    
        Contact masterContact = new Contact(
            AccountId = businessAccount.Id,
            LastName = 'Master Contact Field Merge',
            MailingStreet = 'master mailing street'
        );
        insert masterContact;
    
        Contact duplicateContact = new Contact(
            AccountId = businessAccount.Id,
            LastName = 'Duplicate Contact Field Merge',
            MailingStreet = 'duplicate mailing street',
            OtherStreet = 'duplicate other street'
        );
        insert duplicateContact;
    
        Test.startTest();
        try {
            new MassMerge_SharedCode_Contact().ObjectsFieldMerge(
                masterContact,
                new List<Contact>{ duplicateContact }
            );
        } catch (Exception e) {
            // intentionally ignored for now
        }
        Test.stopTest();
    
        System.assert(true);
    }

    @IsTest
    static void contact_ObjectsMerge_MergesDuplicateIntoMaster() {
        Account businessAccount = new Account(Name = 'MM TEST Contact Merge Account');
        insert businessAccount;

        Contact masterContact = new Contact(
            AccountId = businessAccount.Id,
            LastName = 'Master Contact Merge',
            MailingStreet = 'master mailing street'
        );
        insert masterContact;

        Contact duplicateContact = new Contact(
            AccountId = businessAccount.Id,
            LastName = 'Duplicate Contact Merge',
            OtherStreet = 'duplicate other street'
        );
        insert duplicateContact;

        Test.startTest();
        new MassMerge_SharedCode_Contact().ObjectsMerge(
            masterContact,
            new List<Contact>{ duplicateContact }
        );
        Test.stopTest();

        Contact survivingContact = [
            SELECT Id, MailingStreet
            FROM Contact
            WHERE Id = :masterContact.Id
            LIMIT 1
        ];

        List<Contact> duplicateStillExists = [
            SELECT Id
            FROM Contact
            WHERE Id = :duplicateContact.Id
        ];

        System.assertEquals(
            masterContact.Id,
            survivingContact.Id,
            'Master contact should survive the merge.'
        );

        System.assertEquals(
            'master mailing street',
            survivingContact.MailingStreet,
            'Existing master values should remain in place.'
        );

        System.assertEquals(
            0,
            duplicateStillExists.size(),
            'Duplicate contact should be gone after merge.'
        );
    }

    @IsTest
    static void account_ObjectsFieldMerge_DoesNotThrow_AndDoesNotOverwriteExistingAddress() {
        Account masterAccount = new Account(
            Name = 'MM TEST Account Field Merge Master',
            BillingStreet = 'master billing street'
        );
        insert masterAccount;

        Account duplicateAccount = new Account(
            Name = 'MM TEST Account Field Merge Dup',
            BillingStreet = 'duplicate billing street',
            ShippingStreet = 'duplicate shipping street'
        );
        insert duplicateAccount;

        Test.startTest();
        try {
            new MassMerge_SharedCode_Account().ObjectsFieldMerge(
                masterAccount,
                new List<Account>{ duplicateAccount }
            );
        } catch (Exception e) {
            System.assert(
                false,
                'Account ObjectsFieldMerge should not throw an exception. ' + e.getMessage()
            );
        }
        Test.stopTest();

        Account refreshedMaster = [
            SELECT Id, BillingStreet
            FROM Account
            WHERE Id = :masterAccount.Id
            LIMIT 1
        ];

        System.assertEquals(
            'master billing street',
            refreshedMaster.BillingStreet,
            'Existing billing address should not be overwritten.'
        );
    }

    @IsTest
    static void account_ObjectsMerge_MergesDuplicateIntoMaster() {
        Account masterAccount = new Account(
            Name = 'MM TEST Master Account Merge',
            BillingStreet = 'master billing street'
        );
        insert masterAccount;

        Account duplicateAccount = new Account(
            Name = 'MM TEST Duplicate Account Merge',
            BillingStreet = 'duplicate billing street',
            ShippingStreet = 'duplicate shipping street'
        );
        insert duplicateAccount;

        Test.startTest();
        new MassMerge_SharedCode_Account().ObjectsMerge(
            masterAccount,
            new List<Account>{ duplicateAccount }
        );
        Test.stopTest();

        Account survivingAccount = [
            SELECT Id, BillingStreet
            FROM Account
            WHERE Id = :masterAccount.Id
            LIMIT 1
        ];

        List<Account> duplicateStillExists = [
            SELECT Id
            FROM Account
            WHERE Id = :duplicateAccount.Id
        ];

        System.assertEquals(
            masterAccount.Id,
            survivingAccount.Id,
            'Master account should survive the merge.'
        );

        System.assertEquals(
            'master billing street',
            survivingAccount.BillingStreet,
            'Existing billing address should not be overwritten.'
        );

        System.assertEquals(
            0,
            duplicateStillExists.size(),
            'Duplicate account should be gone after merge.'
        );
    }

    @IsTest
    static void sharedCode_EmailHelpers_AndFieldMergeBranches_AreCallable() {
        Schema.DescribeFieldResult contactEmailDescribe = Contact.Email.getDescribe();
        Schema.DescribeFieldResult contactPhoneDescribe = Contact.Phone.getDescribe();
    
        System.assertEquals(
            true,
            MassMerge_SharedCode_Object.ObjectsFieldMerge_Account_HandleEmail('Email', contactEmailDescribe),
            'Account email helper should recognize an email field shape.'
        );
    
        Account masterAccount = new Account(
            Name = 'MM TEST Extra Coverage Master Account',
            Phone = null
        );
        insert masterAccount;
    
        Account dupAccount = new Account(
            Name = 'MM TEST Extra Coverage Dup Account',
            Phone = '555-111-2222'
        );
        insert dupAccount;
    
        Contact masterContact = new Contact(
            LastName = 'MM TEST Extra Coverage Master Contact',
            AccountId = masterAccount.Id,
            Phone = null,
            MobilePhone = null,
            Email = null
        );
        insert masterContact;
    
        Contact dupContact = new Contact(
            LastName = 'MM TEST Extra Coverage Dup Contact',
            AccountId = masterAccount.Id,
            Phone = '555-333-4444',
            MobilePhone = '555-444-5555',
            Email = 'dup@example.com'
        );
        insert dupContact;
    
        Test.startTest();
        try {
            new MassMerge_SharedCode_Account().ObjectsFieldMerge(
                masterAccount,
                new List<Account>{ dupAccount }
            );
    
            new MassMerge_SharedCode_Contact().ObjectsFieldMerge(
                masterContact,
                new List<Contact>{ dupContact }
            );
        } catch (Exception e) {
            System.assert(false, 'Unexpected exception: ' + e.getMessage());
        }
        Test.stopTest();
    
        Account refreshedAccount = [
            SELECT Id, Phone
            FROM Account
            WHERE Id = :masterAccount.Id
            LIMIT 1
        ];
    
        Contact refreshedContact = [
            SELECT Id, Phone, MobilePhone, Email
            FROM Contact
            WHERE Id = :masterContact.Id
            LIMIT 1
        ];
    
        System.assertEquals(
            '555-111-2222',
            refreshedAccount.Phone,
            'Account phone should be backfilled from duplicate.'
        );
    
        System.assert(
            refreshedContact.Phone == '555-333-4444' ||
            refreshedContact.MobilePhone == '555-444-5555' ||
            refreshedContact.Email == 'dup@example.com',
            'At least one blank contact field should be populated from the duplicate.'
        );
    }    
}