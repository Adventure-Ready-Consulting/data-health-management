@IsTest
private class DHM_DuplicateRuleCandidateService_TEST {

    @IsTest
    static void testContactDuplicateRulesRespectSameAccountBoundary() {
        Account householdOne = new Account(Name = 'Household One');
        Account householdTwo = new Account(Name = 'Household Two');
        insert new List<Account>{ householdOne, householdTwo };

        Contact source = new Contact(LastName = 'Source', AccountId = householdOne.Id);
        Contact sameAccount = new Contact(LastName = 'Same', AccountId = householdOne.Id);
        Contact otherAccount = new Contact(LastName = 'Other', AccountId = householdTwo.Id);
        insert new List<Contact>{ source, sameAccount, otherAccount };

        DHM_DuplicateRuleCandidateService.setTestCandidates(
            new Map<Id, Set<Id>>{
                source.Id => new Set<Id>{ sameAccount.Id, otherAccount.Id }
            }
        );

        DHM_SingleContactMerge.Result result =
            DHM_SingleContactMergeService.evaluateAndMerge(source.Id, false, null);

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(
            new Set<Id>{ source.Id, sameAccount.Id },
            new Set<Id>{ result.masterContactId, result.duplicateContactId }
        );
        DHM_DuplicateRuleCandidateService.clearTestCandidates();
    }

    @IsTest
    static void testAccountRulesAndContactRulesCreateSafeCandidate() {
        Account sourceAccount = new Account(Name = 'Source Household');
        Account targetAccount = new Account(Name = 'Target Household');
        insert new List<Account>{ sourceAccount, targetAccount };

        Contact sourceContact = new Contact(LastName = 'Source Member', AccountId = sourceAccount.Id);
        Contact targetContact = new Contact(LastName = 'Target Member', AccountId = targetAccount.Id);
        insert new List<Contact>{ sourceContact, targetContact };

        DHM_DuplicateRuleCandidateService.setTestCandidates(
            new Map<Id, Set<Id>>{
                sourceAccount.Id => new Set<Id>{ targetAccount.Id },
                sourceContact.Id => new Set<Id>{ targetContact.Id },
                targetContact.Id => new Set<Id>{ sourceContact.Id }
            }
        );

        DHM_SingleAccountMerge.Result result =
            DHM_SingleAccountMergeService.evaluateAndMerge(
                sourceAccount.Id,
                false,
                null,
                null,
                false);

        System.assertEquals(true, result.candidateFound);
        System.assertEquals(targetAccount.Id, result.masterAccountId);
        System.assertEquals(sourceAccount.Id, result.duplicateAccountId);
        DHM_DuplicateRuleCandidateService.clearTestCandidates();
    }

    @IsTest
    static void testProviderRemovesSourceId() {
        Account source = new Account(Name = 'Source');
        Account candidate = new Account(Name = 'Candidate');
        insert new List<Account>{ source, candidate };

        DHM_DuplicateRuleCandidateService.setTestCandidates(
            new Map<Id, Set<Id>>{
                source.Id => new Set<Id>{ source.Id, candidate.Id }
            }
        );
        Set<Id> candidates = DHM_DuplicateRuleCandidateService.findCandidates(source.Id);
        System.assertEquals(false, candidates.contains(source.Id));
        System.assertEquals(true, candidates.contains(candidate.Id));
        DHM_DuplicateRuleCandidateService.clearTestCandidates();
    }


    @IsTest
    static void testAdditionalMatchFieldsFiltersByBirthdate() {
        Account acct = new Account(Name = 'Additional Match Household');
        insert acct;

        Contact source = new Contact(
            FirstName = 'David', LastName = 'Boyce', AccountId = acct.Id,
            Birthdate = Date.newInstance(1972, 1, 1)
        );
        Contact matching = new Contact(
            FirstName = 'David', LastName = 'Boyce', AccountId = acct.Id,
            Birthdate = Date.newInstance(1972, 1, 1)
        );
        Contact differentDob = new Contact(
            FirstName = 'David', LastName = 'Boyce', AccountId = acct.Id,
            Birthdate = Date.newInstance(1973, 1, 1)
        );
        insert new List<Contact>{ source, matching, differentDob };

        Set<Id> filtered = DHM_DuplicateRuleCandidateService.filterContactCandidatesByAdditionalFields(
            source.Id,
            new Set<Id>{ matching.Id, differentDob.Id },
            'Birthdate'
        );

        System.assertEquals(new Set<Id>{ matching.Id }, filtered);
    }

    @IsTest
    static void testAdditionalMatchFieldsRejectsBlankBirthdateAndInvalidField() {
        Account acct = new Account(Name = 'Blank Additional Match Household');
        insert acct;

        Contact source = new Contact(LastName = 'Boyce', AccountId = acct.Id);
        Contact candidate = new Contact(LastName = 'Boyce', AccountId = acct.Id);
        insert new List<Contact>{ source, candidate };

        Set<Id> filtered = DHM_DuplicateRuleCandidateService.filterContactCandidatesByAdditionalFields(
            source.Id,
            new Set<Id>{ candidate.Id },
            'Birthdate'
        );
        System.assertEquals(0, filtered.size(), 'Two blank identity fields must not be treated as a match.');

        Boolean threwExpectedError = false;
        try {
            DHM_DuplicateRuleCandidateService.filterContactCandidatesByAdditionalFields(
                source.Id,
                new Set<Id>{ candidate.Id },
                'Not_A_Contact_Field__c'
            );
        } catch (DHM_DuplicateRuleCandidateService.DuplicateRuleException e) {
            threwExpectedError = true;
        }
        System.assertEquals(true, threwExpectedError);
    }



    @IsTest
    static void testGenericRequiredAdditionalFieldPopulationByType() {
        Contact c = new Contact(
            LastName = 'Generic',
            Birthdate = Date.newInstance(1972, 1, 1),
            Email = 'person@example.org'
        );

        System.assertEquals(
            true,
            DHM_DuplicateRuleCandidateService.hasAllRequiredAdditionalMatchFieldValues(
                c,
                'Birthdate'
            ),
            'A populated Date field should satisfy required additional-field validation.'
        );

        c.Birthdate = null;
        System.assertEquals(
            false,
            DHM_DuplicateRuleCandidateService.hasAllRequiredAdditionalMatchFieldValues(
                c,
                'Birthdate'
            ),
            'A null Date field should fail required additional-field validation.'
        );

        c.Email = '   ';
        System.assertEquals(
            false,
            DHM_DuplicateRuleCandidateService.hasAllRequiredAdditionalMatchFieldValues(
                c,
                'Email'
            ),
            'A blank text-like field should fail required additional-field validation.'
        );

        c.Email = 'person@example.org';
        System.assertEquals(
            true,
            DHM_DuplicateRuleCandidateService.hasAllRequiredAdditionalMatchFieldValues(
                c,
                'Email'
            ),
            'A nonblank text-like field should satisfy required additional-field validation.'
        );

        System.assertEquals(
            true,
            DHM_DuplicateRuleCandidateService.hasAllRequiredAdditionalMatchFieldValues(
                c,
                null
            ),
            'No configured additional fields means there is no additional required-field gate.'
        );
    }

}