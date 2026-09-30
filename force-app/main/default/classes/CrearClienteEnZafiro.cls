public class CrearClienteEnZafiro {

    @InvocableMethod(label='Crear Cliente' description='Crea un cliente en Maco')
    public static List<ClienteOutput> invocableCrearCliente(List<ClienteInput> clientes) {
        String token = ZafiroAuthManager.getToken();
        List<ClienteOutput> outputs = new List<ClienteOutput>();

        for (ClienteInput cliente : clientes) {
            ClienteOutput output = new ClienteOutput();
            try {
                sendCliente(token, cliente);
                output.Success = true;
                output.Message = 'Cliente creado correctamente.';
            } catch (Exception e) {
                output.Success = false;
                output.Message = 'Error al crear el cliente: ' + e.getMessage();
            }
            outputs.add(output);
        }

        return outputs;
    }

    private static void sendCliente(String token, ClienteInput input) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:IntegracionZafiro/salesforce/CrearCliente');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + token);

        Map<String, Object> clienteMap = new Map<String, Object>();
        clienteMap.put('SalesforceID', input.SalesforceID);
        clienteMap.put('Nombre', input.Nombre);
        clienteMap.put('Direccion', input.Direccion);
        clienteMap.put('Ciudad', input.Ciudad);
        clienteMap.put('Estado', input.Estado);
        clienteMap.put('Cp', input.Cp);
        clienteMap.put('Pais', input.Pais);
        clienteMap.put('Email', input.Email);
        clienteMap.put('WebSite', input.WebSite);
        clienteMap.put('Observaciones', input.Observaciones);
        clienteMap.put('Rfc', input.Rfc);

        String clienteJson = JSON.serialize(clienteMap);
        request.setBody(clienteJson);

        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 201) {
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            System.debug(responseBody);

            Integer clienteId = (Integer) responseBody.get('ClienteID');

            Account accountToUpdate = new Account(
                Id = input.SalesforceID,
                ZF_Cliente_ID__c = clienteId
            );
            update accountToUpdate;

            ZafiroAuthManager.persistToken(token);
        } else {
            throw new CalloutException('Error al enviar cliente: ' + response.getBody());
        }
    }

    public class ClienteInput {
        @InvocableVariable(required=true)
        public Id SalesforceID;
        @InvocableVariable(required=true)
        public String Nombre;
        @InvocableVariable(required=true)
        public String Direccion;
        @InvocableVariable(required=true)
        public String Ciudad;
        @InvocableVariable(required=true)
        public String Estado;
        @InvocableVariable(required=true)
        public String Cp;
        @InvocableVariable(required=true)
        public String Pais;
        @InvocableVariable(required=true)
        public String Email;
        @InvocableVariable(required=true)
        public String WebSite;
        @InvocableVariable(required=true)
        public String Observaciones;
        @InvocableVariable(required=true)
        public String Rfc;
    }

    public class ClienteOutput {
        @InvocableVariable
        public Boolean Success;
        @InvocableVariable
        public String Message;
    }
}