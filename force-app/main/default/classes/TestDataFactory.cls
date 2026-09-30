@isTest
public class TestDataFactory {

    public static void crearTodoLoNecesario() {
        // ✅ 1. Crear una cuenta con campo obligatorio
        Account acc = new Account(
            Name = 'Cliente de Prueba',
            RFC__c = 'XAXX010101000' // ⚠️ Ajuste por campo obligatorio
        );
        insert acc;

        // ✅ 2. Crear un Producto con External ID
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            ExternalId__c = 'EXT123',
            Family = 'General',  // ⚠️ Ajuste si Product2 tiene picklist obligatorio
            IsActive = true
        );
        insert testProduct;

        // ✅ 3. Obtener la Pricebook estándar
        Id standardPricebookId = Test.getStandardPricebookId();

        // ✅ 4. Crear una Pricebook personalizada
        Pricebook2 pb2 = new Pricebook2(
            Name = 'Custom PB',
            ExternalId__c = 'PBI-12345678',
            IsActive = true
        );
        insert pb2;

        // ✅ 5. Crear Pricebook Entries (Estándar y Personalizado)
        PricebookEntry pbeStandard = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = testProduct.Id,
            UnitPrice = 100,
            IsActive = true,
            UseStandardPrice = false,
            ExternalId__c = '10000'
        );
        insert pbeStandard;

        PricebookEntry pbeCustom = new PricebookEntry(
            Pricebook2Id = pb2.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100,
            IsActive = true,
            ExternalId__c = '10001'
        );
        insert pbeCustom;

        // ✅ 6. Crear una Oportunidad con Pricebook asignado
        Opportunity opp = new Opportunity(
            Name = 'New Opp',
            StageName = 'Quote',
            CloseDate = System.today(),
            Pricebook2Id = pb2.Id
        );
        insert opp;

        // ✅ 7. Crear una Cotización relacionada con la Oportunidad
        Quote quote1 = new Quote(
            Name = 'Test Quote',
            Status = 'Draft',
            OpportunityId = opp.Id
        );
        insert quote1;

        // ✅ 8. Crear un QuoteLineItem
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quote1.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100,
            Quantity = 1,
            PricebookEntryId = pbeCustom.Id
        );
        insert qli;

        // ✅ 9. Crear una Orden (estado inicial "Draft")
        Order ord = new Order(
            Name = 'New Order',
            AccountId = acc.Id,
            Pricebook2Id = pb2.Id,
            Status = 'Draft',  // ⚠️ Insert inicial debe ser "Draft"
            EffectiveDate = System.today(),
            QuoteId = quote1.Id,
            BillingCity = 'Ciudad Test',
            ShippingCity = 'Ciudad Test'
        );
        insert ord;

        // ✅ 10. 🚀 Intentar Actualizar la Orden a "Ready_To_Send"
        try {
            ord.Status = 'Draft';
            update ord;
            System.debug('🚀 Orden actualizada correctamente a Ready_To_Send');
        } catch (Exception e) {
            System.debug('🚨 ERROR: No se pudo actualizar la orden a Ready_To_Send: ' + e.getMessage());
            throw e; // ⚠️ Lanza el error para que Salesforce lo registre
        }

        // ✅ 11. Crear un OrderItem (SOLO si la orden está en Ready_To_Send)
        try {
            OrderItem ordItem = new OrderItem(
                OrderId = ord.Id,
                Product2Id = testProduct.Id,
                Quantity = 1,
                PricebookEntryId = pbeCustom.Id,
                UnitPrice = 100
            );
            insert ordItem;
        } catch (Exception e) {
            System.debug('🚨 ERROR: No se pudo insertar OrderItem: ' + e.getMessage());
            throw e;
        }
    } 
}