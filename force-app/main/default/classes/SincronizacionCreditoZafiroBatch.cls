public class SincronizacionCreditoZafiroBatch implements Database.Batchable<sObject>, Database.AllowsCallouts {
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Obtenemos unicamente las cuentas que tengan un ID de Zafiro
        return Database.getQueryLocator([
            SELECT Id, ZF_Cliente_ID__c 
            FROM Account 
            WHERE ZF_Cliente_ID__c != null
        ]);
    }

    public void execute(Database.BatchableContext BC, List<Account> scope) {
        String token = ZafiroAuthManager.getToken();
        List<Account> accountsToUpdate = new List<Account>();

        Http http = new Http();

        for (Account acc : scope) {
            HttpRequest request = new HttpRequest();
            // Construye el endpoint con el ID de cliente de Zafiro
            String endpoint = 'callout:IntegracionZafiro/clientes/InformacionCredito/' + acc.ZF_Cliente_ID__c;
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('Authorization', 'Bearer ' + token);
            request.setHeader('Content-Type', 'application/json');

            try {
                HttpResponse response = http.send(request);
                if (response.getStatusCode() == 200) {
                    Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    
                    // Asegurarse de que los nombres de llave coincidan con los que devuelve realmente el API.
                    // Si el API usa camelCase o PascalCase, ajustar aqui:
                    Decimal limite = getDecimalValue(respMap, 'LimiteCredito');
                    Decimal saldo = getDecimalValue(respMap, 'Saldo');
                    Decimal disponible = getDecimalValue(respMap, 'CreditoDisponible');
                    String plazo = getStringValue(respMap, 'PlazoPago');

                    acc.Limite_de_Credito__c = limite;
                    acc.Saldo__c = saldo;
                    acc.Credito_Disponible__c = disponible;
                    acc.Plazo_de_Pago__c = plazo;

                    accountsToUpdate.add(acc);
                } else {
                    System.debug('Error al obtener credito para cliente ' + acc.ZF_Cliente_ID__c + ': ' + response.getBody());
                }
            } catch (Exception e) {
                System.debug('Excepcion HTTP al obtener credito: ' + e.getMessage());
            }
        }

        if (!accountsToUpdate.isEmpty()) {
            // Actualizamos bloqueos para prevenir errores
            update accountsToUpdate;
        }
        
        ZafiroAuthManager.persistToken(token);
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('Batch de sincronizacion de credito de Zafiro completado.');
    }

    // Funciones auxiliares para manejo seguro de tipos
    private Decimal getDecimalValue(Map<String, Object> mapData, String key) {
        if(mapData.containsKey(key) && mapData.get(key) != null) {
            try {
                return Decimal.valueOf(String.valueOf(mapData.get(key)));
            } catch(Exception e) {
                return null;
            }
        }
        return null;
    }

    private String getStringValue(Map<String, Object> mapData, String key) {
        if(mapData.containsKey(key) && mapData.get(key) != null) {
            return String.valueOf(mapData.get(key));
        }
        return null;
    }
}
