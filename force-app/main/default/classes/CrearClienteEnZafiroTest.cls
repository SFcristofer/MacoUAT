@isTest
private class CrearClienteEnZafiroTest {
    @isTest
    static void testCrearClienteExitoso() {

       Account newAcc = new Account(
            Name='Cliente test',
            RFC__c = 'XAXX010101000' // Campo obligatorio corregido
        );
        Test.startTest();

        // Simulación de respuesta HTTP 400
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        // Creación de datos de entrada
        CrearClienteEnZafiro.ClienteInput input = new CrearClienteEnZafiro.ClienteInput();
        input.SalesforceID = newAcc.Id;
        input.Nombre = 'Cliente Test';
        input.Direccion = 'Calle Falsa 123';
        input.Ciudad = 'Ciudad Test';
        input.Estado = 'Estado Test';
        input.Cp = '12345';
        input.Pais = 'Pais Test';
        input.Email = 'cliente@test.com';
        input.WebSite = 'http://test.com';
        input.Observaciones = 'Observaciones';
        input.Rfc = 'RFC123456';
        
        List<CrearClienteEnZafiro.ClienteInput> inputs = new List<CrearClienteEnZafiro.ClienteInput>{input};
        
        // Llamada al método invocable
        List<CrearClienteEnZafiro.ClienteOutput> outputs = CrearClienteEnZafiro.invocableCrearCliente(inputs);
        
        Test.stopTest();
        
        // Validaciones
        System.assertEquals(1, outputs.size(), 'Debe haber un resultado');
    }
    
    @isTest
    static void testCrearClienteError() {

Account newAcc = new Account(
            Name='Cliente test',
            RFC__c = 'XAXX010101000' // Campo obligatorio corregido
        );
        insert newAcc;      

        Test.startTest();
        
        // Simulación de respuesta HTTP 400
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());  
        
        CrearClienteEnZafiro.ClienteInput input = new CrearClienteEnZafiro.ClienteInput();
        input.SalesforceID = newAcc.Id;
        input.Nombre = 'Cliente Fallido';
        input.Direccion = 'Calle Falsa 456';
        input.Ciudad = 'Ciudad Fallida';
        input.Estado = 'Estado Fallido';
        input.Cp = '54321';
        input.Pais = 'Pais Fallido';
        input.Email = 'fallo@test.com';
        input.WebSite = 'http://fallo.com';
        input.Observaciones = 'Observaciones de fallo';
        input.Rfc = 'RFC654321';
        
        List<CrearClienteEnZafiro.ClienteInput> inputs = new List<CrearClienteEnZafiro.ClienteInput>{input};
        
        try {
            // Llamada al método
            List<CrearClienteEnZafiro.ClienteOutput> outputs = CrearClienteEnZafiro.invocableCrearCliente(inputs);
        } catch (System.CalloutException e) {
            // Validaciones
            System.assertEquals('Error authenticating: Error en la solicitud', e.getMessage());
        }
        
        Test.stopTest();
    
    }
}