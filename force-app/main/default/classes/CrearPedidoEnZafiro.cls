public without sharing class CrearPedidoEnZafiro {

    @InvocableMethod(label='Crear Pedido' description='Crea un pedido en Maco')
    public static List<PedidoOutput> invocableCrearPedido(List<PedidoInput> pedidos) {
        String token = ZafiroAuthManager.getToken();
        List<PedidoOutput> outputs = new List<PedidoOutput>();

        for (PedidoInput pedido : pedidos) {
            PedidoOutput output = new PedidoOutput();
            try {
                String idZafiro = sendPedido(token, pedido);
                output.Success = true;
                output.Message = 'Pedido creado correctamente.';
                output.IdZafiro = idZafiro;
            } catch (Exception e) {
                output.Success = false;
                output.Message = 'Error al crear el pedido: ' + e.getMessage();
                output.IdZafiro = null;
            }
            outputs.add(output);
        }

        return outputs;
    }

    private static String sendPedido(String token, PedidoInput input) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:IntegracionZafiro/salesforce/CrearPedido');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + token);
        request.setTimeout(120000);

        // Armar el JSON del pedido
        Map<String, Object> pedidoMap = new Map<String, Object>();
        pedidoMap.put('SalesforceID', input.PedidoId);
        pedidoMap.put('AlmacenID', input.AlmacenID);
        pedidoMap.put('Fecha', input.Fecha);
        pedidoMap.put('Cliente', input.Cliente);
        pedidoMap.put('TipoImpuesto', input.TipoImpuesto);
        pedidoMap.put('Moneda', input.Moneda);
        pedidoMap.put('Paridad', input.Paridad);
        pedidoMap.put('SubTotal', input.SubTotal);
        pedidoMap.put('TotalImpuesto', input.TotalImpuesto);
        pedidoMap.put('TipoEntregaVenta', input.TipoEntregaVenta);
        pedidoMap.put('TipoVenta', input.TipoVenta);
        pedidoMap.put('FechaPromesa', input.FechaPromesa);
        pedidoMap.put('OCCliente', input.OCCliente);

        // Armar artículos
        List<OrderItem> orderItemsDeOrden = [
            SELECT Id, UnitPrice, Quantity, Articulo__c, Impuesto__c, 
                   Impuesto_Porcentaje__c, TotalPrice, Tipo_Precio__c, Description
            FROM OrderItem
            WHERE OrderId = :input.PedidoId
            ORDER BY SortOrderProducts__c ASC NULLS LAST, CreatedDate ASC, Id ASC
        ];

        List<Map<String, Object>> articulosList = new List<Map<String, Object>>();
        for (OrderItem articulo : orderItemsDeOrden) {
            Map<String, Object> articuloMap = new Map<String, Object>();
            articuloMap.put('SalesforceID', articulo.Id);
            articuloMap.put('Articulo', articulo.Articulo__c);
            articuloMap.put('Cantidad', articulo.Quantity);
            articuloMap.put('Precio', articulo.UnitPrice);
            articuloMap.put('TipoPrecio', articulo.Tipo_Precio__c);
            articuloMap.put('ImpuestoPorcentaje', articulo.Impuesto_Porcentaje__c);
            articuloMap.put('Impuesto', articulo.Impuesto__c);
            articuloMap.put('Descripcion', articulo.Description);
            articulosList.add(articuloMap);
        }
        pedidoMap.put('Articulos', articulosList);

        // Serializar y enviar el request
        String pedidoJson = JSON.serialize(pedidoMap);
        request.setBody(pedidoJson);

        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 201) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            String pedidoIdZafiro = (String) responseBody.get('FolioPedido');

            if (!Test.isRunningTest()) {
                ZafiroAuthManager.persistToken(token);
            }

            return pedidoIdZafiro;
        } else {
            throw new CalloutException('Error al enviar pedido: ' + response.getBody());
        }
    }

    public class PedidoInput {
        @InvocableVariable(required=true)
        public Id PedidoId;
        @InvocableVariable(required=true)
        public String AlmacenID;
        @InvocableVariable(required=true)
        public String Fecha;
        @InvocableVariable(required=true)
        public Integer Cliente;
        @InvocableVariable(required=true)
        public String TipoImpuesto;
        @InvocableVariable(required=true)
        public Integer Moneda;
        @InvocableVariable(required=true)
        public Decimal Paridad;
        @InvocableVariable(required=true)
        public Decimal SubTotal;
        @InvocableVariable(required=true)
        public Decimal TotalImpuesto;
        @InvocableVariable(required=true)
        public String TipoEntregaVenta;
        @InvocableVariable(required=true)
        public String TipoVenta;
        @InvocableVariable(required=true)
        public String FechaPromesa;
        @InvocableVariable(required=true)
        public String OCCliente;
    }

    public class PedidoOutput {
        @InvocableVariable
        public Boolean Success;
        @InvocableVariable
        public String Message;
        @InvocableVariable
        public String IdZafiro;
    }
}