public class VerificarOrdenesEntregaZafiro {

    @InvocableMethod(label='Verificar Ordenes de Entrega' description='Consulta a Zafiro si el pedido tiene ordenes de entrega')
    public static List<Integer> verificarOrdenes(List<VerificacionInput> inputs) {
        String token = ZafiroAuthManager.getToken();
        List<Integer> resultados = new List<Integer>();

        Http http = new Http();

        for (VerificacionInput input : inputs) {
            if (input.zfPedidoId == null || input.almacenId == null) {
                // Si no tiene ID de Zafiro o Almacen, devolvemos 0 asumiendo que no hay ordenes de entrega validas
                resultados.add(0);
                continue;
            }

            // Consultar el codigo real de Zafiro (Code__c) para este Almacen en Salesforce
            String zafiroAlmacenCode = '';
            try {
                Warehouse__c wh = [SELECT Code__c FROM Warehouse__c WHERE Id = :input.almacenId LIMIT 1];
                zafiroAlmacenCode = wh.Code__c;
            } catch(Exception e) {
                System.debug('Error obteniendo Almacen: ' + e.getMessage());
                resultados.add(0);
                continue;
            }

            HttpRequest request = new HttpRequest();
            // Endpoint: /api/pedidos/TotalOrdenesEntregaEmbarque?PedidoID={ID}&AlmacenID={Almacen}
            String endpoint = 'callout:IntegracionZafiro/pedidos/TotalOrdenesEntregaEmbarque'
                            + '?PedidoID=' + input.zfPedidoId
                            + '&AlmacenID=' + zafiroAlmacenCode;
            
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Authorization', 'Bearer ' + token);
            request.setHeader('Content-Type', 'application/json');

            try {
                HttpResponse response = http.send(request);
                if (response.getStatusCode() == 200) {
                    // El endpoint dice que la respuesta incluye la cantidad de ordenes.
                    // Puede ser un JSON objeto o un entero directo.
                    String body = response.getBody();
                    Integer cantidad = 0;
                    
                    if(body.trim().startsWith('{')) {
                        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(body);
                        for(String key : respMap.keySet()) {
                            if(respMap.get(key) != null && respMap.get(key) instanceof Integer) {
                                cantidad = (Integer) respMap.get(key);
                                break;
                            }
                        }
                    } else if (body.isNumeric()) {
                        cantidad = Integer.valueOf(body);
                    }
                    resultados.add(cantidad);
                } else {
                    System.debug('Error al verificar ordenes de entrega: ' + response.getBody());
                    resultados.add(0);
                }
            } catch (Exception e) {
                System.debug('Excepcion HTTP al verificar ordenes de entrega: ' + e.getMessage());
                resultados.add(0);
            }
        }
        
        ZafiroAuthManager.persistToken(token);
        return resultados;
    }

    public class VerificacionInput {
        @InvocableVariable(required=true description='ID del pedido en Zafiro')
        public String zfPedidoId;

        @InvocableVariable(required=true description='ID del almacen de la orden (Salesforce ID)')
        public String almacenId;
    }
}
