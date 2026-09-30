public class OrderMacoLinesController {
    
    @AuraEnabled(cacheable=false)
    public static Order getOrderInfo(Id orderId) {
        return [
            SELECT Id, OrderNumber, AccountId, Account.Name, OwnerId, Owner.Name, Pricebook2Id, PricebookName__c,
                   Orden_Sin_Cotizacion__c, Warehouse__c, Status, ZF_Pedido_ID__c, EffectiveDate,
                   Method_of_Payment__c, Tipo_Entrega_Venta__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
    }

    @AuraEnabled(cacheable=false)
    public static List<OrderLineWrapper> getOrderLines(Id orderId) {
        String warehouseId = [SELECT Warehouse__c FROM Order WHERE Id = :orderId].Warehouse__c;
    
        List<OrderItem> orderItems = [
            SELECT Id, Product2Id, ProductCode__c, ProductName__c, Quantity, UnitPrice, TotalPrice,
                   Description, ProductoGenerico__c
            FROM OrderItem
            WHERE OrderId = :orderId
            ORDER BY SortOrderProducts__c ASC NULLS LAST, CreatedDate ASC, Id ASC
        ];
    
        Set<Id> productIds = new Set<Id>();
        for (OrderItem item : orderItems) {
            productIds.add(item.Product2Id);
        }
    
        List<ProductWarehouse__c> productsWarehouse = [
            SELECT Id, Existencias__c, Product2__c, Classification__c, Location__c
            FROM ProductWarehouse__c
            WHERE Warehouse__c = :warehouseId AND Product2__c IN :productIds
        ];
    
        Map<Id, ProductWarehouse__c> productWarehouseMap = new Map<Id, ProductWarehouse__c>();
        for (ProductWarehouse__c pw : productsWarehouse) {
            productWarehouseMap.put(pw.Product2__c, pw);
        }
    
        List<OrderLineWrapper> wrapperList = new List<OrderLineWrapper>();
        for (OrderItem item : orderItems) {
            ProductWarehouse__c pw = productWarehouseMap.get(item.Product2Id);
            OrderLineWrapper wrapper = new OrderLineWrapper();
            wrapper.id = item.Id;
            wrapper.productId = item.Product2Id;
            wrapper.productCode = item.ProductCode__c;
            wrapper.productName = item.ProductName__c;
            wrapper.quantity = String.valueOf(item.Quantity);
            wrapper.unitPrice = item.UnitPrice;
            wrapper.totalPrice = item.TotalPrice;
            wrapper.description = item.Description;
            wrapper.productoGenerico = item.ProductoGenerico__c;
            wrapper.existencias = pw?.Existencias__c;
            wrapper.classification = pw?.Classification__c;
            wrapper.location = pw?.Location__c;
            wrapperList.add(wrapper);
        }
    
        return wrapperList;
    }


    @AuraEnabled(cacheable=false)
    public static Boolean updateOrderWarehouse(Id orderId, Id warehouseId) {
        Order ord = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        if (ord.Status != 'Draft') {
            throw newAuraException('Solo puedes cambiar el almacén mientras el pedido está en Borrador.');
        }
        Integer lineCount = [SELECT COUNT() FROM OrderItem WHERE OrderId = :orderId];
        if (lineCount > 0) {
            throw newAuraException('No puedes cambiar el almacén: el pedido ya tiene productos agregados.');
        }
        ord.Warehouse__c = warehouseId;
        update ord;
        return true;
    }

    @AuraEnabled(cacheable=false)
    public static Boolean updateOrderHeaderFields(Id orderId, String methodOfPayment, Date effectiveDate, String tipoEntrega) {
        Order ord = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        if (ord.Status != 'Draft') {
            throw newAuraException('Solo puedes editar estos datos mientras el pedido está en Borrador.');
        }
        ord.Method_of_Payment__c = methodOfPayment;
        ord.EffectiveDate = effectiveDate;
        ord.Tipo_Entrega_Venta__c = tipoEntrega;
        update ord;
        return true;
    }

    private static AuraHandledException newAuraException(String message){
        AuraHandledException ahe = new AuraHandledException(message);
        ahe.setMessage(message);
        return ahe;
    }

    @AuraEnabled(cacheable=false)
    public static Boolean insertOrderLines(String jsonString) {
        System.debug('OrderMacoLinesController.insertOrderLines()-jsonString: ' + jsonString);
        try {
            List<OrdersMacoItem> items = (List<OrdersMacoItem>) JSON.deserialize(jsonString, List<OrdersMacoItem>.class);
            if(items.size()>0){
                String pricebookId;
                PricebookEntry peg;
                List<OrderItem> orderLineItems = new List<OrderItem>();

                // Numeracion de partidas.
                //
                // Easy Sort tiene apagado el auto-numerado
                // (aies__Easy_Sort_Order_Settings__c.AutomateSortOrdering = false),
                // asi que las partidas agregadas directo al pedido nacian con
                // SortOrderProducts__c nulo. Solo las convertidas desde una
                // cotizacion traian numero. Resultado: al ordenar por ese campo,
                // lo nuevo caia siempre al final aunque el usuario lo quisiera
                // en otra posicion, y solo se corregia presionando "Ordenar".
                //
                // Aqui se continua la numeracion existente del pedido.
                Decimal siguienteOrden = obtenerSiguienteOrden(items[0].orderId);

                for(OrdersMacoItem item:items){
                    if(pricebookId==null){
                        pricebookId = getPricebookIdFromOrder(item.orderId);
                    }
                    OrderItem newItem = new OrderItem();
                    newItem.SortOrderProducts__c = siguienteOrden;
                    siguienteOrden = siguienteOrden + 1;
                    newItem.Description = item.ProductCode;
                    newItem.OrderId = item.orderId;                     
                    newItem.Quantity = item.quantity;                   
                    newItem.UnitPrice = item.unitPrice;     
                    if(item.generic==false){
                        newItem.Product2Id = item.product2Id;               
                        newItem.PricebookEntryId = item.pricebookEntryId;
                    }            
                    if(item.generic==true){
                        if(peg==null){
                            peg = getGenericProductInfo(pricebookId);
                        }
                        newItem.Product2Id = peg.Product2Id;
                        newItem.PricebookEntryId = peg.Id;
                    }
                    orderLineItems.add(newItem);
                }
                if(orderLineItems.size()>0){
                    System.debug('OrderMacoLinesController.insertOrderLines()-orderLineItems: ' + orderLineItems);
                    insert orderLineItems;
                }
            }
            return true;
        } catch (Exception e) {
            System.debug('Error in insertOrderLines: ' + e.getMessage());
            throw newAuraException(e.getMessage());
        }
    }

    /**
     * Devuelve el numero que le toca a la siguiente partida del pedido:
     * el mayor SortOrderProducts__c existente + 1, o 1 si no hay ninguno.
     */
    private static Decimal obtenerSiguienteOrden(String orderId){
        if(String.isBlank(orderId)){
            return 1;
        }
        List<OrderItem> ultimo = [
            SELECT SortOrderProducts__c
            FROM OrderItem
            WHERE OrderId = :orderId
            AND SortOrderProducts__c != null
            ORDER BY SortOrderProducts__c DESC
            LIMIT 1
        ];
        if(ultimo.isEmpty() || ultimo[0].SortOrderProducts__c == null){
            return 1;
        }
        return ultimo[0].SortOrderProducts__c + 1;
    }

    @AuraEnabled(cacheable=false)
    public static Boolean updateOrderLines(String jsonString){
        List<OrderMacoItemUpdate> itemsUpdate = (List<OrderMacoItemUpdate>) JSON.deserialize(jsonString, List<OrderMacoItemUpdate>.class);
        List<OrderItem> recordsToUpdate = new List<OrderItem>();
        for(OrderMacoItemUpdate item:itemsUpdate){
            OrderItem lineItem = new OrderItem();
            lineItem.Id = item.id;
            lineItem.Quantity = Decimal.valueOf(item.quantity);
            lineItem.UnitPrice= item.unitPrice;
            if (!String.isBlank(item.description)) {
                lineItem.Description = item.description;
            }
            recordsToUpdate.add(lineItem);
        }
        update recordsToUpdate;
        return true;
    }

    @AuraEnabled(cacheable=false)
    public static Boolean deleteListOfOrderLines(String orderLinesDelete){
        List<String> linesToDelete = orderLinesDelete.split(',');
        try {
            List<OrderItem> quoteLines = [SELECT Id FROM OrderItem WHERE Id IN :linesToDelete];
            System.debug('OrderMacoLinesController.deleteListOfOrderLines()-quoteLines: ' + quoteLines);
            delete quoteLines;
            return true;
        } catch (Exception e) {
            System.debug('QuoteMacoLinesController.deleteListOfOrderLines()-Error: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled(cacheable=false)
    public static Boolean deleteAllOrderItems(String orderId){
        System.debug('OrderMacoLinesController.deleteAllOrderItems()-orderId: ' + orderId);
        List<OrderItem> items = [SELECT Id FROM OrderItem WHERE OrderId=:orderId];
        System.debug('OrderMacoLinesController.deleteAllOrderItems()-items: ' + items);
        delete items;
        return true;
    }
   

    /**
     * ---------------
     * Private Helpers
     * ---------------
     */

     private static PricebookEntry getGenericProductInfo(String pricebookId){
        System.debug('OrderMacoLinesController.getGenericProductInfo()-pricebookId: ' + pricebookId);
        PricebookEntry peg = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2.ProductoGenerico__c = true AND Pricebook2Id=:pricebookId LIMIT 1];
        return peg;
    }

    private static Id getPricebookIdFromOrder(String orderId){
        System.debug('OrderMacoLinesController.getPricebookIdFromOrder()-orderId: ' + orderId);
        return [SELECT Id, Pricebook2Id FROM Order WHERE Id =: orderId].Pricebook2Id;
    }

    public class OrderLineWrapper {
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

    public class OrderMacoItemUpdate {
        public String id {get;set;}
        public String quantity {get;set;}
        public Decimal unitPrice {get;set;}
        public Decimal totalPrice {get;set;}
        public String name {get;set;}
        public String description{get;set;}
        public String productCode {get;set;}
    }

    public class OrdersMacoItem{
    	public Decimal quantity{get;set;}
    	public String orderId{get;set;}
    	public String product2Id{get;set;}
    	public String pricebook2Id{get;set;}
    	public String pricebookEntryId{get;set;}
    	public Decimal unitPrice{get;set;}
    	public String description{get;set;}
        public Boolean generic {get;set;}
        public String productCode {get;set;}
    }
}