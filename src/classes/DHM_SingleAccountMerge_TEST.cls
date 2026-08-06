@IsTest
private class DHM_SingleAccountMerge_TEST {

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
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
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

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
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

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
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

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
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

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
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
        List<String> parsed = DHM_SingleAccountMergeService.parseMatchFields(' FirstName , LastName , Birthdate ');
        System.assertEquals(3, parsed.size());
        System.assertEquals('FirstName', parsed[0]);
        System.assertEquals('LastName', parsed[1]);
        System.assertEquals('Birthdate', parsed[2]);

        List<String> parsedBlank = DHM_SingleAccountMergeService.parseMatchFields(null);
        System.assertEquals(3, parsedBlank.size());

        List<String> parsedEmpty = DHM_SingleAccountMergeService.parseMatchFields('');
        System.assertEquals(3, parsedEmpty.size());
    }

    @IsTest
    static void testFindTargetAccountForSourceReturnsNullForEmptyContacts() {
        Account source = new Account(Name = 'Source Empty');
        insert source;

        DHM_SingleAccountMergeService.MatchBundle bundle =
            DHM_SingleAccountMergeService.findTargetAccountForSource(
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

        DHM_SingleAccountMergeService.MatchBundle bundle =
            DHM_SingleAccountMergeService.findTargetAccountForSource(
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
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
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
    static void testDifferentHouseholdSizesStillReturnCandidate() {
        Account source = new Account(Name = 'Source Smaller Household');
        Account target = new Account(Name = 'Target Larger Household');
        insert new List<Account>{ source, target };

        insert new List<Contact>{
            new Contact(AccountId = source.Id, FirstName = 'John', LastName = 'Smith', Birthdate = Date.newInstance(1980, 1, 1)),
            new Contact(AccountId = source.Id, FirstName = 'Mary', LastName = 'Jones', Birthdate = Date.newInstance(1990, 5, 15)),
            new Contact(AccountId = target.Id, FirstName = 'John', LastName = 'Smith', Birthdate = Date.newInstance(1980, 1, 1)),
            new Contact(AccountId = target.Id, FirstName = 'Mary', LastName = 'Jones', Birthdate = Date.newInstance(1990, 5, 15)),
            new Contact(AccountId = target.Id, FirstName = 'Extra', LastName = 'Adult', Birthdate = Date.newInstance(1975, 3, 20))
        };

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(source.Id, false);

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(target.Id, result.targetAccountId);
    }

    @IsTest
    static void testConfigurableEmailMatchField() {
        Account source = new Account(Name = 'Source Email');
        Account target = new Account(Name = 'Target Email');
        insert new List<Account>{ source, target };

        insert new List<Contact>{
            new Contact(AccountId = source.Id, LastName = 'Source', Email = 'person@example.org'),
            new Contact(AccountId = target.Id, LastName = 'Different', Email = 'person@example.org')
        };

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                'Email'
            );

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(target.Id, result.targetAccountId);
    }

    @IsTest
    static void testDuplicateKeysRequireMatchingMultiplicity() {
        Account source = new Account(Name = 'Source Twins');
        Account targetOneMatch = new Account(Name = 'Target One Match');
        Account targetTwoMatches = new Account(Name = 'Target Two Matches');
        insert new List<Account>{ source, targetOneMatch, targetTwoMatches };

        Date dob = Date.newInstance(1985, 6, 1);
        insert new List<Contact>{
            new Contact(AccountId = source.Id, FirstName = 'Alex', LastName = 'Same', Birthdate = dob),
            new Contact(AccountId = source.Id, FirstName = 'Alex', LastName = 'Same', Birthdate = dob),
            new Contact(AccountId = targetOneMatch.Id, FirstName = 'Alex', LastName = 'Same', Birthdate = dob),
            new Contact(AccountId = targetTwoMatches.Id, FirstName = 'Alex', LastName = 'Same', Birthdate = dob),
            new Contact(AccountId = targetTwoMatches.Id, FirstName = 'Alex', LastName = 'Same', Birthdate = dob)
        };

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(source.Id, false);

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(targetTwoMatches.Id, result.targetAccountId);
    }

    @IsTest
    static void testMinimumAgeSkipsSourceWithMinor() {
        Account source = new Account(Name = 'Source Minor');
        Account target = new Account(Name = 'Target Adult');
        insert new List<Account>{ source, target };

        Date minorDob = Date.today().addYears(-18).addDays(1);
        insert new List<Contact>{
            new Contact(AccountId = source.Id, FirstName = 'Young', LastName = 'Person', Birthdate = minorDob),
            new Contact(AccountId = target.Id, FirstName = 'Young', LastName = 'Person', Birthdate = minorDob)
        };

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                'FirstName,LastName,Birthdate',
                'Birthdate > ' + String.valueOf(Date.today().addYears(-18))
            );

        System.assertEquals(false, result.candidateFound);
        System.assert(result.message.contains('exclusion criteria'));
    }

    @IsTest
    static void testMinimumAgeSkipsTargetWithExtraMinor() {
        Account source = new Account(Name = 'Source Adults');
        Account target = new Account(Name = 'Target Has Minor');
        insert new List<Account>{ source, target };

        Date adultDob = Date.today().addYears(-30);
        Date minorDob = Date.today().addYears(-10);
        insert new List<Contact>{
            new Contact(AccountId = source.Id, FirstName = 'Adult', LastName = 'Person', Birthdate = adultDob),
            new Contact(AccountId = target.Id, FirstName = 'Adult', LastName = 'Person', Birthdate = adultDob),
            new Contact(AccountId = target.Id, FirstName = 'Child', LastName = 'Person', Birthdate = minorDob)
        };

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                'FirstName,LastName,Birthdate',
                'Birthdate > ' + String.valueOf(Date.today().addYears(-18))
            );

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(
            'No target account found where all source contacts match on required fields.',
            result.message
        );
    }

    @IsTest
    static void testMoveMatchedContactsToMaster_NoOpAndUpdatePath() {
        DHM_SingleAccountMergeService.moveMatchedContactsToMaster(null);

        DHM_SingleAccountMergeService.MatchBundle emptyBundle =
            new DHM_SingleAccountMergeService.MatchBundle();
        DHM_SingleAccountMergeService.moveMatchedContactsToMaster(emptyBundle);

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

        DHM_SingleAccountMergeService.MatchBundle bundle =
            new DHM_SingleAccountMergeService.MatchBundle();
        bundle.sourceAccountId = source.Id;
        bundle.targetAccountId = target.Id;

        DHM_SingleAccountMergeService.ContactMatch cm =
            new DHM_SingleAccountMergeService.ContactMatch();
        cm.sourceContact = sourceCon;
        cm.targetContact = null;
        bundle.contactMatches.add(cm);

        Test.startTest();
        DHM_SingleAccountMergeService.moveMatchedContactsToMaster(bundle);
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