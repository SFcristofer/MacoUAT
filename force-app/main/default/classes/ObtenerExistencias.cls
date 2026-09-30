public with sharing class ObtenerExistencias {

    // -----------
    // LWC Methods
    // -----------

    @AuraEnabled(cacheable=false)
    public static List<ExistenciasInformation> getExistenciasFromLocal(String productId, String almacenId) {
        productId = productId != null ? productId.trim() : '';
        almacenId = almacenId != null ? almacenId.trim() : '';
        List<ProductWarehouse__c> existencias = [ SELECT Id, Warehouse__r.Name, Product2__c, Existencias__c, ToBeDelivered__c FROM ProductWarehouse__c  WHERE Product2__c = :productId AND Warehouse__c != :almacenId WITH SECURITY_ENFORCED ];
        List<ExistenciasInformation> result = new List<ExistenciasInformation>();
        for (ProductWarehouse__c pw : existencias) {
            ExistenciasInformation info = new ExistenciasInformation();
            info.almacen = pw.Warehouse__r.Name;
            info.existencia = String.valueOf(pw.Existencias__c);
            info.comprometido = String.valueOf(pw.ToBeDelivered__c);
            result.add(info);
        }
        return result;
    }

    public class ExistenciasInformation {
        @AuraEnabled public String almacen;
        @AuraEnabled public String existencia;
        @AuraEnabled public String comprometido;
    }

    // ---------------
    // Trigger Methods
    // ---------------

    // Method executed on trigger only.
    public static void updateExistenciasInOrder(Id orderId) {
        List<OrderItem> orderItems = [ SELECT Id, Product2Id, Classification__c, Location__c, Stock__c, Unity__c, Order.Warehouse__c, PorSurtir__c, Surtida__c   FROM OrderItem  WHERE OrderId = :orderId];
        if (orderItems.isEmpty()) {
            return;
        }
        Id warehouseId = orderItems[0].Order.Warehouse__c;
        Set<Id> productIds = new Set<Id>();
        for (OrderItem item : orderItems) {
            if (item.Product2Id != null) {
                productIds.add(item.Product2Id);
            }
        }
        Map<Id, ProductWarehouse__c> existenciaMap = getProductWarehouse(new List<Id>(productIds), warehouseId);
        List<OrderItem> itemsToUpdate = new List<OrderItem>();
        for (OrderItem item : orderItems) {
            if (existenciaMap.containsKey(item.Product2Id)) {
                ProductWarehouse__c pw = existenciaMap.get(item.Product2Id);
                item.Stock__c = pw.Existencias__c;
                item.Classification__c = pw.Classification__c;
                item.Location__c = pw.Location__c;
                item.Unity__c = pw.Unity__c;
                item.Surtida__c = pw.ToBeDelivered__c;
                item.PorSurtir__c = pw.ToBeSupplied__c;
                itemsToUpdate.add(item);
            }
        }
        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }
    }

    // Method executed on trigger only.
    public static void updateExistenciasInQuote(Id quoteId) {
        List<QuoteLineItem> quoteItems = [ SELECT Id, Product2Id, Classification__c, Location__c, Stock__c, Unity__c, Quote.Warehouse__c, ToBeSupplied__c, ToBeDelivered__c  FROM QuoteLineItem  WHERE QuoteId = :quoteId ];
        if (quoteItems.isEmpty()) {
            return;
        }
        Id warehouseId = quoteItems[0].Quote.Warehouse__c;
        Set<Id> productIds = new Set<Id>();
        for (QuoteLineItem item : quoteItems) {
            if (item.Product2Id != null) {
                productIds.add(item.Product2Id);
            }
        }
        Map<Id, ProductWarehouse__c> existenciaMap = getProductWarehouse(new List<Id>(productIds), warehouseId);
        List<QuoteLineItem> itemsToUpdate = new List<QuoteLineItem>();
        for (QuoteLineItem item : quoteItems) {
            if (existenciaMap.containsKey(item.Product2Id)) {
                ProductWarehouse__c pw = existenciaMap.get(item.Product2Id);
                item.Stock__c = pw.Existencias__c;
                item.Classification__c = pw.Classification__c;
                item.Location__c = pw.Location__c;
                item.Unity__c = pw.Unity__c;
                item.ToBeDelivered__c = pw.ToBeDelivered__c;
                item.ToBeSupplied__c = pw.ToBeSupplied__c;
                itemsToUpdate.add(item);
            }
        }
        if (!itemsToUpdate.isEmpty()) {
            update itemsToUpdate;
        }
    }

    // --------------
    // Private Helper
    // --------------

    private static Map<Id, ProductWarehouse__c> getProductWarehouse(List<Id> productIds, Id warehouseId) {
        List<ProductWarehouse__c> productWarehouses = [
            SELECT Id, Product2__c, Warehouse__c, Existencias__c, Classification__c, Location__c, Unity__c, ToBeDelivered__c, ToBeSupplied__c
            FROM ProductWarehouse__c 
            WHERE Product2__c IN :productIds
            AND Warehouse__c =: warehouseId
        ];
        Map<Id, ProductWarehouse__c> existenciaMap = new Map<Id, ProductWarehouse__c>();
        for (ProductWarehouse__c pw : productWarehouses) {
            existenciaMap.put(pw.Product2__c, pw);
        }
        return existenciaMap;
    }
}