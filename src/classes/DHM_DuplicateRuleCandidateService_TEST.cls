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
                null
            );

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
}