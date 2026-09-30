public with sharing class QuoteMacoLinesController {
    
    @AuraEnabled(cacheable=true)
    public static Quote getQuoteInfo(Id quoteId) {
        return [ SELECT Id, Name, AccountId, Pricebook2Id, PricebookName__c, Warehouse__c  FROM Quote  WHERE Id = :quoteId LIMIT 1 ];
    }

    @AuraEnabled(cacheable=false)
    public static List<QuoteLineWrapper> getQuoteLines(Id quoteId) {
        String warehouseId = [SELECT Warehouse__c FROM Quote WHERE Id = :quoteId].Warehouse__c;
        List<QuoteLineItem> lineItems = [SELECT Id, Product2Id, ProductCode__c, ProductName__c, Quantity, UnitPrice, TotalPrice, Description, ProductoGenerico__c FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY aies__CustomSortOrder__c ASC NULLS LAST, CreatedDate ASC, Id ASC];

        Set<Id> productIds = new Set<Id>();
        for(QuoteLineItem lineItem : lineItems) {
            productIds.add(lineItem.Product2Id);
        }

        List<ProductWarehouse__c> productsWarehouse = [SELECT Id, Existencias__c, Product2__c, Classification__c, Location__c FROM ProductWarehouse__c WHERE Warehouse__c = :warehouseId AND Product2__c IN :productIds];

        Map<Id, ProductWarehouse__c> productWarehouseMap = new Map<Id, ProductWarehouse__c>();
        for(ProductWarehouse__c pw : productsWarehouse) {
            productWarehouseMap.put(pw.Product2__c, pw);
        }

        List<QuoteLineWrapper> wrapperList = new List<QuoteLineWrapper>();
        for(QuoteLineItem lineItem : lineItems) {
            ProductWarehouse__c pw = productWarehouseMap.get(lineItem.Product2Id);
            QuoteLineWrapper wrapper = new QuoteLineWrapper();
            wrapper.id = lineItem.Id;
            wrapper.productId = lineItem.Product2Id;
            wrapper.productCode = lineItem.ProductCode__c;
            wrapper.productName = lineItem.ProductName__c;
            wrapper.quantity = String.valueOf(lineItem.Quantity);
            wrapper.unitPrice = lineItem.UnitPrice;
            wrapper.totalPrice = lineItem.TotalPrice;
            wrapper.description = lineItem.Description;
            wrapper.productoGenerico = lineItem.ProductoGenerico__c;
            wrapper.existencias = pw?.Existencias__c;
            wrapper.classification = pw?.Classification__c;
            wrapper.location = pw?.Location__c;
            System.debug('QuoteLineWrapper: ' + wrapper);
            wrapperList.add(wrapper);
        }
        System.debug('QuoteMacoLinesController.getQuoteLines()-wrapperList: ' + wrapperList);
        return wrapperList;
    }

    @AuraEnabled(cacheable=false)
    public static Boolean insertQuoteLines(String jsonString) {
        System.debug('QuoteMacoLinesController.insertQuoteLines()-jsonString: ' + jsonString);
        try {
            List<QuotesMacoItem> items = (List<QuotesMacoItem>) JSON.deserialize(jsonString, List<QuotesMacoItem>.class);
            System.debug('JSON Parsed: ' + items);
            if(items.size()>0){
                String pricebookId;
                PricebookEntry peg;
                List<QuoteLineItem> quoteLineItems = new List<QuoteLineItem>();
                for(QuotesMacoItem item:items){
                    System.debug('Item: ' + item);
                    if(pricebookId==null){
                        pricebookId = getPricebookIdFromQuote(item.quoteId);
                    }
                    QuoteLineItem newItem = new QuoteLineItem();
                    newItem.QuoteId = item.quoteId;                     // Required
                    newItem.Quantity = item.quantity;                   // Required
                    newItem.UnitPrice = item.unitPrice;                 // Required
                    newItem.Description = item.ProductCode;
                    if(item.generic==false){
                        newItem.Product2Id = item.product2Id;               // Required
                        newItem.PricebookEntryId = item.pricebookEntryId;   // Required
                    }
                    if(item.generic==true){
                        if(peg==null){
                            peg = getGenericProductInfo(pricebookId);
                        }
                        newItem.Product2Id = peg.Product2Id;
                        newItem.PricebookEntryId = peg.Id;
                    }
                    quoteLineItems.add(newItem);
                }
                if(quoteLineItems.size()>0){
                    System.debug('QuoteMacoLinesController.insertQuoteLines()-quoteLineItems: ' + quoteLineItems);
                    insert quoteLineItems;
                }
            }
            return true;
        } catch (Exception e) {
            System.debug('Error in insertQuoteLines: ' + e.getMessage());
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
    }

    @AuraEnabled(cacheable=false)
    public static Boolean updateQuoteLines(String jsonString){
        List<QuoteMacoItemUpdate> itemsUpdate = (List<QuoteMacoItemUpdate>) JSON.deserialize(jsonString, List<QuoteMacoItemUpdate>.class);
        List<QuoteLineItem> recordsToUpdate = new List<QuoteLineItem>();
        for(QuoteMacoItemUpdate item:itemsUpdate){
            QuoteLineItem lineItem = new QuoteLineItem();
            lineItem.Id = item.id;
            lineItem.Quantity = Decimal.valueOf(item.quantity);
            lineItem.UnitPrice= item.unitPrice;
            lineItem.Description = item.Description; 
            recordsToUpdate.add(lineItem);
        }
        System.debug('QuoteMacoLinesController.updateQuoteLines()-recordsToUpdate: ' + recordsToUpdate);
        update recordsToUpdate;
        return true;
    }
    
    @AuraEnabled(cacheable=false)
    public static Boolean deleteListOfQuoteLines(String quoteLinesDelete){
        List<String> linesToDelete = quoteLinesDelete.split(',');
        try {
            List<QuoteLineItem> quoteLines = [SELECT Id FROM QuoteLineItem WHERE Id IN :linesToDelete];
            delete quoteLines;
            return true;
        } catch (Exception e) {
            System.debug('QuoteMacoLinesController.deleteListOfQuoteLines()-Error: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled(cacheable=false)
    public static Boolean deleteAllQuoteLineItems(String quoteId){
        List<QuoteLineItem> items = [SELECT Id FROM QuoteLineItem WHERE QuoteId=:quoteId];
        delete items;
        return true;
    }

    /**
     * ---------------
     * Private Helpers
     * ---------------
     */

    private static Id getPricebookIdFromQuote(String quoteId){
        return [SELECT Id, Pricebook2Id FROM Quote WHERE Id =: quoteId].Pricebook2Id;
    }

    private static PricebookEntry getGenericProductInfo(String pricebookId){
        PricebookEntry peg = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductoGenerico__c = true AND Pricebook2Id=:pricebookId LIMIT 1];
        return peg;
    }

    public class QuoteLineWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String quantity { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public Decimal totalPrice { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean productoGenerico { get; set; }
        @AuraEnabled public Decimal existencias { get; set; }
        @AuraEnabled public String classification { get; set; }
        @AuraEnabled public String location { get; set; }
    }

    public class QuoteMacoItemUpdate {
        public String id {get;set;}
        public String quantity {get;set;}
        public Decimal unitPrice {get;set;}
        public Decimal totalPrice {get;set;}
        public String name {get;set;}
        public String description {get;set;} 
        public String productCode {get;set;}
    }

    public class QuotesMacoItem{
    	public Decimal quantity{get;set;}
    	public String quoteId{get;set;}
    	public String product2Id{get;set;}
    	public String pricebook2Id{get;set;}
    	public String pricebookEntryId{get;set;}
    	public Decimal unitPrice{get;set;}
    	public String description{get;set;}
        public Boolean generic {get;set;}
       public String productCode {get;set;}
    }
}