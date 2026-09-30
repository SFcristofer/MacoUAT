@isTest
private class ObtenerAntiguedadSaldosTest {

    @testSetup
    static void setupData() {
        // Cuenta con ZF_Cliente_ID__c correcto (Decimal)
        Account acc2 = new Account(
            Name = 'Cuenta con Zafiro ID',
            RFC__c = 'XAXX010101000',
            ZF_Cliente_ID__c = Decimal.valueOf('123456')
        );
        insert acc2;
    }

    @isTest
    static void testObtenerAntiguedadSaldo_Exitoso() {
        // Mockeamos la respuesta del callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Account acc = [SELECT Id FROM Account WHERE Name = 'Cuenta con Zafiro ID' LIMIT 1];

        Test.startTest();
        List<Object> result = ObtenerAntiguedadSaldos.obtenerAntiguedadSaldo(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Debe retornar una lista');
        System.assert(result.size() > 0, 'Debe haber resultados en la respuesta del mock');
    }
}