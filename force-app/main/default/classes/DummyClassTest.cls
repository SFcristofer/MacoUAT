@IsTest
private class DummyClassTest {
    // Clase para pipeline CI/CD
    @IsTest
    static void testInvoke() {
        DummyClass.Input input = new DummyClass.Input();
        input.inputMessage = 'Test';

        List<DummyClass.Input> inputList = new List<DummyClass.Input>{input};
        List<DummyClass.Output> result = DummyClass.invoke(inputList);

        System.assertEquals(1, result.size());
        System.assertEquals('Success', result[0].outputMessage);
    }
}