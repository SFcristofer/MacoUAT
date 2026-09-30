public with sharing class OrderItemCloner {

    public class CloneOrderItemRequest {
        @InvocableVariable(required=true)
        public Id originalOrderId;

        @InvocableVariable(required=true)
        public Id newOrderId;
    }

    @InvocableMethod(label='Clonar OrderItems a un nuevo pedido')
    public static void cloneOrderItems(List<CloneOrderItemRequest> requests) {
        for (CloneOrderItemRequest req : requests) {
            try {
                cloneItems(req.originalOrderId, req.newOrderId);
            } catch (Exception ex) {
                System.debug('🛑 Error al clonar OrderItems: ' + ex.getMessage());
                throw new FlowException('Error al clonar los productos del pedido: ' + ex.getMessage());
            }
        }
    }

    private static void cloneItems(Id originalOrderId, Id newOrderId) {
        if (originalOrderId == null || newOrderId == null) {
            throw new FlowException('IDs del pedido original o nuevo no pueden ser nulos.');
        }

        // 1. Obtener OrderItems del pedido original
        List<OrderItem> originalItems = [
            SELECT Product2Id, Quantity, UnitPrice, Description,Location__c,Classification__c,Stock__c,Commited__c,Unity__c,Surtida__c,PorSurtir__c,SortOrderProducts__c
            FROM OrderItem
            WHERE OrderId = :originalOrderId
            ORDER BY SortOrderProducts__c ASC NULLS LAST, CreatedDate ASC, Id ASC
        ];

        if (originalItems.isEmpty()) {
            throw new FlowException('El pedido original no tiene productos cargados.');
        }

        // 2. Obtener Pricebook del nuevo pedido
        Order newOrder = [
            SELECT Pricebook2Id FROM Order WHERE Id = :newOrderId
        ];

        if (newOrder.Pricebook2Id == null) {
            throw new FlowException('El nuevo pedido no tiene una lista de precios asignada.');
        }

        // 3. Obtener PricebookEntries en la nueva Pricebook
        Set<Id> productIds = new Set<Id>();
        for (OrderItem oi : originalItems) {
            productIds.add(oi.Product2Id);
        }

        Map<Id, PricebookEntry> pricebookEntryMap = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :newOrder.Pricebook2Id
            AND Product2Id IN :productIds
        ]) {
            pricebookEntryMap.put(pbe.Product2Id, pbe);
        }

        // 4. Crear nuevos OrderItems
        List<OrderItem> newItems = new List<OrderItem>();
        List<Id> notFoundProducts = new List<Id>();

        for (OrderItem oldItem : originalItems) {
            if (pricebookEntryMap.containsKey(oldItem.Product2Id)) {
                PricebookEntry pbe = pricebookEntryMap.get(oldItem.Product2Id);

                OrderItem newItem = new OrderItem();
                newItem.OrderId = newOrderId;
                newItem.PricebookEntryId = pbe.Id;
                newItem.Quantity = oldItem.Quantity;
                newItem.UnitPrice = pbe.UnitPrice;
                newItem.Description = oldItem.Description;
                newItem.Location__c = oldItem.Location__c;
                newItem.Classification__c = oldItem.Classification__c;
                newItem.Commited__c = oldItem.Commited__c;
                newItem.Unity__c = oldItem.Unity__c;
                newItem.Stock__c = oldItem.Stock__c;
                newItem.Product2Id = oldItem.Product2Id;
                newItem.PorSurtir__c = oldItem.PorSurtir__c;
                newItem.Surtida__c = oldItem.Surtida__c;
                newItem.SortOrderProducts__c = oldItem.SortOrderProducts__c;
                
          

                newItems.add(newItem);
            } else {
                notFoundProducts.add(oldItem.Product2Id);
            }
        }

        if (!newItems.isEmpty()) {
            insert newItems;
        }

        if (!notFoundProducts.isEmpty()) {
            System.debug('⚠️ Productos no encontrados en la nueva Pricebook: ' + notFoundProducts);
            // throw new FlowException('Algunos productos no se clonaron por no existir en la nueva Pricebook.');
        }
    }

    public class FlowException extends Exception {}
}