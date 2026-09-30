public class ObtenerAntiguedadSaldos {
    private static final String NAMED_CREDENTIAL = 'callout:IntegracionZafiro';
    
    @AuraEnabled(cacheable=false)
    public static List<Object> obtenerAntiguedadSaldo(String clienteId) {
        if (String.isBlank(clienteId)) {
            throw new AuraHandledException('El parámetro clienteId no puede estar vacío.');
        }
        Decimal zafiroId = [SELECT Id, ZF_Cliente_ID__c FROM Account WHERE Id=:clienteId LIMIT 1].ZF_Cliente_ID__c;
        if (zafiroId==null) {
            throw new AuraHandledException('Esta cuenta no posee un Id de cliente en Zafiro');
        }
        String zafiroIdString = String.valueOf(zafiroId);
        String endpoint = NAMED_CREDENTIAL + '/salesforce/ObtenerAntiguedadSaldos?ClienteID=' + EncodingUtil.urlEncode(zafiroIdString, 'UTF-8');

        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(15000);
        
        String token = ZafiroAuthManager.getToken();
        request.setHeader('Authorization', 'Bearer ' + token);

        Http http = new Http();
        HttpResponse response;
        try {
            response = http.send(request);
        } catch (Exception e) {
            throw new AuraHandledException('Error al realizar la llamada al servicio: ' + e.getMessage());
        }

        if (response.getStatusCode() == 200) {
            if(!Test.IsRunningTest()) ZafiroAuthManager.persistToken(token);
            System.debug(JSON.deserializeUntyped(response.getBody()));
            return (List<Object>) JSON.deserializeUntyped(response.getBody());
        } else {
            throw new AuraHandledException('Error en la llamada al servicio: ' + response.getStatus() + ' - ' + response.getBody());
        }
    }
}