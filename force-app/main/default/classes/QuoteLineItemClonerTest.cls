@isTest
private class QuoteLineItemClonerTest {
    
    // ========================================
    // DEBUG HELPER METHOD
    // ========================================
    
    @isTest
    static void debugDataSetup() {
        // Verificar que los datos básicos se crearon correctamente
        System.debug('=== DEBUG DATA SETUP ===');
        
        List<Account> accounts = [SELECT Id, Name FROM Account];
        System.debug('Accounts creadas: ' + accounts.size());
        
        List<Opportunity> opps = [SELECT Id, Name FROM Opportunity];
        System.debug('Opportunities creadas: ' + opps.size());
        
        List<Product2> products = [SELECT Id, Name, IsActive FROM Product2];
        System.debug('Products creados: ' + products.size());
        
        List<Pricebook2> pricebooks = [SELECT Id, Name, IsActive, IsStandard FROM Pricebook2];
        System.debug('Pricebooks creados: ' + pricebooks.size());
        for(Pricebook2 pb : pricebooks) {
            System.debug('PB: ' + pb.Name + ', IsStandard: ' + pb.IsStandard + ', IsActive: ' + pb.IsActive);
        }
        
        List<PricebookEntry> pbes = [SELECT Id, Pricebook2Id, Product2Id, UnitPrice, IsActive FROM PricebookEntry];
        System.debug('PricebookEntries creados: ' + pbes.size());
        
        List<Quote> quotes = [SELECT Id, Name, Pricebook2Id FROM Quote];
        System.debug('Quotes creados: ' + quotes.size());
        for(Quote q : quotes) {
            System.debug('Quote: ' + q.Name + ', PB: ' + q.Pricebook2Id);
        }
        
        List<QuoteLineItem> qlis = [SELECT Id, QuoteId, Product2Id, Quantity FROM QuoteLineItem];
        System.debug('QLIs creados: ' + qlis.size());
        
        // Verificar que existe Standard Pricebook
        List<Pricebook2> standardPBs = [SELECT Id FROM Pricebook2 WHERE IsStandard = true];
        System.debug('Standard Pricebooks encontrados: ' + standardPBs.size());
        
        System.assertEquals(1, accounts.size(), 'Debe haber 1 account');
        System.assertEquals(1, opps.size(), 'Debe haber 1 opportunity');
        System.assertEquals(3, products.size(), 'Deben haber 3 products');
    }
    
    // ========================================
    // TEST DATA SETUP
    // ========================================
    
    @TestSetup
    static void makeData() {
        // 1. Crear Account con RFC requerido
        Account testAccount = new Account(
            Name = 'Test Account',
            RFC__c = 'TST080513CIA'  // Formato similar a tu ejemplo PPS080513CIA
        );
        insert testAccount;
        
        // 2. Crear Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;
        
        // 3. Crear productos
        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Product A', IsActive = true),
            new Product2(Name = 'Product B', IsActive = true),
            new Product2(Name = 'Product C', IsActive = true)
        };
        insert products;
        
        // 4. Obtener Standard Pricebook - CRITICAL FIX
        Id standardPBId = Test.getStandardPricebookId();
        
        // 5. Crear Custom Pricebooks
        Pricebook2 customPB1 = new Pricebook2(
            Name = 'Custom Pricebook 1',
            ExternalId__c = '01010101',
            IsActive = true
        );
        insert customPB1;
        
        Pricebook2 customPB2 = new Pricebook2(
            Name = 'Custom Pricebook 2', 
           	ExternalId__c = '01010100',
            IsActive = true
        );
        insert customPB2;
        
        // 6. Crear PricebookEntries para Standard Pricebook (requerido)
        List<PricebookEntry> standardPBEs = new List<PricebookEntry>();
        for (Product2 prod : products) {
            standardPBEs.add(new PricebookEntry(
                Pricebook2Id = standardPBId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true
            ));
        }
        insert standardPBEs;
        
        // 7. Crear PricebookEntries para Custom Pricebook 1
        List<PricebookEntry> customPB1Es = new List<PricebookEntry>();
        for (Product2 prod : products) {
            customPB1Es.add(new PricebookEntry(
                Pricebook2Id = customPB1.Id,
                Product2Id = prod.Id,
                UnitPrice = 150,
                IsActive = true
            ));
        }
        insert customPB1Es;
        
        // 8. Crear PricebookEntries para Custom Pricebook 2 (solo 2 productos)
        List<PricebookEntry> customPB2Es = new List<PricebookEntry>();
        for (Integer i = 0; i < 2; i++) {
            customPB2Es.add(new PricebookEntry(
                Pricebook2Id = customPB2.Id,
                Product2Id = products[i].Id,
                UnitPrice = 200,
                IsActive = true
            ));
        }
        insert customPB2Es;
        
        // 9. Crear Quotes
        Quote originalQuote = new Quote(
            Name = 'Original Quote',
            OpportunityId = testOpp.Id,
            Pricebook2Id = customPB1.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today() + 5
        );
        insert originalQuote;
        
        Quote newQuote = new Quote(
            Name = 'New Quote',
            OpportunityId = testOpp.Id,
            Pricebook2Id = customPB2.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today() + 5
        );
        insert newQuote;
        
        // 10. Crear OpportunityLineItems para el Standard Pricebook (requerido antes de custom)
        testOpp.Pricebook2Id = standardPBId;
        update testOpp;
        
        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        for (PricebookEntry pbe : standardPBEs) {
            olis.add(new OpportunityLineItem(
                OpportunityId = testOpp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 100
            ));
        }
        insert olis;
        
        // 11. Crear QuoteLineItems en el presupuesto original
        List<QuoteLineItem> originalQLIs = new List<QuoteLineItem>();
        Integer counter = 0;
        for (PricebookEntry pbe : customPB1Es) {
            originalQLIs.add(new QuoteLineItem(
                QuoteId = originalQuote.Id,
                PricebookEntryId = pbe.Id,
                Product2Id = pbe.Product2Id,
                Quantity = 5 + counter,
                UnitPrice = 150,
                Discount = 10 + (counter * 5),
                Description = 'Test Product ' + (counter + 1),
                Location__c = 'Location ' + (counter + 1),
                Classification__c = 'Class ' + (counter + 1),
                Stock__c = 100 + (counter * 10),
                Commited__c = 50 + (counter * 5),
                Unity__c = 'PCS',  // Agregar Unity si es requerido
                aies__CustomSortOrder__c = counter + 1,
                ToBeDelivered__c = 25 + counter,
                ToBeSupplied__c = 75 + counter,
                OpportunityLineItemId = olis[counter].Id
            ));
            counter++;
        }
        insert originalQLIs;
    }
    
    // ========================================
    // SUCCESS SCENARIOS
    // ========================================
    
    @isTest
    static void testSuccessfulCloning() {
        System.debug('=== STARTING testSuccessfulCloning ===');
        
        // Given
        Quote originalQuote = [SELECT Id FROM Quote WHERE Name = 'Original Quote' LIMIT 1];
        Quote newQuote = [SELECT Id FROM Quote WHERE Name = 'New Quote' LIMIT 1];
        
        System.debug('Original Quote ID: ' + originalQuote.Id);
        System.debug('New Quote ID: ' + newQuote.Id);
        
        List<QuoteLineItem> originalQLIs = [
            SELECT Id, Product2Id, Quantity, Discount, Description
            FROM QuoteLineItem 
            WHERE QuoteId = :originalQuote.Id
        ];
        
        System.debug('QLIs encontrados en original: ' + originalQLIs.size());
        System.assertEquals(3, originalQLIs.size(), 'Deberían existir 3 QLIs originales');
        
        QuoteLineItemCloner.CloneQLIRequest request = new QuoteLineItemCloner.CloneQLIRequest();
        request.originalQuoteId = originalQuote.Id;
        request.newQuoteId = newQuote.Id;
        
        // When
        Test.startTest();
        try {
            QuoteLineItemCloner.cloneQuoteLineItems(new List<QuoteLineItemCloner.CloneQLIRequest>{request});
            System.debug('Cloning completed successfully');
        } catch (Exception e) {
            System.debug('ERROR during cloning: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw e;
        }
        Test.stopTest();
        
        // Then
        List<QuoteLineItem> newQLIs = [
            SELECT Id, Product2Id, Quantity, UnitPrice, Discount, Description,
                   Location__c, Classification__c, Stock__c, Commited__c,
                   aies__CustomSortOrder__c, ToBeDelivered__c, ToBeSupplied__c,
                   OpportunityLineItemId, PricebookEntryId
            FROM QuoteLineItem 
            WHERE QuoteId = :newQuote.Id
        ];
        
        System.debug('QLIs creados en nuevo quote: ' + newQLIs.size());
        
        // Solo 2 productos deberían clonarse (Product A y B están en ambos Pricebooks)
        System.assertEquals(2, newQLIs.size(), 'Deberían clonarse 2 QLIs');
        
        // Verificar que los campos se copiaron correctamente
        for (QuoteLineItem newQLI : newQLIs) {
            System.assertNotEquals(null, newQLI.Product2Id, 'Product2Id debe estar presente');
            System.assertNotEquals(null, newQLI.PricebookEntryId, 'PricebookEntryId debe estar presente');
            System.assertEquals(200, newQLI.UnitPrice, 'UnitPrice debe ser del nuevo Pricebook (200)');
            System.assertNotEquals(null, newQLI.Location__c, 'Location__c debe copiarse');
            System.assertNotEquals(null, newQLI.Classification__c, 'Classification__c debe copiarse');
        }
    }
    
    @isTest 
    static void testMultipleRequestsProcessing() {
        // Given
        List<Quote> quotes = [SELECT Id, Name FROM Quote ORDER BY Name];
        Quote originalQuote = quotes[1]; // New Quote
        Quote newQuote = quotes[0]; // Original Quote
        
        List<QuoteLineItemCloner.CloneQLIRequest> requests = new List<QuoteLineItemCloner.CloneQLIRequest>();
        
        QuoteLineItemCloner.CloneQLIRequest request1 = new QuoteLineItemCloner.CloneQLIRequest();
        request1.originalQuoteId = originalQuote.Id;
        request1.newQuoteId = newQuote.Id;
        requests.add(request1);
        
        // When
        Test.startTest();
        QuoteLineItemCloner.cloneQuoteLineItems(requests);
        Test.stopTest();
        
        // Then
        List<QuoteLineItem> newQLIs = [
            SELECT Id FROM QuoteLineItem WHERE QuoteId = :newQuote.Id
        ];
        
        System.assert(!newQLIs.isEmpty(), 'Se deberían haber creado nuevos QLIs');
    }
    
    // ========================================
    // ERROR SCENARIOS  
    // ========================================
    
    @isTest
    static void testNullOriginalQuoteId() {
        // Given
        Quote newQuote = [SELECT Id FROM Quote WHERE Name = 'New Quote' LIMIT 1];
        
        QuoteLineItemCloner.CloneQLIRequest request = new QuoteLineItemCloner.CloneQLIRequest();
        request.originalQuoteId = null;
        request.newQuoteId = newQuote.Id;
        
        // When/Then
        Test.startTest();
        try {
            QuoteLineItemCloner.cloneQuoteLineItems(new List<QuoteLineItemCloner.CloneQLIRequest>{request});
            System.assert(false, 'Debería lanzar excepción');
        } catch (QuoteLineItemCloner.FlowException ex) {
            System.assert(ex.getMessage().contains('no pueden ser nulos'), 'Mensaje de error correcto: ' + ex.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testNullNewQuoteId() {
        // Given
        Quote originalQuote = [SELECT Id FROM Quote WHERE Name = 'Original Quote' LIMIT 1];
        
        QuoteLineItemCloner.CloneQLIRequest request = new QuoteLineItemCloner.CloneQLIRequest();
        request.originalQuoteId = originalQuote.Id;
        request.newQuoteId = null;
        
        // When/Then
        Test.startTest();
        try {
            QuoteLineItemCloner.cloneQuoteLineItems(new List<QuoteLineItemCloner.CloneQLIRequest>{request});
            System.assert(false, 'Debería lanzar excepción');
        } catch (QuoteLineItemCloner.FlowException ex) {
            System.assert(ex.getMessage().contains('no pueden ser nulos'), 'Mensaje de error correcto: ' + ex.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testOriginalQuoteWithoutQLIs() {
        // Given - Crear nuevo Quote sin QLIs
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Custom Pricebook 1' LIMIT 1];
        
        Quote emptyQuote = new Quote(
            Name = 'Empty Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pb.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today() + 5
        );
        insert emptyQuote;
        
        Quote newQuote = [SELECT Id FROM Quote WHERE Name = 'New Quote' LIMIT 1];
        
        QuoteLineItemCloner.CloneQLIRequest request = new QuoteLineItemCloner.CloneQLIRequest();
        request.originalQuoteId = emptyQuote.Id;
        request.newQuoteId = newQuote.Id;
        
        // When/Then
        Test.startTest();
        try {
            QuoteLineItemCloner.cloneQuoteLineItems(new List<QuoteLineItemCloner.CloneQLIRequest>{request});
            System.assert(false, 'Debería lanzar excepción');
        } catch (QuoteLineItemCloner.FlowException ex) {
            System.assert(ex.getMessage().contains('no tiene productos cargados'), 'Mensaje de error correcto: ' + ex.getMessage());
        }
        Test.stopTest();
    }
    
    
    // ========================================
    // UNIT TESTS FOR UTILITY METHODS
    // ========================================
    
    @isTest
    static void testBuildClonedQLIsMethod() {
        // Given
        List<Product2> products = [SELECT Id FROM Product2 LIMIT 2];
        Id newQuoteId = [SELECT Id FROM Quote WHERE Name = 'New Quote'].Id;
        
        // Mock original QLIs
        List<QuoteLineItem> originalQLIs = new List<QuoteLineItem>();
        for (Integer i = 0; i < products.size(); i++) {
            QuoteLineItem mockQLI = new QuoteLineItem();
            mockQLI.Product2Id = products[i].Id;
            mockQLI.Quantity = 10 + i;
            mockQLI.Discount = 5 + (i * 2);
            mockQLI.Description = 'Test Description ' + i;
            mockQLI.Location__c = 'Location ' + i;
            mockQLI.Classification__c = 'Class ' + i;
            mockQLI.Stock__c = 100 + (i * 10);
            mockQLI.Commited__c = 50 + (i * 5);
            mockQLI.aies__CustomSortOrder__c = i + 1;
            mockQLI.ToBeDelivered__c = 20 + i;
            mockQLI.ToBeSupplied__c = 80 + i;
            originalQLIs.add(mockQLI);
        }
        
        // Mock PricebookEntry map
        Map<Id, PricebookEntry> pbeMap = new Map<Id, PricebookEntry>();
        List<PricebookEntry> realPBEs = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Product2Id IN :products LIMIT 2];
        
        for (Integer i = 0; i < products.size() && i < realPBEs.size(); i++) {
            pbeMap.put(products[i].Id, realPBEs[i]);
        }
        
        // When
        Test.startTest();
        List<QuoteLineItem> result = QuoteLineItemCloner.buildClonedQLIs(originalQLIs, pbeMap, newQuoteId);
        Test.stopTest();
        
        // Then
        System.assertEquals(2, result.size(), 'Deberían crearse 2 QLIs');
        
        for (Integer i = 0; i < result.size(); i++) {
            QuoteLineItem newQLI = result[i];
            QuoteLineItem originalQLI = originalQLIs[i];
            
            System.assertEquals(newQuoteId, newQLI.QuoteId, 'QuoteId debe ser el nuevo');
            System.assertEquals(originalQLI.Product2Id, newQLI.Product2Id, 'Product2Id debe copiarse');
            System.assertEquals(originalQLI.Quantity, newQLI.Quantity, 'Quantity debe copiarse');
            System.assertEquals(originalQLI.Discount, newQLI.Discount, 'Discount debe copiarse');
            System.assertEquals(originalQLI.Description, newQLI.Description, 'Description debe copiarse');
            System.assertEquals(originalQLI.Location__c, newQLI.Location__c, 'Location__c debe copiarse');
            System.assertEquals(originalQLI.Classification__c, newQLI.Classification__c, 'Classification__c debe copiarse');
            System.assertEquals(pbeMap.get(originalQLI.Product2Id).UnitPrice, newQLI.UnitPrice, 'UnitPrice debe ser del nuevo PBE');
        }
    }
    
    @isTest
    static void testBuildClonedQLIsWithMissingProducts() {
        // Given
        List<Product2> products = [SELECT Id FROM Product2 LIMIT 2];
        Id newQuoteId = [SELECT Id FROM Quote WHERE Name = 'New Quote'].Id;
        
        // Mock original QLIs (2 productos)
        List<QuoteLineItem> originalQLIs = new List<QuoteLineItem>();
        for (Integer i = 0; i < products.size(); i++) {
            QuoteLineItem mockQLI = new QuoteLineItem();
            mockQLI.Product2Id = products[i].Id;
            mockQLI.Quantity = 10;
            originalQLIs.add(mockQLI);
        }
        
        // Mock PricebookEntry map (solo 1 producto)
        Map<Id, PricebookEntry> pbeMap = new Map<Id, PricebookEntry>();
        List<PricebookEntry> realPBEs = [SELECT Id, Product2Id, UnitPrice FROM PricebookEntry WHERE Product2Id = :products[0].Id LIMIT 1];
        
        if (!realPBEs.isEmpty()) {
            pbeMap.put(products[0].Id, realPBEs[0]);
        }
        
        // When
        Test.startTest();
        List<QuoteLineItem> result = QuoteLineItemCloner.buildClonedQLIs(originalQLIs, pbeMap, newQuoteId);
        Test.stopTest();
        
        // Then
        System.assertEquals(1, result.size(), 'Solo 1 QLI debería crearse (el que tiene PBE)');
        System.assertEquals(products[0].Id, result[0].Product2Id, 'Debe ser el producto que tiene PBE');
    }
}