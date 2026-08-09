global with sharing class DHM_AccountDuplicateScheduler implements Schedulable {

    public static final String FLOW_API_NAME = 'DHM_Account_Duplicate_Management';

    @TestVisible
    private static Boolean skipFlowStartForTest = false;

    global void execute(SchedulableContext context) {
        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_AccountDuplicateScheduler::execute ENTER flow=' + FLOW_API_NAME
        );

        if (Test.isRunningTest() && skipFlowStartForTest) {
            DHM_SharedCode.OutputDebugLogText(
                LoggingLevel.DEBUG,
                '***** DHM_AccountDuplicateScheduler::execute TEST flow start skipped'
            );
            return;
        }

        Map<String, Object> inputs = new Map<String, Object>();
        Flow.Interview.DHM_Account_Duplicate_Management interview =
            new Flow.Interview.DHM_Account_Duplicate_Management(inputs);
        interview.start();

        DHM_SharedCode.OutputDebugLogText(
            LoggingLevel.DEBUG,
            '***** DHM_AccountDuplicateScheduler::execute EXIT flow=' + FLOW_API_NAME
        );
    }
}