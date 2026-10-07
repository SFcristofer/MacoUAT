@isTest
public class GenerateQuotePDFDocumentTest {

    @isTest
    static void testCreateQuote() {
        // Crear datos de prueba
        Account testAccount = new Account(
            Name = 'Test Account',
            RFC__c = 'XAXX010101000' // Campo obligatorio corregido
        );
        insert testAccount;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id
        );
        insert testOpportunity;

        Quote testQuote = new Quote(
            Name = 'Test Quote',
            OpportunityId = testOpportunity.Id,
            Status = 'Draft',
            ExpirationDate = Date.today().addDays(30)
        );
        insert testQuote;

        // Forzar ejecución del método @future
        Test.startTest();
        GenerateQuotePDFDocument.createQuote(new List<Id>{testQuote.Id});
        Test.stopTest();  // 🚀 Esto hace que Salesforce ejecute el método asincrónico antes de seguir

        // Validar que el PDF se haya generado y adjuntado correctamente
        List<ContentVersion> quoteDocs = [SELECT Id, Title, FirstPublishLocationId FROM ContentVersion WHERE FirstPublishLocationId = :testQuote.Id];

        // Asegurar que se generó el archivo PDF correctamente
        System.assert(!quoteDocs.isEmpty(), 'Debe haberse generado un ContentVersion para la cotización.');
        System.assertEquals(testQuote.Id, quoteDocs[0].FirstPublishLocationId, 'El ContentVersion debe estar asociado a la cotización correcta.');
        System.assert(quoteDocs[0].Title.endsWith('_V1.pdf'), 'El nombre del archivo PDF debe ser el esperado.');
    }

    @isTest
    static void testQuotePDFController() {
        Account acct = new Account(Name = 'Cuenta Test', AccountNumber = '123456', RFC__c = 'XAXX010101000');
        insert acct;
        Product2 prod = new Product2(Name = 'Producto Test', IsActive = true);
        insert prod;
        Id pbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pbId, Product2Id = prod.Id, UnitPrice = 491.9, IsActive = true, ExternalId__c = '0001');
        insert pbe;
        Opportunity opp = new Opportunity(Name = 'Opp Test', StageName = 'Prospecting', CloseDate = Date.today().addDays(30), AccountId = acct.Id, Pricebook2Id = pbId);
        insert opp;
        Quote q = new Quote(Name = 'Quote Test', OpportunityId = opp.Id, Pricebook2Id = pbId, End_Date__c = Date.today().addDays(30));
        insert q;
        insert new QuoteLineItem(QuoteId = q.Id, PricebookEntryId = pbe.Id, Product2Id = prod.Id, Quantity = 30.48, UnitPrice = 491.9, Ubicacion__c = '11-A-1');

        Test.setCurrentPage(Page.QuotePDF);
        QuotePDFController ctrl = new QuotePDFController(new ApexPages.StandardController(q));

        System.assertEquals(1, ctrl.formattedItems.size());
        System.assertEquals('30.48', ctrl.formattedItems[0].quantity);
        System.assertEquals('11-A-1', ctrl.formattedItems[0].ubicacion);
        System.assert(ctrl.formattedItems[0].unitPriceFormatted.endsWith('491.90'), ctrl.formattedItems[0].unitPriceFormatted);
        System.assertNotEquals('', ctrl.expirationDateFormatted);
    }
}