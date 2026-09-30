@isTest
public class QuoteMacoLinesControllerTest {
    
    @testSetup
    static void setupTestData() {
        Id pricebookId = Test.getStandardPricebookId();
		Pricebook2 standardPricebook = new Pricebook2(
    		Id = pricebookId,
    		IsActive = true,
            ExternalId__c = 'STD'
        );
		update standardPricebook;
    	System.debug('Standard Pricebook Id: ' + standardPricebook.Id);
        
    	Pricebook2 pb = new Pricebook2(
    	    Name = 'TEST_PB',
    	    IsActive = true,
    	    ExternalId__c = 'TEST_PB' );
    	insert pb;
    	System.debug('Custom Pricebook Id: ' + pb.Id);

    	Product2 product = new Product2(
        	Name = 'Test Product',
        	IsActive = true,
        	ExternalId__c = 'TEST_PRODUCT' );
    	insert product;
    	System.debug('Product Id: ' + product.Id);
        
        Product2 productGeneric = new Product2(
        	Name='GENERIC',
            IsActive = true,
            ProductoGenerico__c = true,
            ExternalId__c = 'GENERIC');
        insert productGeneric;
        System.debug('Generic: ' + productGeneric.Id);

    	// NOTA: no insertamos PricebookEntry manualmente. El flow activo
    	// "ST_Maco_ProductCreation" (RecordAfterSave en Product2, sin filtro de entrada)
    	// ya crea automáticamente una PricebookEntry por cada Pricebook2 activo para todo
    	// Product2 recién insertado. Insertarlas aquí también duplicaba el registro y
    	// hacía fallar el setup con DUPLICATE_VALUE. Solo ajustamos el UnitPrice de las
    	// entries auto-creadas en el pricebook custom.
    	PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :product.Id AND Pricebook2Id = :pb.Id LIMIT 1];
    	pbe.UnitPrice = 100;
    	update pbe;
    	System.debug('Custom PricebookEntry Id: ' + pbe.Id);

        PricebookEntry pbeg = [SELECT Id FROM PricebookEntry WHERE Product2Id = :productGeneric.Id AND Pricebook2Id = :pb.Id LIMIT 1];
        pbeg.UnitPrice = 100;
        update pbeg;
        System.debug('Product Generic - Custom Price: ' + pbeg.Id);
        
        Opportunity opp = new Opportunity();
        opp.Name = 'TEST_OPP';
        opp.StageName ='Quote';
        opp.CloseDate = System.today();
        insert opp;
        System.debug('Opp: ' + opp.Id);
        
        Quote quote = new Quote(
            Name = 'Test Quote',
            Pricebook2Id = pb.Id,
            Status = 'Draft',
            OpportunityId = opp.Id );
        insert quote;
        System.debug('Quote: ' + quote.Id);
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = quote.Id,
            Quantity = 2,
            UnitPrice = 100.0,
            PricebookEntryId = pbe.Id );
        insert qli;
        
        QuoteLineItem qli2 = new QuoteLineItem(
            QuoteId = quote.Id,
            Quantity = 2,
            UnitPrice = 100.0,
            PricebookEntryId = pbe.Id );
        insert qli2;
        System.debug('qli2: ' + qli2.Id);
    }
    
    @isTest
    static void testGetQuoteInfo() {
        Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
        
        Test.startTest();
        Quote result = QuoteMacoLinesController.getQuoteInfo(quote.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetQuoteLines() {
        Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
        
        Test.startTest();
List<QuoteMacoLinesController.QuoteLineWrapper> result = QuoteMacoLinesController.getQuoteLines(quote.Id);
        Test.stopTest();
    }

    @isTest
    static void testInsertQuoteLines() {
        Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Product2 productGeneric = [SELECT Id FROM Product2 WHERE ProductoGenerico__c = true];
        PricebookEntry pricebookEntry = [SELECT Id FROM PricebookEntry WHERE Product2Id = :product.Id AND Pricebook2.IsStandard=false LIMIT 1];

        List<QuoteMacoLinesController.QuotesMacoItem> items = new List<QuoteMacoLinesController.QuotesMacoItem>();
		QuoteMacoLinesController.QuotesMacoItem item = new QuoteMacoLinesController.QuotesMacoItem();
		item.quantity = 1;
		item.quoteId = quote.Id;
		item.product2Id = product.Id;
		item.pricebookEntryId = pricebookEntry.Id;
		item.unitPrice = 100;
		item.description = 'Test Line Item';
		item.generic = false;
		items.add(item);
        
        QuoteMacoLinesController.QuotesMacoItem item2 = new QuoteMacoLinesController.QuotesMacoItem();
		item2.quantity = 1;
		item2.quoteId = quote.Id;
		item2.product2Id = productGeneric.Id;
		item2.pricebookEntryId = null;
		item2.unitPrice = 100;
		item2.description = 'Test Line Item';
		item2.generic = true;
		items.add(item2);

        Test.startTest();
        Boolean result = QuoteMacoLinesController.insertQuoteLines(JSON.serialize(items));
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateQuoteLines(){
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1]; 
        List<QuoteMacoLinesController.QuoteMacoItemUpdate> listUpdate = new List<QuoteMacoLinesController.QuoteMacoItemUpdate>();
        QuoteMacoLinesController.QuoteMacoItemUpdate itemUpdate = new QuoteMacoLinesController.QuoteMacoItemUpdate();
        itemUpdate.Id = qli.Id;
        itemUpdate.quantity = '2';
        itemUpdate.unitPrice = 100;
		itemUpdate.totalPrice = 200;
		itemUpdate.name = 'TEST';
        itemUpdate.productCode = 'TP';
        listUpdate.add(itemUpdate);
        Test.startTest();
        QuoteMacoLinesController.updateQuoteLines(JSON.serialize(listUpdate));
        Test.stopTest();
    }
    
    @isTest
    static void testDeleteListOfQuoteLines(){
        QuoteLineItem qli = [SELECT Id FROM QuoteLineItem LIMIT 1];
        Test.startTest();
        QuoteMacoLinesController.deleteListOfQuoteLines(qli.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testDeleteAllQuoteLineItems(){
         Quote quote = [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
        Test.startTest();
		QuoteMacoLinesController.deleteAllQuoteLineItems(quote.Id);        
        Test.stopTest();
    }
}