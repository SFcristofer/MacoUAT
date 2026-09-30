@isTest
private class CrearPedidoEnZafiroTest {
    @testSetup
    static void setup() {
        TestDataFactory.crearTodoLoNecesario();
    }

    @isTest
    static void testCrearPedidoExitoso() {
        Test.startTest();

        // Mock del Callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Verificar que la Orden tiene el estado "DRaft"
        Order ord = [SELECT Id, Status FROM Order LIMIT 1];
        System.debug('Estado de la orden: ' + ord.Status);
        System.assertEquals('Draft', ord.Status, 'La orden debe estar en estado Draft antes de crear un pedido.');

        // Creación de datos de entrada
        CrearPedidoEnZafiro.PedidoInput input = new CrearPedidoEnZafiro.PedidoInput();
        input.PedidoId = ord.Id;
        input.AlmacenID = '01';
        input.Fecha = String.valueOf(Date.today()); 
        input.Cliente = 1;
        input.TipoImpuesto = 'impuesto';
        input.Moneda = 1;
        input.Paridad = 1;
        input.SubTotal = 1;
        input.TotalImpuesto = 1;
        input.TipoEntregaVenta = 'venta';
        input.TipoVenta = 'venta';
        input.FechaPromesa = String.valueOf(Date.today());  
        input.OCCliente = '00001';
        
        List<CrearPedidoEnZafiro.PedidoInput> inputs = new List<CrearPedidoEnZafiro.PedidoInput>{input};
        
        // Llamada al método invocable
        List<CrearPedidoEnZafiro.PedidoOutput> outputs = CrearPedidoEnZafiro.invocableCrearPedido(inputs);
        
        Test.stopTest();
        
        // Validaciones
        System.assertEquals(1, outputs.size(), 'Debe haber un resultado');
    }
}