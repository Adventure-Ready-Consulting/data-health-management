/*
    Copyright (c) 2016, Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
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

@isTest
public class C501_MassMerge_SharedCode_TEST {
    
    //==================== TEST METHOD(s) ======================================

    @isTest(SeeAllData='true')
    public static void Contact_MergePhoneTests() {

      Contact masterContact = new Contact(
        LastName = 'Contact_MergePhone_TESTDATA',
        Phone = '(111) 111-1111');
      insert masterContact;

      Contact duplicateContact = new Contact(
        LastName = 'Contact_MergePhone_TESTDATA',
        Phone = '(222) 222-2222');
      insert duplicateContact;

      C501_MassMerge_SharedCode_Contact mergeRequest = new C501_MassMerge_SharedCode_Contact();
      mergeRequest.ObjectsMerge(masterContact, new List<Contact> { duplicateContact });

      List<Contact> contacts = [SELECT Id, Phone, MobilePhone, HomePhone, OtherPhone FROM Contact WHERE LastName = 'Contact_MergePhone_TESTDATA'];
      System.Assert(contacts.size() == 1);
      System.Assert(contacts[0].Phone == '(111) 111-1111');
      System.Assert(contacts[0].MobilePhone == '(222) 222-2222' || contacts[0].HomePhone == '(222) 222-2222' || contacts[0].OtherPhone == '(222) 222-2222');
    }

    @isTest(SeeAllData='true')
    public static void Contact_MergeEmailTests() {

      Contact masterContact = new Contact(
        LastName = 'Contact_MergeEmail_TESTDATA',
        Email = 'master@master.org');
      insert masterContact;

      Contact duplicateContact = new Contact(
        LastName = 'Contact_MergeEmail_TESTDATA',
        Email = 'duplicate@duplicate.org');
      insert duplicateContact;

      C501_MassMerge_SharedCode_Contact mergeRequest = new C501_MassMerge_SharedCode_Contact();
      mergeRequest.ObjectsMerge(masterContact, new List<Contact> { duplicateContact });

      List<Contact> contacts = [SELECT Id, Email FROM Contact WHERE LastName = 'Contact_MergeEmail_TESTDATA'];
      System.Assert(contacts.size() == 1);
      System.Assert(contacts[0].Email == 'master@master.org');
    }

    @isTest(SeeAllData='true')
    public static void Contact_MergeAddressTests() {

      Contact masterContact = new Contact(
        LastName = 'Contact_MergeAddress_TESTDATA',
        MailingStreet = 'master mailing street');
      insert masterContact;

      Contact duplicateContact = new Contact(
        LastName = 'Contact_MergeAddress_TESTDATA',
        MailingStreet = 'duplicate mailing street',
        OtherStreet = 'duplicate other street');
      insert duplicateContact;

      C501_MassMerge_SharedCode_Contact mergeRequest = new C501_MassMerge_SharedCode_Contact();
      mergeRequest.ObjectsMerge(masterContact, new List<Contact> { duplicateContact });

      List<Contact> contacts = [SELECT Id, MailingStreet, OtherStreet FROM Contact WHERE LastName = 'Contact_MergeAddress_TESTDATA'];
      System.Assert(contacts.size() == 1);
      System.Assert(contacts[0].MailingStreet == 'master mailing street');
      System.Assert(contacts[0].OtherStreet == 'duplicate other street');
    }

    @isTest(SeeAllData='true')
    public static void Account_MergeAddressTests() {
    
        Account masterAccount = new Account(
            Name = 'Account_MergeAddress_TESTDATA',
            BillingStreet = 'master billing street'
        );
        insert masterAccount;
    
        Account duplicateAccount = new Account(
            Name = 'Account_MergeAddress_TESTDATA',
            BillingStreet = 'duplicate billing street',
            ShippingStreet = 'duplicate shipping street'
        );
        insert duplicateAccount;
    
        C501_MassMerge_SharedCode_Account mergeRequest = new C501_MassMerge_SharedCode_Account();
        mergeRequest.ObjectsMerge(masterAccount, new List<Account> { duplicateAccount });
    
        Account survivingAccount = [
            SELECT Id, BillingStreet, ShippingStreet
            FROM Account
            WHERE Id = :masterAccount.Id
            LIMIT 1
        ];
    
        List<Account> duplicateStillExists = [
            SELECT Id
            FROM Account
            WHERE Id = :duplicateAccount.Id
        ];
    
        System.AssertEquals(masterAccount.Id, survivingAccount.Id);
        System.AssertEquals('master billing street', survivingAccount.BillingStreet);
        System.AssertEquals('duplicate shipping street', survivingAccount.ShippingStreet);
        System.AssertEquals(0, duplicateStillExists.size());
    }
}