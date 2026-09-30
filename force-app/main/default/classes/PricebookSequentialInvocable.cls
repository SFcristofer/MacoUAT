// INVOCABLE METHOD para usar desde Flow
public class PricebookSequentialInvocable {
    
    @InvocableMethod(label='Asignar Secuencial a PricebookEntry' 
                     description='Asigna número secuencial desde MACO_Secuenciador__c')
    public static List<ResultWrapper> asignarSecuencial(List<InputWrapper> inputs) {
        
        List<ResultWrapper> results = new List<ResultWrapper>();
        
        if (inputs == null || inputs.isEmpty()) {
            ResultWrapper result = new ResultWrapper();
            result.success = false;
            result.errorMessage = 'No se recibieron datos de entrada';
            results.add(result);
            return results;
        }
        
        try {
            // Obtener el secuenciador
            List<MACO_Secuenciador__c> secuenciadores = [
                SELECT Id, Name, Number__c 
                FROM MACO_Secuenciador__c 
                WHERE Name = 'ExternalId' 
                LIMIT 1
            ];
            
            if (secuenciadores.isEmpty()) {
                ResultWrapper result = new ResultWrapper();
                result.success = false;
                result.errorMessage = 'No se encontró secuenciador con Name = ExternalId';
                results.add(result);
                return results;
            }
            
            MACO_Secuenciador__c secuenciador = secuenciadores[0];
            
            // Procesar cada PricebookEntry
            List<PricebookEntry> pricesToUpdate = new List<PricebookEntry>();
            
            for (InputWrapper input : inputs) {
                // Calcular próximo número
                secuenciador.Number__c += 1;
                
                // Preparar actualización del PricebookEntry
                PricebookEntry pbeToUpdate = new PricebookEntry();
                pbeToUpdate.Id = input.pricebookEntryId;
                pbeToUpdate.ExternalId__c = String.valueOf(secuenciador.Number__c.intValue());
                pricesToUpdate.add(pbeToUpdate);
                
                // Preparar resultado
                ResultWrapper result = new ResultWrapper();
                result.success = true;
                result.assignedNumber = secuenciador.Number__c;
                result.pricebookEntryId = input.pricebookEntryId;
                results.add(result);
            }
            
            // Actualizar PricebookEntries
            if (!pricesToUpdate.isEmpty()) {
                update pricesToUpdate;
            }
            
            // Actualizar secuenciador
            update secuenciador;
            
        } catch (Exception e) {
            ResultWrapper result = new ResultWrapper();
            result.success = false;
            result.errorMessage = 'Error: ' + e.getMessage();
            results.add(result);
        }
        
        return results;
    }
    
    // Wrapper para datos de entrada
    public class InputWrapper {
        @InvocableVariable(label='PricebookEntry ID' required=true)
        public String pricebookEntryId;
        
        @InvocableVariable(label='Nombre Secuenciador' required=false)
        public String secuenciadorName = 'ExternalId';
    }
    
    // Wrapper para resultados
    public class ResultWrapper {
        @InvocableVariable(label='Éxito')
        public Boolean success;
        
        @InvocableVariable(label='Número Asignado')
        public Decimal assignedNumber;
        
        @InvocableVariable(label='PricebookEntry ID')
        public String pricebookEntryId;
        
        @InvocableVariable(label='Mensaje de Error')
        public String errorMessage;
    }
}