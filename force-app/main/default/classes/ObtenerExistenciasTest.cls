@isTest
private class ObtenerExistenciasTest {

    @testSetup
    static void setup() {
        createData();
    }

    @isTest
    static void testObtenerProductoExternalId() {
        // WH001 es el que se pasa como excluyente
        String warehouseId = [SELECT Id FROM Warehouse__c WHERE Code__c = 'WH001' LIMIT 1].Id;
        String product2Id = [SELECT Id FROM Product2 WHERE ProductCode = 'TP001' LIMIT 1].Id;

        Test.startTest();
        List<ObtenerExistencias.ExistenciasInformation> result =
            ObtenerExistencias.getExistenciasFromLocal(product2Id, warehouseId);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Debe haber una existencia en otro almacén distinto al pasado');
        System.assertEquals(100, Decimal.valueOf(result[0].existencia), 'Debe tener 100 unidades disponibles');
        System.assertEquals('Test Warehouse 2', result[0].almacen);
    }

    @isTest
    static void testUpdateExistenciasInOrder() {
        Order o = [SELECT Id, Warehouse__c FROM Order WHERE Name = 'Test Order' LIMIT 1];

        Test.startTest();
        ObtenerExistencias.updateExistenciasInOrder(o.Id);
        Test.stopTest();

        OrderItem oi = [
            SELECT Stock__c, Classification__c, Location__c, Unity__c 
            FROM OrderItem 
            WHERE OrderId = :o.Id LIMIT 1
        ];

        System.assertEquals(100, oi.Stock__c, 'Stock debería venir de ProductWarehouse');
        System.assertEquals('Test Classification', oi.Classification__c);
        System.assertEquals('Test Location', oi.Location__c);
        System.assertEquals('Test Unity', oi.Unity__c);
    }

    @isTest
    static void testUpdateExistenciasInQuote() {
        Quote q = [SELECT Id, Warehouse__c FROM Quote WHERE Name = 'Test Quote' LIMIT 1];

        Test.startTest();
        ObtenerExistencias.updateExistenciasInQuote(q.Id);
        Test.stopTest();

        QuoteLineItem qli = [
            SELECT Stock__c, Classification__c, Location__c, Unity__c 
            FROM QuoteLineItem 
            WHERE QuoteId = :q.Id LIMIT 1
        ];

        System.assertEquals(100, qli.Stock__c);
        System.assertEquals('Test Classification', qli.Classification__c);
        System.assertEquals('Test Location', qli.Location__c);
        System.assertEquals('Test Unity', qli.Unity__c);
    }

    private static void createData() {
        // Warehouses
        Warehouse__c warehouse = new Warehouse__c(Name = 'Test Warehouse', Code__c = 'WH001');
        insert warehouse;

        Warehouse__c warehouse2 = new Warehouse__c(Name = 'Test Warehouse 2', Code__c = 'WH002');
        insert warehouse2;

        // Product
        Product2 product = new Product2(
            Name = 'Test Product',
            IsActive = true,
            ProductCode = 'TP001',
            ExternalId__c = 'TP001'
        );
        insert product;

        // Pricebook Entry
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = product.Id,
            Pricebook2Id = stdPbId,
            ExternalId__c = 'TP001',
            UnitPrice = 10,
            IsActive = true
        );
        insert pbe;

        // ProductWarehouse en WH002 (esto es lo que se debería encontrar)
        insert new ProductWarehouse__c(
            Product2__c = product.Id,
            Warehouse__c = warehouse2.Id,
            Existencias__c = 100,
            Classification__c = 'Test Classification',
            Location__c = 'Test Location',
            Unity__c = 'Test Unity'
        );

        // Account
        Account acc = createTestAccount();

        // Order + OrderItem
        Order o = new Order(
            Name = 'Test Order',
            Status = 'Draft',
            EffectiveDate = System.today(),
            Warehouse__c = warehouse2.Id,
            AccountId = acc.Id,
            Pricebook2Id = stdPbId
        );
        insert o;

        insert new OrderItem(
            OrderId = o.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 10
        );

        // Opportunity + Quote + QuoteLineItem
        Opportunity opp = createTestOpportunity(acc.Id);

        Quote q = new Quote(
            Name = 'Test Quote',
            Status = 'Draft',
            Pricebook2Id = stdPbId,
            OpportunityId = opp.Id,
            Warehouse__c = warehouse2.Id
        );
        insert q;

        insert new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = product.Id,
            Quantity = 1,
            UnitPrice = 10,
            PricebookEntryId = pbe.Id
        );
    }

    private static Account createTestAccount() {
        Account acc = new Account(Name = 'Test Account', RFC__c = '123');
        insert acc;
        return acc;
    }

    private static Opportunity createTestOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = accountId
        );
        insert opp;
        return opp;
    }
}