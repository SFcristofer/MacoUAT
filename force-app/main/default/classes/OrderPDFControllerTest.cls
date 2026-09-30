@isTest
public class OrderPDFControllerTest {
    
    @isTest
    static void testOrderPDFController() {
        // Crear cuenta
        Account acct = new Account(Name = 'Cuenta Test', AccountNumber = '123456', RFC__c = 'XAXX010101000');
        insert acct;

        // Crear producto
        Product2 prod = new Product2(Name = 'Producto Test', Description = 'Descripción producto', isActive = true);
        insert prod;

        // Obtener Pricebook estándar
        Id standardPbId = Test.getStandardPricebookId();

        // Crear PricebookEntry estándar
        PricebookEntry standardEntry = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            ExternalId__c = '0001'
        );
        insert standardEntry;

        // Crear Order
        Order ord = new Order(
    AccountId = acct.Id,
    Status = 'Draft',
    EffectiveDate = Date.today(),
    Pricebook2Id = standardPbId,
    ZF_Pedido_ID__c = 'ZF-001'
        );
        insert ord;

        // Crear OrderItem
        OrderItem item = new OrderItem(
            OrderId = ord.Id,
            Quantity = 2,
            UnitPrice = 100,
            PricebookEntryId = standardEntry.Id,
            Description = 'Ítem de prueba'
        );
        insert item;

        // Ejecutar controlador
        ApexPages.StandardController sc = new ApexPages.StandardController(ord);
        OrderPDFController ctrl = new OrderPDFController(sc);

        // Validaciones
        System.assertNotEquals(null, ctrl.orderRecord);
        System.assert(ctrl.formattedOrderItems.size() > 0);
        System.assert(ctrl.effectiveDateFormatted != null);
    }
}