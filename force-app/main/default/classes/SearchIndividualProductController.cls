public with sharing class SearchIndividualProductController {

    @AuraEnabled(cacheable=false)
    public static ProductPriceInformation getSpecificPricebookEntry(String pricebookEntryId){
        System.debug('Pricebook Entry ID: ' + pricebookEntryId);
        List<PricebookEntry> results = [SELECT Id, UnitPrice, Pricebook2Id, Product2.Name, Product2.ProductCode FROM PricebookEntry WHERE Id = :pricebookEntryId];
        if(!results.isEmpty()){
            PricebookEntry pb = results[0];
            ProductPriceInformation info = new ProductPriceInformation();
            info.entryId = pb.Id;
            info.pricebookId = pb.Pricebook2Id;
            info.unitPrice = String.valueOf(pb.UnitPrice);
            info.productName = pb.Product2.Name;
            info.productCode = pb.Product2.ProductCode;
            return info;
        }
        return null; 
    }

    @AuraEnabled(cacheable=false)
    public static List<ProductPriceInformation> getPossibleProducts(String searchTerm, String pricebookId){
        System.debug('Search Term: ' + searchTerm);
        System.debug('Pricebook ID: ' + pricebookId);
        List<PricebookEntry> results =[
            SELECT Id, Product2.Name, Product2.ProductCode FROM PricebookEntry 
            WHERE Pricebook2Id =:pricebookId
            AND IsActive = true
            AND (
                Product2.Name LIKE :('%' + searchTerm + '%') OR 
                Product2.ProductCode LIKE :('%' + searchTerm + '%')
            )];
        if(!results.isEmpty()){
            List<ProductPriceInformation> posibleProducts = new List<ProductPriceInformation>();
            for(PricebookEntry pb : results){
                ProductPriceInformation info = new ProductPriceInformation();
                info.entryId = pb.Id;
                info.pricebookId = pricebookId;
                info.productName = pb.Product2.Name;
                info.productCode = pb.Product2.ProductCode;
                posibleProducts.add(info);
            }
            return posibleProducts;
        }
        return null; 
    }

    @AuraEnabled(cacheable=false)
    public static ProductPriceInformation getProductByProductCode(String productCode, String pricebookId, String almacenId){
        List<PricebookEntry> result = [
            SELECT Id, UnitPrice, Product2.Name, Product2.ProductCode, Product2Id, IsActive, Product2.ExternalId__c 
            FROM PricebookEntry 
            WHERE Product2.ProductCode = :productCode 
            AND Pricebook2Id = :pricebookId 
            AND IsActive = true
            LIMIT 1
        ];
        ProductPriceInformation info = new ProductPriceInformation();
        if (!result.isEmpty()) {
            PricebookEntry pb = result[0];
            info.entryId = pb.Id;
            info.pricebookId = pricebookId;
            info.productId = pb.Product2Id;
            info.unitPrice = String.valueOf(pb.UnitPrice);
            info.productName = pb.Product2.Name;
            info.productCode = pb.Product2.ProductCode;
            info.isActive = pb.IsActive;
            info.externalId = pb.Product2.ExternalId__c;
        }
        if(!String.isBlank(almacenId)){
            List<ProductWarehouse__c> existencias = [SELECT Id, Existencias__c, Location__c, Unity__c, Classification__c FROM ProductWarehouse__c WHERE Product2__r.ProductCode = :productCode AND Warehouse__c=:almacenId];
            if(!existencias.isEmpty()){
                info.existencias = String.valueOf(existencias[0].Existencias__c);
                info.ubicacion = existencias[0].Location__c;
                info.clasificacion = existencias[0].Classification__c;
                info.unidadMedida = existencias[0].Unity__c;
            }
        }
        return !result.isEmpty() ? info : null;
    }

    @AuraEnabled(cacheable=false)
    public static ProductPriceInformation getProductByName(String productCode, String pricebookId, String almacenId){
        List<PricebookEntry> result = [
            SELECT Id, UnitPrice, Product2.Name, Product2.ProductCode, Product2Id, IsActive, Product2.ExternalId__c 
            FROM PricebookEntry 
            WHERE Product2.Name = :productCode 
            AND Pricebook2Id = :pricebookId 
            AND IsActive = true
            LIMIT 1
        ];
        ProductPriceInformation info = new ProductPriceInformation();
        if (!result.isEmpty()) {
            System.debug('Found product and mapping');
            PricebookEntry pb = result[0];
            info.entryId = pb.Id;
            info.pricebookId = pricebookId;
            info.productId = pb.Product2Id;
            info.unitPrice = String.valueOf(pb.UnitPrice);
            info.productName = pb.Product2.Name;
            info.productCode = pb.Product2.ProductCode;
            info.isActive = pb.IsActive;
            info.externalId = pb.Product2.ExternalId__c;
        }
        if(!String.isBlank(almacenId)){
            System.debug('Searching for existencias in almacen: ' + almacenId);
            List<ProductWarehouse__c> existencias = [SELECT Id, Existencias__c, Location__c, Unity__c, Classification__c, ToBeDelivered__c FROM ProductWarehouse__c WHERE Product2__r.Name = :productCode AND Warehouse__c=:almacenId];
            if(!existencias.isEmpty()){
                info.existencias = String.valueOf(existencias[0].Existencias__c);
                info.ubicacion = existencias[0].Location__c;
                info.clasificacion = existencias[0].Classification__c;
                info.unidadMedida = existencias[0].Unity__c;
                info.comprometido = String.valueOf(existencias[0].ToBeDelivered__c);
            }
        }
        return !result.isEmpty() ? info : null;
    }

    @AuraEnabled(cacheable=false)
    public static List<ProductWarehouse__c> getProductExistencias(String productId){
        System.debug('Existencias Product ID: ' + productId);
        List<ProductWarehouse__c> existencias = [SELECT Id, Existencias__c, ProductName__c, WarehouseName__c FROM ProductWarehouse__c WHERE Product2__c=:productId];
        return existencias;
    }

    public class ProductPriceInformation {
        @AuraEnabled public String entryId { get; set; }
        @AuraEnabled public String pricebookId { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public String unitPrice { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public String externalId { get; set; }
        @AuraEnabled public String existencias { get; set; }
        @AuraEnabled public String ubicacion { get; set; }
        @AuraEnabled public String clasificacion { get; set; }
        @AuraEnabled public String unidadMedida { get; set; }
        @AuraEnabled public String comprometido { get; set; }
    }
}