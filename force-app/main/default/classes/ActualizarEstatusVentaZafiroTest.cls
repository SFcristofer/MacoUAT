// Clase de test principal
@isTest
private class ActualizarEstatusVentaZafiroTest {

    @isTest
    static void testActualizarEstatus_exitoso() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Account acc = new Account(Name = 'Test Account', RFC__c = 'RFC123456');
        insert acc;

        ActualizarEstatusVentaZafiro.EstatusInput input = new ActualizarEstatusVentaZafiro.EstatusInput();
        input.SalesforceID = acc.Id;
        input.Estatus = 'Procesado';

        List<ActualizarEstatusVentaZafiro.EstatusInput> inputs = new List<ActualizarEstatusVentaZafiro.EstatusInput>{ input };

        Test.startTest();
        List<ActualizarEstatusVentaZafiro.EstatusOutput> resultados = ActualizarEstatusVentaZafiro.invocableActualizarEstatus(inputs);
        Test.stopTest();

        System.assertEquals(1, resultados.size());
        System.assertEquals(true, resultados[0].Success);
        // System.assertEquals(true, resultados[0].Success); testing purposes
    }
}