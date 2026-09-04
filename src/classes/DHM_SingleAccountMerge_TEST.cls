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
                false,
                'Birthdate',
                null,
                null,
                false);
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
                false,
                'Birthdate',
                null,
                null,
                false);

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
                false,
                null,
                null,
                null,
                false);

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
                false,
                'Birthdate',
                null,
                null,
                false);

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals('No target account found where all Contacts in one Account have distinct matches in the other Account.', result.message);
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
                'FirstName,LastName,Birthdate',
                null,
                null,
                false);

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
        System.assertEquals(2, parsedBlank.size());
        System.assertEquals('FirstName', parsedBlank[0]);
        System.assertEquals('LastName', parsedBlank[1]);

        List<String> parsedEmpty = DHM_SingleAccountMergeService.parseMatchFields('');
        System.assertEquals(2, parsedEmpty.size());
        System.assertEquals('FirstName', parsedEmpty[0]);
        System.assertEquals('LastName', parsedEmpty[1]);
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
                true,
                null,
                null,
                null,
                false);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals(true, result.staged);
        System.assertEquals(target.Id, result.masterAccountId);
        System.assertEquals(source.Id, result.duplicateAccountId);
        System.assert(result.message.contains('Staged account'));

        Account stagedSource = [
            SELECT Id, DHM_Pending_Merge__c, DHM_Merge_After__c, DHM_Merge_Into_Account__c
            FROM Account
            WHERE Id = :source.Id
            LIMIT 1
        ];
        System.assertEquals(true, stagedSource.DHM_Pending_Merge__c);
        System.assertEquals(Date.today().addDays(1), stagedSource.DHM_Merge_After__c);
        System.assertEquals(target.Id, stagedSource.DHM_Merge_Into_Account__c);
        System.assertEquals(0, [SELECT COUNT() FROM Contact WHERE AccountId = :source.Id]);

        // Make the staged merge due and verify the second-phase merge.
        stagedSource.DHM_Merge_After__c = Date.today().addDays(-1);
        update stagedSource;

        DHM_SingleAccountMerge.Result pendingResult =
            DHM_SingleAccountMergeService.mergePendingAccount(source.Id);
        System.assertEquals(true, pendingResult.candidateFound);
        System.assertEquals(true, pendingResult.merged);
        System.assertEquals(target.Id, pendingResult.masterAccountId);

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
            DHM_SingleAccountMergeService.evaluateAndMerge(source.Id, false, null, null, null, false);

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
                'Email',
                null,
                null,
                false);

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
            DHM_SingleAccountMergeService.evaluateAndMerge(source.Id, false, null, null, null, false);

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
                'Birthdate > ' + String.valueOf(Date.today().addYears(-18)),
                null,
                false);

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
                'Birthdate > ' + String.valueOf(Date.today().addYears(-18)),
                null,
                false);

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(
            'No target account found where all Contacts in one Account have distinct matches in the other Account.',
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


    @IsTest
    static void testDuplicateRulesDeriveAccountCandidateFromContactMatches() {
        Account source = new Account(Name = 'Source Household Different Name');
        Account target = new Account(Name = 'Completely Different Household Name');
        insert new List<Account>{ source, target };

        Contact sourceOne = new Contact(AccountId = source.Id, FirstName = 'John', LastName = 'Smith');
        Contact sourceTwo = new Contact(AccountId = source.Id, FirstName = 'Mary', LastName = 'Jones');
        Contact targetOne = new Contact(AccountId = target.Id, FirstName = 'John', LastName = 'Smith');
        Contact targetTwo = new Contact(AccountId = target.Id, FirstName = 'Mary', LastName = 'Jones');
        Contact targetExtra = new Contact(AccountId = target.Id, FirstName = 'Extra', LastName = 'Member');
        insert new List<Contact>{ sourceOne, sourceTwo, targetOne, targetTwo, targetExtra };

        // Deliberately provide Contact candidate mappings only. There is no Account
        // candidate mapping, proving Account discovery is driven by Contact Duplicate Rules.
        DHM_DuplicateRuleCandidateService.setTestCandidates(new Map<Id, Set<Id>>{
            sourceOne.Id => new Set<Id>{ targetOne.Id },
            sourceTwo.Id => new Set<Id>{ targetTwo.Id }
        });

        Test.startTest();
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(source.Id, false, null, null, null, false);
        Test.stopTest();

        DHM_DuplicateRuleCandidateService.clearTestCandidates();

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(target.Id, result.masterAccountId);
        System.assertEquals(source.Id, result.duplicateAccountId);
    }

    @IsTest
    static void testRequireAllMatchingContactsRejectsDifferentHouseholdSizes() {
        Account source = new Account(Name = 'Strict Source Household');
        Account target = new Account(Name = 'Strict Target Larger Household');
        insert new List<Account>{ source, target };

        Contact sourceOne = new Contact(AccountId = source.Id, FirstName = 'John', LastName = 'Smith');
        Contact sourceTwo = new Contact(AccountId = source.Id, FirstName = 'Mary', LastName = 'Jones');
        Contact targetOne = new Contact(AccountId = target.Id, FirstName = 'John', LastName = 'Smith');
        Contact targetTwo = new Contact(AccountId = target.Id, FirstName = 'Mary', LastName = 'Jones');
        Contact targetExtra = new Contact(AccountId = target.Id, FirstName = 'Extra', LastName = 'Member');
        insert new List<Contact>{ sourceOne, sourceTwo, targetOne, targetTwo, targetExtra };

        DHM_DuplicateRuleCandidateService.setTestCandidates(new Map<Id, Set<Id>>{
            sourceOne.Id => new Set<Id>{ targetOne.Id },
            sourceTwo.Id => new Set<Id>{ targetTwo.Id },
            targetOne.Id => new Set<Id>{ sourceOne.Id },
            targetTwo.Id => new Set<Id>{ sourceTwo.Id },
            targetExtra.Id => new Set<Id>()
        });

        Test.startTest();
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                null,
                null,
                null,
                true
            );
        Test.stopTest();

        DHM_DuplicateRuleCandidateService.clearTestCandidates();

        System.assertEquals(false, result.candidateFound);
        System.assert(result.message.contains('same number of Contacts'));
    }

    @IsTest
    static void testRequireAllMatchingContactsAcceptsEqualHouseholdSizes() {
        Account source = new Account(Name = 'Strict Equal Source');
        Account target = new Account(Name = 'Strict Equal Target');
        insert new List<Account>{ source, target };

        Contact sourceOne = new Contact(AccountId = source.Id, LastName = 'Smith');
        Contact sourceTwo = new Contact(AccountId = source.Id, LastName = 'Jones');
        Contact targetOne = new Contact(AccountId = target.Id, LastName = 'Smith');
        Contact targetTwo = new Contact(AccountId = target.Id, LastName = 'Jones');
        insert new List<Contact>{ sourceOne, sourceTwo, targetOne, targetTwo };

        DHM_DuplicateRuleCandidateService.setTestCandidates(new Map<Id, Set<Id>>{
            sourceOne.Id => new Set<Id>{ targetOne.Id },
            sourceTwo.Id => new Set<Id>{ targetTwo.Id }
        });

        Test.startTest();
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                null,
                null,
                null,
                true
            );
        Test.stopTest();

        DHM_DuplicateRuleCandidateService.clearTestCandidates();

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(target.Id, result.masterAccountId);
    }

    @IsTest
    static void testDuplicateRulesCanMergeSmallerCandidateIntoSource() {
        Account source = new Account(Name = 'Larger Source Household');
        Account candidate = new Account(Name = 'Smaller Candidate Household');
        insert new List<Account>{ source, candidate };

        // Newest-created record is the merge master. Make the source explicitly newer
        // so this test validates asymmetric household matching independently of insert timing.
        Test.setCreatedDate(candidate.Id, Datetime.newInstance(2026, 1, 1, 0, 0, 0));
        Test.setCreatedDate(source.Id, Datetime.newInstance(2026, 1, 2, 0, 0, 0));

        Contact sourceOne = new Contact(AccountId = source.Id, LastName = 'Smith');
        Contact sourceExtra = new Contact(AccountId = source.Id, LastName = 'Unmatched Adult');
        Contact candidateOne = new Contact(AccountId = candidate.Id, LastName = 'Smith');
        insert new List<Contact>{ sourceOne, sourceExtra, candidateOne };

        DHM_DuplicateRuleCandidateService.setTestCandidates(new Map<Id, Set<Id>>{
            sourceOne.Id => new Set<Id>{ candidateOne.Id },
            sourceExtra.Id => new Set<Id>(),
            candidateOne.Id => new Set<Id>{ sourceOne.Id }
        });

        Test.startTest();
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(source.Id, false, null, null, null, false);
        Test.stopTest();

        DHM_DuplicateRuleCandidateService.clearTestCandidates();

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(source.Id, result.masterAccountId);
        System.assertEquals(candidate.Id, result.duplicateAccountId);
    }

    @IsTest
    static void testDuplicateRulesRequireDistinctContactMatches() {
        Account source = new Account(Name = 'Source Twins Contact Driven');
        Account candidate = new Account(Name = 'Candidate One Contact');
        insert new List<Account>{ source, candidate };

        Contact sourceOne = new Contact(AccountId = source.Id, LastName = 'Same');
        Contact sourceTwo = new Contact(AccountId = source.Id, LastName = 'Same');
        Contact candidateOne = new Contact(AccountId = candidate.Id, LastName = 'Same');
        Contact candidateOther = new Contact(AccountId = candidate.Id, LastName = 'Different');
        insert new List<Contact>{ sourceOne, sourceTwo, candidateOne, candidateOther };

        // Both source Contacts point at the same candidate Contact. The other candidate
        // Contact has no match, so neither direction satisfies the full-household rule.
        DHM_DuplicateRuleCandidateService.setTestCandidates(new Map<Id, Set<Id>>{
            sourceOne.Id => new Set<Id>{ candidateOne.Id },
            sourceTwo.Id => new Set<Id>{ candidateOne.Id },
            candidateOne.Id => new Set<Id>{ sourceOne.Id, sourceTwo.Id },
            candidateOther.Id => new Set<Id>()
        });

        Test.startTest();
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(source.Id, false, null, null, null, false);
        Test.stopTest();

        DHM_DuplicateRuleCandidateService.clearTestCandidates();

        System.assertEquals(false, result.candidateFound);
    }

    @IsTest
    static void testAllowedUnmatchedContactCriteriaAllowsChildButRequiresAdults() {
        Account source = new Account(Name = 'Source Adult Plus Child');
        Account target = new Account(Name = 'Target Adult Only');
        insert new List<Account>{ source, target };

        Contact sourceAdult = new Contact(
            AccountId = source.Id, LastName = 'Adult', Birthdate = Date.newInstance(1980, 1, 1)
        );
        Contact sourceChild = new Contact(
            AccountId = source.Id, LastName = 'Child', Birthdate = Date.newInstance(2015, 1, 1)
        );
        Contact targetAdult = new Contact(
            AccountId = target.Id, LastName = 'Adult', Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert new List<Contact>{ sourceAdult, sourceChild, targetAdult };

        DHM_DuplicateRuleCandidateService.setTestCandidates(new Map<Id, Set<Id>>{
            sourceAdult.Id => new Set<Id>{ targetAdult.Id },
            sourceChild.Id => new Set<Id>(),
            targetAdult.Id => new Set<Id>{ sourceAdult.Id }
        });

        Test.startTest();
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                null,
                null,
                'Birthdate > 2010-01-01',
                false
            );
        Test.stopTest();
        DHM_DuplicateRuleCandidateService.clearTestCandidates();

        System.assertEquals(true, result.candidateFound);
    }

    @IsTest
    static void testAllowedUnmatchedContactCriteriaRejectsUnmatchedAdult() {
        Account source = new Account(Name = 'Source With Extra Adult');
        Account target = new Account(Name = 'Target Missing Adult');
        insert new List<Account>{ source, target };

        Contact sourceAdultOne = new Contact(
            AccountId = source.Id, LastName = 'Adult One', Birthdate = Date.newInstance(1980, 1, 1)
        );
        Contact sourceAdultTwo = new Contact(
            AccountId = source.Id, LastName = 'Adult Two', Birthdate = Date.newInstance(1985, 1, 1)
        );
        Contact targetAdultOne = new Contact(
            AccountId = target.Id, LastName = 'Adult One', Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert new List<Contact>{ sourceAdultOne, sourceAdultTwo, targetAdultOne };

        DHM_DuplicateRuleCandidateService.setTestCandidates(new Map<Id, Set<Id>>{
            sourceAdultOne.Id => new Set<Id>{ targetAdultOne.Id },
            sourceAdultTwo.Id => new Set<Id>(),
            targetAdultOne.Id => new Set<Id>{ sourceAdultOne.Id }
        });

        Test.startTest();
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                null,
                null,
                'Birthdate > 2010-01-01',
                false
            );
        Test.stopTest();
        DHM_DuplicateRuleCandidateService.clearTestCandidates();

        System.assertEquals(false, result.candidateFound);
        System.assert(result.message.contains('Allowed Unmatched Contact Criteria'));
    }

    @IsTest
    static void testRequireAllMatchingContactsOverridesAllowedUnmatchedCriteria() {
        Account source = new Account(Name = 'Strict Source Adult Child');
        Account target = new Account(Name = 'Strict Target Adult');
        insert new List<Account>{ source, target };

        Contact sourceAdult = new Contact(
            AccountId = source.Id, LastName = 'Adult', Birthdate = Date.newInstance(1980, 1, 1)
        );
        Contact sourceChild = new Contact(
            AccountId = source.Id, LastName = 'Child', Birthdate = Date.newInstance(2015, 1, 1)
        );
        Contact targetAdult = new Contact(
            AccountId = target.Id, LastName = 'Adult', Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert new List<Contact>{ sourceAdult, sourceChild, targetAdult };

        DHM_DuplicateRuleCandidateService.setTestCandidates(new Map<Id, Set<Id>>{
            sourceAdult.Id => new Set<Id>{ targetAdult.Id },
            sourceChild.Id => new Set<Id>(),
            targetAdult.Id => new Set<Id>{ sourceAdult.Id }
        });

        Test.startTest();
        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                source.Id,
                false,
                null,
                null,
                'Birthdate > 2010-01-01',
                true
            );
        Test.stopTest();
        DHM_DuplicateRuleCandidateService.clearTestCandidates();

        System.assertEquals(false, result.candidateFound);
        System.assert(result.message.contains('same number of Contacts'));
    }

    @IsTest
    static void testReverseMatchBundleSwapsMasterDirection() {
        Account older = new Account(Name = 'Older');
        Account newer = new Account(Name = 'Newer');
        insert new List<Account>{ older, newer };
        Contact olderContact = new Contact(AccountId = older.Id, LastName = 'Match');
        Contact newerContact = new Contact(AccountId = newer.Id, LastName = 'Match');
        insert new List<Contact>{ olderContact, newerContact };

        DHM_SingleAccountMergeService.MatchBundle original =
            new DHM_SingleAccountMergeService.MatchBundle();
        original.sourceAccountId = newer.Id;
        original.targetAccountId = older.Id;
        DHM_SingleAccountMergeService.ContactMatch cm =
            new DHM_SingleAccountMergeService.ContactMatch();
        cm.sourceContact = newerContact;
        cm.targetContact = olderContact;
        original.contactMatches.add(cm);

        DHM_SingleAccountMergeService.MatchBundle reversed =
            DHM_SingleAccountMergeService.reverseMatchBundle(original);
        System.assertEquals(older.Id, reversed.sourceAccountId);
        System.assertEquals(newer.Id, reversed.targetAccountId);
        System.assertEquals(olderContact.Id, reversed.contactMatches[0].sourceContact.Id);
        System.assertEquals(newerContact.Id, reversed.contactMatches[0].targetContact.Id);
    }

    @IsTest
    static void testStageAccountMergeRejectsInvalidIds() {
        Account acct = new Account(Name = 'Stage Validation');
        insert acct;

        Boolean nullRejected = false;
        try {
            DHM_SingleAccountMergeService.stageAccountMerge(null, acct.Id);
        } catch (IllegalArgumentException e) {
            nullRejected = true;
        }
        System.assertEquals(true, nullRejected);

        Boolean sameRejected = false;
        try {
            DHM_SingleAccountMergeService.stageAccountMerge(acct.Id, acct.Id);
        } catch (IllegalArgumentException e) {
            sameRejected = true;
        }
        System.assertEquals(true, sameRejected);
    }

    @IsTest
    static void testMergePendingAccountSourceMissing() {
        // Create a real Account Id, then roll the insert back so the service can
        // exercise its "source no longer exists" branch without firing Account
        // delete automation/triggers in the test org.
        Savepoint sp = Database.setSavepoint();
        Account source = new Account(Name = 'Pending Missing Source');
        insert source;
        Id sourceId = source.Id;
        Database.rollback(sp);

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.mergePendingAccount(sourceId);

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assert(result.message.contains('no longer exists'));
    }

    @IsTest
    static void testMergePendingAccountNotMarked() {
        Account source = new Account(Name = 'Pending Not Marked');
        insert source;

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.mergePendingAccount(source.Id);

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assert(result.message.contains('not marked'));
    }

    @IsTest
    static void testMergePendingAccountNotDueYet() {
        Account source = new Account(
            Name = 'Pending Future Source',
            DHM_Pending_Merge__c = true,
            DHM_Merge_After__c = Date.today().addDays(1)
        );
        insert source;

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.mergePendingAccount(source.Id);

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals(true, result.staged);
        System.assert(result.message.contains('not due yet'));
    }

    @IsTest
    static void testMergePendingAccountMissingMaster() {
        Account source = new Account(
            Name = 'Pending No Master',
            DHM_Pending_Merge__c = true,
            DHM_Merge_After__c = Date.today().addDays(-1)
        );
        insert source;

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.mergePendingAccount(source.Id);

        System.assertEquals(false, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals(true, result.staged);
        System.assert(result.message.contains('no master Account'));
    }

    @IsTest
    static void testMergePendingAccountRetainedWhenContactsRemain() {
        Account master = new Account(Name = 'Pending Contact Master');
        Account source = new Account(Name = 'Pending Contact Source');
        insert new List<Account>{ master, source };

        source.DHM_Pending_Merge__c = true;
        source.DHM_Merge_After__c = Date.today().addDays(-1);
        source.DHM_Merge_Into_Account__c = master.Id;
        update source;

        insert new Contact(
            AccountId = source.Id,
            FirstName = 'Still',
            LastName = 'Here'
        );

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.mergePendingAccount(source.Id);

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(false, result.merged);
        System.assertEquals(true, result.staged);
        System.assert(result.message.contains('still has 1 Contact'));

        Account stillPending = [
            SELECT DHM_Pending_Merge__c, DHM_Merge_Into_Account__c
            FROM Account
            WHERE Id = :source.Id
        ];
        System.assertEquals(true, stillPending.DHM_Pending_Merge__c);
        System.assertEquals(master.Id, stillPending.DHM_Merge_Into_Account__c);
    }



    @IsTest
    static void testCriteriaAndAccountExclusionHelpers_CoverageBoost() {
        Account a1 = new Account(Name = 'Criteria Account One');
        Account a2 = new Account(Name = 'Criteria Account Two');
        insert new List<Account>{ a1, a2 };

        Contact minor = new Contact(
            AccountId = a1.Id,
            FirstName = 'Minor',
            LastName = 'Kid',
            Birthdate = Date.newInstance(2015, 6, 1)
        );
        Contact adult = new Contact(
            AccountId = a2.Id,
            FirstName = 'Adult',
            LastName = 'Person',
            Birthdate = Date.newInstance(1980, 1, 1)
        );
        insert new List<Contact>{ minor, adult };

        String criteria = 'Birthdate >= 2010-01-01 AND (FirstName = \'Minor\' OR LastName = \'Kid\')';
        System.assertEquals(
            criteria,
            DHM_SingleAccountMergeService.validateContactExclusionCriteria(criteria)
        );

        Set<Id> matchingContacts =
            DHM_SingleAccountMergeService.findContactIdsMatchingCriteria(
                new Set<Id>{ minor.Id, adult.Id }, criteria
            );
        System.assertEquals(new Set<Id>{ minor.Id }, matchingContacts);

        System.assertEquals(
            true,
            DHM_SingleAccountMergeService.accountMatchesContactExclusion(a1.Id, criteria)
        );
        System.assertEquals(
            false,
            DHM_SingleAccountMergeService.accountMatchesContactExclusion(a2.Id, criteria)
        );
        System.assertEquals(
            false,
            DHM_SingleAccountMergeService.accountMatchesContactExclusion(null, criteria)
        );
        System.assertEquals(
            false,
            DHM_SingleAccountMergeService.accountMatchesContactExclusion(a1.Id, null)
        );

        Set<Id> matchingAccounts =
            DHM_SingleAccountMergeService.findAccountIdsMatchingContactExclusion(
                new Set<Id>{ a1.Id, a2.Id }, criteria
            );
        System.assertEquals(new Set<Id>{ a1.Id }, matchingAccounts);

        System.assertEquals(
            0,
            DHM_SingleAccountMergeService.findContactIdsMatchingCriteria(null, criteria).size()
        );
        System.assertEquals(
            0,
            DHM_SingleAccountMergeService.findContactIdsMatchingCriteria(new Set<Id>(), criteria).size()
        );
        System.assertEquals(
            0,
            DHM_SingleAccountMergeService.findAccountIdsMatchingContactExclusion(null, criteria).size()
        );
        System.assertEquals(
            0,
            DHM_SingleAccountMergeService.findAccountIdsMatchingContactExclusion(new Set<Id>(), criteria).size()
        );
    }

    @IsTest
    static void testCriteriaValidationAndTokenizationBranches_CoverageBoost() {
        System.assertEquals(null, DHM_SingleAccountMergeService.validateContactExclusionCriteria(null));
        System.assertEquals(null, DHM_SingleAccountMergeService.validateContactExclusionCriteria('   '));

        List<String> tokens = DHM_SingleAccountMergeService.tokenizeCriteria(
            '(Birthdate < 2010-01-01 OR FirstName != \'O\'\'Brien\') AND DoNotCall = false'
        );
        System.assert(tokens.size() > 10);
        System.assert(tokens.contains('('));
        System.assert(tokens.contains('!='));
        System.assert(tokens.contains('false'));

        // Exercise supported literal types and comparison operators.
        DHM_SingleAccountMergeService.validateContactExclusionCriteria('Birthdate = null');
        DHM_SingleAccountMergeService.validateContactExclusionCriteria('DoNotCall = true');
    }

    @IsTest
    static void testCriteriaValidationRejectsUnsafeInputs_CoverageBoost() {
        List<String> badCriteria = new List<String>{
            'LastName LIKE \'Smith%\'',
            'LastName = \'Smith\';',
            'LastName = :name',
            'Bogus_Field__c = 1',
            'LastName ~~ \'Smith\'',
            'LastName =',
            '(LastName = \'Smith\''
        };

        for (String criteria : badCriteria) {
            Boolean rejected = false;
            try {
                DHM_SingleAccountMergeService.validateContactExclusionCriteria(criteria);
            } catch (IllegalArgumentException e) {
                rejected = true;
            }
            System.assertEquals(true, rejected, 'Expected criteria to be rejected: ' + criteria);
        }

        String tooLong = '';
        for (Integer i = 0; i < 1001; i++) {
            tooLong += 'x';
        }
        Boolean longRejected = false;
        try {
            DHM_SingleAccountMergeService.validateContactExclusionCriteria(tooLong);
        } catch (IllegalArgumentException e) {
            longRejected = true;
        }
        System.assertEquals(true, longRejected);

        Boolean unterminatedRejected = false;
        try {
            DHM_SingleAccountMergeService.tokenizeCriteria('LastName = \'Smith');
        } catch (IllegalArgumentException e) {
            unterminatedRejected = true;
        }
        System.assertEquals(true, unterminatedRejected);
    }

    @IsTest
    static void testMatchFieldAndLiteralHelpers_CoverageBoost() {
        DHM_SingleAccountMergeService.validateMatchFields(
            new List<String>{ 'FirstName', 'LastName', 'Birthdate' }
        );
        System.assertEquals(
            'FirstName',
            DHM_SingleAccountMergeService.findFilterableMatchField(
                new List<String>{ 'FirstName', 'LastName' }
            )
        );

        List<List<String>> invalidFieldLists = new List<List<String>>{
            null,
            new List<String>(),
            new List<String>{ 'Bogus_Field__c' },
            new List<String>{ 'LastName', 'LastName' }
        };
        for (List<String> fields : invalidFieldLists) {
            Boolean rejected = false;
            try {
                DHM_SingleAccountMergeService.validateMatchFields(fields);
            } catch (IllegalArgumentException e) {
                rejected = true;
            }
            System.assertEquals(true, rejected);
        }

        Boolean noFilterableRejected = false;
        try {
            DHM_SingleAccountMergeService.findFilterableMatchField(
                new List<String>{ 'Bogus_Field__c' }
            );
        } catch (IllegalArgumentException e) {
            noFilterableRejected = true;
        }
        System.assertEquals(true, noFilterableRejected);

        System.assertEquals('null', DHM_SingleAccountMergeService.toSoqlLiteral(null));
        System.assertEquals('2026-09-04', DHM_SingleAccountMergeService.toSoqlLiteral(Date.newInstance(2026, 9, 4)));
        System.assertEquals('true', DHM_SingleAccountMergeService.toSoqlLiteral(true));
        System.assertEquals('42', DHM_SingleAccountMergeService.toSoqlLiteral(42));
        System.assertEquals('42.5', DHM_SingleAccountMergeService.toSoqlLiteral(Decimal.valueOf('42.5')));
        String escapedLiteral = DHM_SingleAccountMergeService.toSoqlLiteral('O\'Brien');
        System.assert(escapedLiteral.startsWith('\''));
        System.assert(escapedLiteral.endsWith('\''));
        System.assert(escapedLiteral.contains('Brien'));
        System.assert(escapedLiteral.contains('\\'));

        String dateTimeLiteral = DHM_SingleAccountMergeService.toSoqlLiteral(
            Datetime.newInstanceGMT(2026, 9, 4, 12, 30, 0)
        );
        System.assertEquals('2026-09-04T12:30:00Z', dateTimeLiteral);

        Set<Object> values = new Set<Object>{ 'B', 'A', 2 };
        String literalList = DHM_SingleAccountMergeService.buildSoqlLiteralList(values);
        System.assert(literalList.contains('\'A\''));
        System.assert(literalList.contains('\'B\''));
        System.assert(literalList.contains('2'));
    }

    @IsTest
    static void testRequiredKeyCountsBranches_CoverageBoost() {
        Map<String, Integer> required = new Map<String, Integer>{ 'A' => 2, 'B' => 1 };
        Map<String, List<Contact>> enough = new Map<String, List<Contact>>{
            'A' => new List<Contact>{ new Contact(), new Contact() },
            'B' => new List<Contact>{ new Contact() }
        };
        Map<String, List<Contact>> tooFew = new Map<String, List<Contact>>{
            'A' => new List<Contact>{ new Contact() },
            'B' => new List<Contact>{ new Contact() }
        };

        System.assertEquals(true, DHM_SingleAccountMergeService.hasRequiredKeyCounts(required, enough));
        System.assertEquals(false, DHM_SingleAccountMergeService.hasRequiredKeyCounts(required, tooFew));
        System.assertEquals(false, DHM_SingleAccountMergeService.hasRequiredKeyCounts(required, new Map<String, List<Contact>>()));
        System.assertEquals(false, DHM_SingleAccountMergeService.hasRequiredKeyCounts(null, enough));
        System.assertEquals(false, DHM_SingleAccountMergeService.hasRequiredKeyCounts(required, null));
    }

}