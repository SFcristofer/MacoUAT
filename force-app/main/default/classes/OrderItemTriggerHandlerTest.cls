@isTest
public class OrderItemTriggerHandlerTest {

    @isTest
    static void testAfterUpdateInvokesValidateExistencias() {
        // Crear Warehouse
        Warehouse__c wh = new Warehouse__c(Name = 'Test WH', Code__c = 'WH_TEST');
        insert wh;

        // Crear Cuenta
        Account acc = new Account(Name = 'Cuenta Test', RFC__c = 'XAXX010101000');
        insert acc;

        // Producto
        Product2 prod = new Product2(
            Name = 'Producto Test',
            IsActive = true,
            ProductCode = 'PROD_TEST',
            ExternalId__c = 'EXT_TEST'
        );
        insert prod;

        // PricebookEntry
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 10,
            IsActive = true,
            ExternalId__c = 'PBE_EXT_TEST'
        );
        insert pbe;

        // Order
        Order ord = new Order(
            Name = 'Order Test',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id,
            Warehouse__c = wh.Id,
            Pricebook2Id = stdPbId
        );
        insert ord;

        // OrderItem
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 1,
            UnitPrice = 10,
            PricebookEntryId = pbe.Id
        );
        insert oi;

        // ProductWarehouse para WH_TEST y PROD_TEST
        ProductWarehouse__c pw = new ProductWarehouse__c(
            Product2__c = prod.Id,
            Warehouse__c = wh.Id,
            Existencias__c = 500,
            Classification__c = 'Clase A',
            Location__c = 'Ubicación X',
            Unity__c = 'Unidad Z'
        );
        insert pw;

        // Disparar update al OrderItem
        Test.startTest();
        oi.Quantity = 2;
        update oi;
        Test.stopTest();

        // Verificar valores copiados
        OrderItem result = [
            SELECT Stock__c, Classification__c, Location__c, Unity__c
            FROM OrderItem
            WHERE Id = :oi.Id
        ];

        System.assertEquals(500, result.Stock__c, 'Debe actualizarse desde ProductWarehouse');
        System.assertEquals('Clase A', result.Classification__c);
        System.assertEquals('Ubicación X', result.Location__c);
        System.assertEquals('Unidad Z', result.Unity__c);
    }
}