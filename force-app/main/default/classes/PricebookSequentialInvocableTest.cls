@isTest
public class PricebookSequentialInvocableTest {
    
    @TestSetup
    static void setupData() {
        // Crear el secuenciador de prueba
        MACO_Secuenciador__c secuenciador = new MACO_Secuenciador__c(
            Name = 'ExternalId',
            Number__c = 1000
        );
        insert secuenciador;
        
        // Asumir que el producto ya existe y está completamente configurado
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            IsActive = true,
            ProductCode = 'TEST-PROD-001'
        );
        insert testProduct;
        
        // Asumir que el pricebook estándar ya tiene todos los valores configurados
        Id standardPricebookId = Test.getStandardPricebookId();
        
        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true,
            ExternalId__c = 'STD-001',
            UseStandardPrice = false
        );
        insert standardPbe;
        
        // Crear pricebooks custom ya configurados
        List<Pricebook2> customPricebooks = new List<Pricebook2>();
        customPricebooks.add(new Pricebook2(
            Name = 'Custom Pricebook 1',
            IsActive = true,
            ExternalId__c = 'CPB-001'
        ));
        customPricebooks.add(new Pricebook2(
            Name = 'Custom Pricebook 2', 
            IsActive = true,
            ExternalId__c = 'CPB-002'
        ));
        insert customPricebooks;
        
        // Crear PricebookEntries custom - ESTOS son los que van a usar el secuenciador
        List<PricebookEntry> customEntries = new List<PricebookEntry>();
        customEntries.add(new PricebookEntry(
            Pricebook2Id = customPricebooks[0].Id,
            Product2Id = testProduct.Id,
            UnitPrice = 150.00,
            IsActive = true,
            ExternalId__c = 'TEMP-001'  // Valor temporal que será reemplazado por el secuenciador
        ));
        customEntries.add(new PricebookEntry(
            Pricebook2Id = customPricebooks[1].Id,
            Product2Id = testProduct.Id,
            UnitPrice = 200.00,
            IsActive = true,
            ExternalId__c = 'TEMP-002'  // Valor temporal que será reemplazado por el secuenciador
        ));
        insert customEntries;
    }
    
    @isTest
    static void testAsignarSecuencialSuccess() {
        // Obtener un PricebookEntry custom para probar el secuenciador
        PricebookEntry pbe = [SELECT Id, ExternalId__c FROM PricebookEntry 
                             WHERE Pricebook2.Name LIKE 'Custom Pricebook%' 
                             LIMIT 1];
        
        MACO_Secuenciador__c secuenciadorAntes = [SELECT Number__c FROM MACO_Secuenciador__c WHERE Name = 'ExternalId'];
        
        // Preparar input para el secuenciador
        PricebookSequentialInvocable.InputWrapper input = new PricebookSequentialInvocable.InputWrapper();
        input.pricebookEntryId = pbe.Id;
        
        List<PricebookSequentialInvocable.InputWrapper> inputs = new List<PricebookSequentialInvocable.InputWrapper>();
        inputs.add(input);
        
        Test.startTest();
        // Ejecutar el secuenciador sobre el custom pricebook
        List<PricebookSequentialInvocable.ResultWrapper> results = 
            PricebookSequentialInvocable.asignarSecuencial(inputs);
        Test.stopTest();
        
        // Verificar que el secuenciador funcionó correctamente
        System.assertEquals(1, results.size(), 'Debe retornar un resultado');
        System.assertEquals(true, results[0].success, 'El resultado debe ser exitoso');
        System.assertEquals(pbe.Id, results[0].pricebookEntryId, 'Debe retornar el ID correcto');
        System.assertEquals(secuenciadorAntes.Number__c + 1, results[0].assignedNumber, 'Debe incrementar el número');
        
        // Verificar que el ExternalId__c se actualizó con el número secuencial
        PricebookEntry pbeActualizado = [SELECT ExternalId__c FROM PricebookEntry WHERE Id = :pbe.Id];
        System.assertEquals(String.valueOf(Integer.valueOf(secuenciadorAntes.Number__c + 1)), 
                           pbeActualizado.ExternalId__c, 'ExternalId debe tener el nuevo número secuencial');
        
        // Verificar que el secuenciador se incrementó
        MACO_Secuenciador__c secuenciadorDespues = [SELECT Number__c FROM MACO_Secuenciador__c WHERE Name = 'ExternalId'];
        System.assertEquals(secuenciadorAntes.Number__c + 1, secuenciadorDespues.Number__c, 'Secuenciador debe incrementarse');
    }
    
    @isTest
    static void testAsignarSecuencialMultipleEntries() {
        // Obtener todos los PricebookEntries custom para probar secuenciación múltiple
        List<PricebookEntry> customPbes = [SELECT Id, ExternalId__c FROM PricebookEntry 
                                          WHERE Pricebook2.Name LIKE 'Custom Pricebook%' 
                                          ORDER BY CreatedDate];
        
        MACO_Secuenciador__c secuenciadorAntes = [SELECT Number__c FROM MACO_Secuenciador__c WHERE Name = 'ExternalId'];
        
        // Preparar inputs para múltiples PricebookEntries custom
        List<PricebookSequentialInvocable.InputWrapper> inputs = new List<PricebookSequentialInvocable.InputWrapper>();
        for (PricebookEntry pbe : customPbes) {
            PricebookSequentialInvocable.InputWrapper input = new PricebookSequentialInvocable.InputWrapper();
            input.pricebookEntryId = pbe.Id;
            inputs.add(input);
        }
        
        Test.startTest();
        // Ejecutar el secuenciador sobre múltiples custom pricebooks
        List<PricebookSequentialInvocable.ResultWrapper> results = 
            PricebookSequentialInvocable.asignarSecuencial(inputs);
        Test.stopTest();
        
        // Verificar resultados múltiples
        System.assertEquals(2, results.size(), 'Debe retornar 2 resultados');
        
        for (Integer i = 0; i < results.size(); i++) {
            System.assertEquals(true, results[i].success, 'Todos los resultados deben ser exitosos');
            System.assertEquals(secuenciadorAntes.Number__c + i + 1, results[i].assignedNumber, 
                               'Los números deben ser secuenciales');
        }
        
        // Verificar que el secuenciador se incrementó correctamente
        MACO_Secuenciador__c secuenciadorDespues = [SELECT Number__c FROM MACO_Secuenciador__c WHERE Name = 'ExternalId'];
        System.assertEquals(secuenciadorAntes.Number__c + 2, secuenciadorDespues.Number__c, 
                           'Secuenciador debe incrementarse en 2');
        
        // Verificar que los ExternalId__c se actualizaron correctamente
        List<PricebookEntry> pbesActualizados = [SELECT Id, ExternalId__c FROM PricebookEntry 
                                                WHERE Id IN :customPbes 
                                                ORDER BY CreatedDate];
        
        for (Integer i = 0; i < pbesActualizados.size(); i++) {
            String expectedValue = String.valueOf(Integer.valueOf(secuenciadorAntes.Number__c + i + 1));
            System.assertEquals(expectedValue, pbesActualizados[i].ExternalId__c, 
                               'ExternalId debe tener el número secuencial correcto');
        }
    }
    
    @isTest
    static void testAsignarSecuencialInputNull() {
        Test.startTest();
        List<PricebookSequentialInvocable.ResultWrapper> results = 
            PricebookSequentialInvocable.asignarSecuencial(null);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Debe retornar un resultado de error');
        System.assertEquals(false, results[0].success, 'El resultado debe ser fallido');
        System.assertEquals('No se recibieron datos de entrada', results[0].errorMessage);
    }
    
    @isTest
    static void testAsignarSecuencialInputEmpty() {
        List<PricebookSequentialInvocable.InputWrapper> emptyInputs = 
            new List<PricebookSequentialInvocable.InputWrapper>();
        
        Test.startTest();
        List<PricebookSequentialInvocable.ResultWrapper> results = 
            PricebookSequentialInvocable.asignarSecuencial(emptyInputs);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Debe retornar un resultado de error');
        System.assertEquals(false, results[0].success, 'El resultado debe ser fallido');
        System.assertEquals('No se recibieron datos de entrada', results[0].errorMessage);
    }
    
    @isTest
    static void testAsignarSecuencialSecuenciadorNoExiste() {
        // Eliminar el secuenciador para probar manejo de error
        delete [SELECT Id FROM MACO_Secuenciador__c WHERE Name = 'ExternalId'];
        
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry 
                             WHERE Pricebook2.Name LIKE 'Custom Pricebook%' 
                             LIMIT 1];
        
        PricebookSequentialInvocable.InputWrapper input = new PricebookSequentialInvocable.InputWrapper();
        input.pricebookEntryId = pbe.Id;
        
        List<PricebookSequentialInvocable.InputWrapper> inputs = 
            new List<PricebookSequentialInvocable.InputWrapper>{input};
        
        Test.startTest();
        List<PricebookSequentialInvocable.ResultWrapper> results = 
            PricebookSequentialInvocable.asignarSecuencial(inputs);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Debe retornar un resultado de error');
        System.assertEquals(false, results[0].success, 'El resultado debe ser fallido');
        System.assertEquals('No se encontró secuenciador con Name = ExternalId', results[0].errorMessage);
    }
    
    @isTest
    static void testAsignarSecuencialPricebookEntryInvalido() {
        PricebookSequentialInvocable.InputWrapper input = new PricebookSequentialInvocable.InputWrapper();
        input.pricebookEntryId = '01uXXXXXXXXXXXX'; // ID inválido
        
        List<PricebookSequentialInvocable.InputWrapper> inputs = 
            new List<PricebookSequentialInvocable.InputWrapper>{input};
        
        Test.startTest();
        List<PricebookSequentialInvocable.ResultWrapper> results = 
            PricebookSequentialInvocable.asignarSecuencial(inputs);
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Debe retornar un resultado de error');
        System.assertEquals(false, results[0].success, 'El resultado debe ser fallido');
        System.assert(results[0].errorMessage.startsWith('Error:'), 'Debe retornar mensaje de error');
    }
    
    @isTest
    static void testInputWrapperDefaults() {
        PricebookSequentialInvocable.InputWrapper input = new PricebookSequentialInvocable.InputWrapper();
        System.assertEquals('ExternalId', input.secuenciadorName, 
                           'secuenciadorName debe tener valor por defecto');
    }
    
    @isTest
    static void testResultWrapperInitialization() {
        PricebookSequentialInvocable.ResultWrapper result = new PricebookSequentialInvocable.ResultWrapper();
        
        System.assertEquals(null, result.success, 'success debe ser null inicialmente');
        System.assertEquals(null, result.assignedNumber, 'assignedNumber debe ser null inicialmente');
        System.assertEquals(null, result.pricebookEntryId, 'pricebookEntryId debe ser null inicialmente');
        System.assertEquals(null, result.errorMessage, 'errorMessage debe ser null inicialmente');
    }
}