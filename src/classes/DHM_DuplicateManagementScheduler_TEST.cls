@IsTest
private class DHM_DuplicateManagementScheduler_TEST {

    @IsTest
    static void testAccountScheduler() {
        DHM_AccountDuplicateScheduler.skipFlowStartForTest = true;
        try {
            new DHM_AccountDuplicateScheduler().execute(null);
            System.assertEquals(
                'DHM_Account_Duplicate_Management',
                DHM_AccountDuplicateScheduler.FLOW_API_NAME
            );
        } finally {
            DHM_AccountDuplicateScheduler.skipFlowStartForTest = false;
        }
    }

    @IsTest
    static void testContactScheduler() {
        DHM_ContactDuplicateScheduler.skipFlowStartForTest = true;
        try {
            new DHM_ContactDuplicateScheduler().execute(null);
            System.assertEquals(
                'DHM_Contact_Duplicate_Management',
                DHM_ContactDuplicateScheduler.FLOW_API_NAME
            );
        } finally {
            DHM_ContactDuplicateScheduler.skipFlowStartForTest = false;
        }
    }
}