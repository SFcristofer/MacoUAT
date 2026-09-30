public class DummyClass {
    // Clase para pipeline CI/CD
    public class Input {
        @InvocableVariable(label='Input Message')
        public String inputMessage;
    }

    public class Output {
        @InvocableVariable(label='Output Message')
        public String outputMessage;
    }

    @InvocableMethod(label='Do Nothing Method')
    public static List<Output> invoke(List<Input> inputs) {
        List<Output> results = new List<Output>();
        for (Input i : inputs) {
            Output o = new Output();
            o.outputMessage = 'Success';
            results.add(o);
        }

        return results;
    }
}