@IsTest
private class MM_Flow_SingleAccountMerge_TEST {

    @IsTest
    static void testCandidateFound() {
        Account source = new Account(Name = 'Source');
        Account target = new Account(Name = 'Target');
        insert new List<Account>{ source, target };

        insert new List<Contact>{
            new Contact(
                AccountId = source.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = Date.newInstance(1980, 1, 1)
            ),
            new Contact(
                AccountId = source.Id,
                FirstName = 'Mary',
                LastName = 'Jones',
                Birthdate = Date.newInstance(1990, 5, 15)
            ),
            new Contact(
                AccountId = target.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = Date.newInstance(1980, 1, 1)
            ),
            new Contact(
                AccountId = target.Id,
                FirstName = 'Mary',
                LastName = 'Jones',
                Birthdate = Date.newInstance(1990, 5, 15)
            )
        };

        Test.startTest();
        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.candidateFound);
        System.assertEquals(target.Id, result.targetAccountId);
        System.assertEquals(target.Id, result.masterAccountId);
        System.assertEquals(source.Id, result.duplicateAccountId);
        System.assertEquals(false, result.merged);
    }

    @IsTest
    static void testNoCandidate() {
        Account source = new Account(Name = 'Source');
        Account target = new Account(Name = 'Target');
        insert new List<Account>{ source, target };

        insert new List<Contact>{
            new Contact(
                AccountId = source.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = Date.newInstance(1980, 1, 1)
            ),
            new Contact(
                AccountId = target.Id,
                FirstName = 'Different',
                LastName = 'Person',
                Birthdate = Date.newInstance(2000, 1, 1)
            )
        };

        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false
            );

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.candidateFound);
        System.assertEquals(null, result.targetAccountId);
        System.assertEquals(null, result.masterAccountId);
        System.assertEquals(null, result.duplicateAccountId);
        System.assertEquals(false, result.merged);
    }

    @IsTest
    static void testSourceAccountHasNoContacts() {
        Account source = new Account(Name = 'Source No Contacts');
        insert source;

        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false
            );

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals('Source account has no contacts.', result.message);
    }

    @IsTest
    static void testNoCandidateWhenSourceContactMissingBirthdate() {
        Account source = new Account(Name = 'Source Missing DOB');
        Account target = new Account(Name = 'Target Missing DOB');
        insert new List<Account>{ source, target };

        insert new List<Contact>{
            new Contact(
                AccountId = source.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = null
            ),
            new Contact(
                AccountId = target.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = Date.newInstance(1980, 1, 1)
            )
        };

        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false
            );

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals('No target account found where all source contacts match on required fields.', result.message);
    }

    @IsTest
    static void testCustomMatchFieldsCsvUsesTwoFields() {
        Account source = new Account(Name = 'Source Custom CSV');
        Account target = new Account(Name = 'Target Custom CSV');
        insert new List<Account>{ source, target };

        insert new List<Contact>{
            new Contact(
                AccountId = source.Id,
                FirstName = 'Chris',
                LastName = 'Pine',
                Birthdate = Date.newInstance(1980, 1, 1)
            ),
            new Contact(
                AccountId = target.Id,
                FirstName = 'Chris',
                LastName = 'Pine',
                Birthdate = Date.newInstance(1980, 1, 1)
            )
        };

        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                'FirstName,LastName,Birthdate'
            );

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(target.Id, result.targetAccountId);
        System.assertEquals(source.Id, result.duplicateAccountId);
    }

    @IsTest
    static void testParseHelpers() {
        List<String> parsed = MM_Flow_SingleAccountMergeService.parseMatchFields(' FirstName , LastName , Birthdate ');
        System.assertEquals(3, parsed.size());
        System.assertEquals('FirstName', parsed[0]);
        System.assertEquals('LastName', parsed[1]);
        System.assertEquals('Birthdate', parsed[2]);

        List<String> parsedBlank = MM_Flow_SingleAccountMergeService.parseMatchFields(null);
        System.assertEquals(0, parsedBlank.size());

        List<String> parsedEmpty = MM_Flow_SingleAccountMergeService.parseMatchFields('');
        System.assertEquals(0, parsedEmpty.size());
    }

    @IsTest
    static void testFindTargetAccountForSourceReturnsNullForEmptyContacts() {
        Account source = new Account(Name = 'Source Empty');
        insert source;

        MM_Flow_SingleAccountMergeService.MatchBundle bundle =
            MM_Flow_SingleAccountMergeService.findTargetAccountForSource(
                source,
                new List<Contact>(),
                new List<String>{ 'FirstName', 'LastName', 'Birthdate' }
            );

        System.assertEquals(null, bundle);
    }

    @IsTest
    static void testFindTargetAccountForSourceReturnsNullWhenSourceKeyMissingField() {
        Account source = new Account(Name = 'Source Null Key');
        insert source;

        Contact sourceCon = new Contact(
            AccountId = source.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = null
        );
        insert sourceCon;

        List<Contact> sourceContacts = [
            SELECT Id, AccountId, FirstName, LastName, Birthdate, CreatedDate
            FROM Contact
            WHERE AccountId = :source.Id
        ];

        MM_Flow_SingleAccountMergeService.MatchBundle bundle =
            MM_Flow_SingleAccountMergeService.findTargetAccountForSource(
                source,
                sourceContacts,
                new List<String>{ 'FirstName', 'LastName', 'Birthdate' }
            );

        System.assertEquals(null, bundle);
    }

    @IsTest
    static void testPerformMergeTrueActuallyMergesAccount() {
        Account source = new Account(
            Name = 'Source Merge True',
            npsp__Number_of_Household_Members__c = 2
        );
        Account target = new Account(
            Name = 'Target Merge True',
            npsp__Number_of_Household_Members__c = 2
        );
        insert new List<Account>{ source, target };

        Contact sourceC1 = new Contact(
            AccountId = source.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        Contact sourceC2 = new Contact(
            AccountId = source.Id,
            FirstName = 'Mary',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1990, 5, 15)
        );
        Contact targetC1 = new Contact(
            AccountId = target.Id,
            FirstName = 'John',
            LastName = 'Smith',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        Contact targetC2 = new Contact(
            AccountId = target.Id,
            FirstName = 'Mary',
            LastName = 'Jones',
            Birthdate = Date.newInstance(1990, 5, 15)
        );
        insert new List<Contact>{ sourceC1, sourceC2, targetC1, targetC2 };

        Test.startTest();
        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                true
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.candidateFound);
        System.assertEquals(true, result.merged);
        System.assertEquals(target.Id, result.masterAccountId);
        System.assertEquals(source.Id, result.duplicateAccountId);
        System.assert(result.message.contains('Merged account'));

        List<Account> sourceStillExists = [
            SELECT Id
            FROM Account
            WHERE Id = :source.Id
        ];
        System.assertEquals(0, sourceStillExists.size());

        Account survivingTarget = [
            SELECT Id
            FROM Account
            WHERE Id = :target.Id
            LIMIT 1
        ];
        System.assertEquals(target.Id, survivingTarget.Id);
    }

    @IsTest
    static void testHouseholdMemberMismatchReturnsNoCandidate() {
        Account source = new Account(
            Name = 'Source HH Mismatch',
            npsp__Number_of_Household_Members__c = 2
        );
        Account target = new Account(
            Name = 'Target HH Mismatch',
            npsp__Number_of_Household_Members__c = 3
        );
        insert new List<Account>{ source, target };

        insert new List<Contact>{
            new Contact(
                AccountId = source.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = Date.newInstance(1980, 1, 1)
            ),
            new Contact(
                AccountId = source.Id,
                FirstName = 'Mary',
                LastName = 'Jones',
                Birthdate = Date.newInstance(1990, 5, 15)
            ),
            new Contact(
                AccountId = target.Id,
                FirstName = 'John',
                LastName = 'Smith',
                Birthdate = Date.newInstance(1980, 1, 1)
            ),
            new Contact(
                AccountId = target.Id,
                FirstName = 'Mary',
                LastName = 'Jones',
                Birthdate = Date.newInstance(1990, 5, 15)
            )
        };

        MM_Flow_SingleAccountMerge.Result result =
            MM_Flow_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false
            );

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals(
            'No target account found where household member counts are equal.',
            result.message
        );
    }

    @IsTest
    static void testMoveMatchedContactsToMaster_NoOpAndUpdatePath() {
        MM_Flow_SingleAccountMergeService.moveMatchedContactsToMaster(null);

        MM_Flow_SingleAccountMergeService.MatchBundle emptyBundle =
            new MM_Flow_SingleAccountMergeService.MatchBundle();
        MM_Flow_SingleAccountMergeService.moveMatchedContactsToMaster(emptyBundle);

        Account source = new Account(Name = 'Move Source');
        Account target = new Account(Name = 'Move Target');
        insert new List<Account>{ source, target };

        Contact sourceCon = new Contact(
            AccountId = source.Id,
            FirstName = 'Move',
            LastName = 'Contact',
            Birthdate = Date.newInstance(1988, 8, 8)
        );
        insert sourceCon;

        MM_Flow_SingleAccountMergeService.MatchBundle bundle =
            new MM_Flow_SingleAccountMergeService.MatchBundle();
        bundle.sourceAccountId = source.Id;
        bundle.targetAccountId = target.Id;

        MM_Flow_SingleAccountMergeService.ContactMatch cm =
            new MM_Flow_SingleAccountMergeService.ContactMatch();
        cm.sourceContact = sourceCon;
        cm.targetContact = null;
        bundle.contactMatches.add(cm);

        Test.startTest();
        MM_Flow_SingleAccountMergeService.moveMatchedContactsToMaster(bundle);
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, AccountId
            FROM Contact
            WHERE Id = :sourceCon.Id
            LIMIT 1
        ];
        System.assertEquals(target.Id, refreshed.AccountId);
    }    
}