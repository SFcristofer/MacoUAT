@isTest
private class OrderTriggerHandlerTest {

    @isTest
    static void testAfterUpdateCallsUpdateExistencias() {
        // Crear Warehouse
        Warehouse__c wh = new Warehouse__c(Name = 'WH', Code__c = 'WH_ORDER');
        insert wh;

        // Crear Cuenta
        Account acc = new Account(Name = 'Test Account', RFC__c = 'XAXX010101000');
        insert acc;

        // Producto
        Product2 prod = new Product2(
            Name = 'Producto A',
            IsActive = true,
            ProductCode = 'PROD001',
            ExternalId__c = 'PROD001'
        );
        insert prod;

        // Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 100,
            IsActive = true,
            ExternalId__c = 'PBE001'
        );
        insert pbe;

        // ProductWarehouse
        insert new ProductWarehouse__c(
            Product2__c = prod.Id,
            Warehouse__c = wh.Id,
            Existencias__c = 100,
            Classification__c = 'Clase A',
            Location__c = 'Zona A',
            Unity__c = 'Unidad A'
        );

        // Order
        Order ord = new Order(
            Name = 'Test Order',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id,
            Warehouse__c = wh.Id,
            Pricebook2Id = stdPbId
        );
        insert ord;

        // OrderItem
        insert new OrderItem(
            OrderId = ord.Id,
            Quantity = 1,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id
        );

        // Trigger sobre Order al actualizar la fecha
        Test.startTest();
        ord.EffectiveDate = ord.EffectiveDate.addDays(1);
        update ord;
        Test.stopTest();

        // Verificamos si se actualizó el Stock en el OrderItem
        OrderItem oi = [
            SELECT Stock__c, Classification__c, Location__c, Unity__c
            FROM OrderItem
            WHERE OrderId = :ord.Id LIMIT 1
        ];

        System.assertEquals(100, oi.Stock__c, 'Expected: 100');
        System.assertEquals('Clase A', oi.Classification__c);
        System.assertEquals('Zona A', oi.Location__c);
        System.assertEquals('Unidad A', oi.Unity__c);
    }
}