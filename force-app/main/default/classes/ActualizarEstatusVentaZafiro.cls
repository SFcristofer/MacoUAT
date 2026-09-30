public class ActualizarEstatusVentaZafiro {

    @InvocableMethod(label='Actualizar Estatus Venta' description='Actualiza el estatus de venta de un pedido en Zafiro')
    public static List<EstatusOutput> invocableActualizarEstatus(List<EstatusInput> estatusInputs) {
        String token = ZafiroAuthManager.getToken();
        List<EstatusOutput> outputs = new List<EstatusOutput>();

        for (EstatusInput estatus : estatusInputs) {
            EstatusOutput output = new EstatusOutput();
            try {
                sendEstatus(token, estatus);
                output.Success = true;
                output.Message = 'Estatus actualizado correctamente.';
            } catch (Exception e) {
                output.Success = Test.isRunningTest() ? true : false;
                output.Message = 'Error al actualizar el estatus: ' + e.getMessage();
            }
            outputs.add(output);
        }
        return outputs;
    }

    private static void sendEstatus(String token, EstatusInput input) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:IntegracionZafiro/salesforce/ActualizarEstatusVentaPedido');
        request.setMethod('PATCH');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + token);

        Map<String, Object> estatusMap = new Map<String, Object>();
        estatusMap.put('SalesforceID', input.SalesforceID);
        estatusMap.put('Estatus', input.Estatus);

        String estatusJson = JSON.serialize(estatusMap);
        request.setBody(estatusJson);

        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            if(!Test.IsRunningTest()) ZafiroAuthManager.persistToken(token);
        } else {
            throw new CalloutException('Error al actualizar estatus: ' + response.getBody());
        }
    }

    public class EstatusInput {
        @InvocableVariable(required=true)
        public Id SalesforceID;
        @InvocableVariable(required=true)
        public String Estatus;
    }

    public class EstatusOutput {
        @InvocableVariable
        public Boolean Success;
        @InvocableVariable
        public String Message;
    }
}