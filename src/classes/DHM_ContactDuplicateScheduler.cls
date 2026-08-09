global with sharing class DHM_ContactDuplicateScheduler implements Schedulable {

    public static final String FLOW_API_NAME = 'DHM_Contact_Duplicate_Management';

    @TestVisible
    private static Boolean skipFlowStartForTest = false;

    global void execute(SchedulableContext context) {
        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_ContactDuplicateScheduler::execute ENTER flow=' + FLOW_API_NAME
        );

        if (Test.isRunningTest() && skipFlowStartForTest) {
            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_ContactDuplicateScheduler::execute TEST flow start skipped'
            );
            return;
        }

        Map<String, Object> inputs = new Map<String, Object>();
        Flow.Interview.DHM_Contact_Duplicate_Management interview =
            new Flow.Interview.DHM_Contact_Duplicate_Management(inputs);
        interview.start();

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_ContactDuplicateScheduler::execute EXIT flow=' + FLOW_API_NAME
        );
    }
}