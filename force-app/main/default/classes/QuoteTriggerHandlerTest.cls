@isTest
public class QuoteTriggerHandlerTest {

    @isTest
    static void testAfterUpdateCallsUpdateExistencias() {
        // Warehouse
        Warehouse__c wh = new Warehouse__c(Name = 'Quote WH', Code__c = 'WH_Q001');
        insert wh;

        // Account y Opportunity
        Account acc = new Account(Name = 'Test Account', RFC__c = 'XAXX010101000');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        // Product y Pricebook
        Id stdPbId = Test.getStandardPricebookId();

        Product2 prod = new Product2(
            Name = 'Quote Product',
            IsActive = true,
            ExternalId__c = 'PROD_QUOTE_001'
        );
        insert prod;

        PricebookEntry pbe = new PricebookEntry(
            Product2Id = prod.Id,
            Pricebook2Id = stdPbId,
            UnitPrice = 150,
            IsActive = true,
            ExternalId__c = 'PBE_QUOTE_001'
        );
        insert pbe;

        // Existencias en ProductWarehouse
        ProductWarehouse__c pw = new ProductWarehouse__c(
            Product2__c = prod.Id,
            Warehouse__c = wh.Id,
            Existencias__c = 75,
            Classification__c = 'Clase Q',
            Location__c = 'Rack 5',
            Unity__c = 'Caja'
        );
        insert pw;

        // Quote
        Quote q = new Quote(
            Name = 'Quote Test',
            Status = 'Draft',
            Pricebook2Id = stdPbId,
            OpportunityId = opp.Id,
            Warehouse__c = wh.Id
        );
        insert q;

        // Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = prod.Id,
            Quantity = 1,
            UnitPrice = 150,
            PricebookEntryId = pbe.Id
        );
        insert qli;

        // Disparar trigger: update al Quote
        q.Name = 'Quote Updated';
        update q;

        // Verificamos que se actualizaron los campos desde ProductWarehouse
        QuoteLineItem qliUpdated = [
            SELECT Stock__c, Classification__c, Location__c, Unity__c
            FROM QuoteLineItem
            WHERE Id = :qli.Id
        ];

        System.assertEquals(75, qliUpdated.Stock__c);
        System.assertEquals('Clase Q', qliUpdated.Classification__c);
        System.assertEquals('Rack 5', qliUpdated.Location__c);
        System.assertEquals('Caja', qliUpdated.Unity__c);
    }
}