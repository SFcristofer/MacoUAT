@isTest
public class QuoteLineItemTriggerHandlerTest {

    @isTest
    static void testAfterUpdateCallsUpdateExistencias() {
        // 1. Crear Warehouse
        Warehouse__c warehouse = new Warehouse__c(Name = 'WH Trigger QLI', Code__c = 'WH_QLI');
        insert warehouse;

        // 2. Crear Account y Opportunity
        Account acc = new Account(Name = 'Account QLI', RFC__c = 'ABC123456789');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Opp QLI',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        // 3. Crear Product y Pricebook
        Id stdPbId = Test.getStandardPricebookId();

        Product2 product = new Product2(Name = 'Prod QLI', IsActive = true, ExternalId__c = 'EXTPROD_QLI');
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Product2Id = product.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 123.45,
            IsActive = true,
            ExternalId__c = 'PBE_QLI'
        );
        insert pbe;

        // 4. Crear ProductWarehouse
        ProductWarehouse__c pw = new ProductWarehouse__c(
            Product2__c = product.Id,
            Warehouse__c = warehouse.Id,
            Existencias__c = 500,
            Classification__c = 'Cat QLI',
            Location__c = 'Loc QLI',
            Unity__c = 'U QLI'
        );
        insert pw;

        // 5. Crear Quote
        Quote quote = new Quote(
            Name = 'Quote QLI',
            Status = 'Draft',
            Pricebook2Id = stdPbId,
            OpportunityId = opp.Id,
            Warehouse__c = warehouse.Id
        );
        insert quote;

        // 6. Crear QuoteLineItem
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quote.Id,
            Product2Id = product.Id,
            Quantity = 1,
            UnitPrice = 123.45,
            PricebookEntryId = pbe.Id
        );
        insert qli;

        // 7. Disparar trigger haciendo update al QLI
        qli.Quantity = 2;
        update qli;

        // 8. Verificar que los campos se actualizaron correctamente desde ProductWarehouse
        QuoteLineItem qliUpdated = [
            SELECT Stock__c, Classification__c, Location__c, Unity__c
            FROM QuoteLineItem
            WHERE Id = :qli.Id
        ];

        System.assertEquals(500, qliUpdated.Stock__c, 'Debe actualizarse desde ProductWarehouse');
        System.assertEquals('Cat QLI', qliUpdated.Classification__c);
        System.assertEquals('Loc QLI', qliUpdated.Location__c);
        System.assertEquals('U QLI', qliUpdated.Unity__c);
    }
}