@IsTest
public class OrderMacoLinesControllerTest {
   @TestSetup
	static void setupTestData() {
    	
    	Id pricebookId = Test.getStandardPricebookId();
		Pricebook2 standardPricebook = new Pricebook2(
    		Id = pricebookId,
    		IsActive = true,
            ExternalId__c = 'STD'
		);
		update standardPricebook;
    	System.debug('Standard Pricebook Id: ' + standardPricebook.Id);

    	// Create a Custom Pricebook
    	Pricebook2 pb = new Pricebook2(
    	    Name = 'Test Pricebook',
    	    IsActive = true,
    	    ExternalId__c = 'TEST_PB'
    	);
    	insert pb;
    	System.debug('Custom Pricebook Id: ' + pb.Id);

    	// Create a Product
    	Product2 product = new Product2(
        	Name = 'Test Product',
        	IsActive = true,
        	ExternalId__c = 'TEST_PRODUCT'
    	);
    	insert product;
    	System.debug('Product Id: ' + product.Id);

    	// NOTA: no insertamos PricebookEntry manualmente. El flow activo
    	// "ST_Maco_ProductCreation" (RecordAfterSave en Product2, sin filtro de entrada)
    	// ya crea automáticamente una PricebookEntry por cada Pricebook2 activo para todo
    	// Product2 recién insertado. Insertarlas aquí también duplicaba el registro y
    	// hacía fallar el setup con DUPLICATE_VALUE. Solo ajustamos el UnitPrice de la
    	// entry auto-creada en el pricebook custom.
    	PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :product.Id AND Pricebook2Id = :pb.Id LIMIT 1];
    	pbe.UnitPrice = 100;
    	update pbe;
    	System.debug('Custom PricebookEntry Id: ' + pbe.Id);

        Account acc = new Account();
        acc.Name = 'TEST_ACCOUNT';
        acc.RFC__c ='XAXX010101000';
        insert acc;
        System.debug('Account: '+ acc.id);
        
    	// Create an Order
    	Order order = new Order(
        	AccountId = [SELECT Id FROM Account LIMIT 1].Id,
        	EffectiveDate = System.today(),
        	Status = 'Draft',
        	Pricebook2Id = pb.Id
    	);
    	insert order;
    	System.debug('Order Id: ' + order.Id);

    	// Create Order Items
    	OrderItem orderItem = new OrderItem(
        	OrderId = order.Id,
        	PricebookEntryId = pbe.Id,
        	Quantity = 1,
        	UnitPrice = 100
    	);
    	insert orderItem;
    	System.debug('OrderItem Id: ' + orderItem.Id);
}


    @IsTest
    static void testGetOrderInfo() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        Order result = OrderMacoLinesController.getOrderInfo(order.Id);
        Test.stopTest();
    }

    @IsTest
    static void testGetOrderLines() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
List<OrderMacoLinesController.OrderLineWrapper> result = OrderMacoLinesController.getOrderLines(order.Id);
        Test.stopTest();
    }

    @IsTest
    static void testInsertOrderLines() {
        Order order = [SELECT Id, Pricebook2Id FROM Order LIMIT 1];
        Product2 product = [SELECT Id FROM Product2 LIMIT 1];
        // La PricebookEntry DEBE ser la de la lista del pedido. Sin el filtro
        // por Pricebook2Id, la consulta podia devolver la entrada de la lista
        // estandar mientras el pedido usa la lista personalizada, y el insert
        // fallaba con INVALID_CROSS_REFERENCE_KEY. El setup no inserta las
        // PricebookEntry a mano: las crea el flow ST_Maco_ProductCreation, y
        // por eso el mismo producto vive en mas de una lista.
        PricebookEntry pbe = [
            SELECT Id
            FROM PricebookEntry
            WHERE Product2Id = :product.Id
            AND Pricebook2Id = :order.Pricebook2Id
            LIMIT 1
        ];

        OrderMacoLinesController.OrdersMacoItem item = new OrderMacoLinesController.OrdersMacoItem();
        item.quantity = 2;
        item.orderId = order.Id;
        item.product2Id = product.Id;
        item.pricebookEntryId = pbe.Id;
        item.unitPrice = 150;
        item.description = 'Test Insert Item';
        item.generic = false;

        List<OrderMacoLinesController.OrdersMacoItem> items = new List<OrderMacoLinesController.OrdersMacoItem>{item};
        String jsonString = JSON.serialize(items);

        Test.startTest();
        Boolean result = OrderMacoLinesController.insertOrderLines(jsonString);
        Test.stopTest();
    }

    @IsTest
    static void testUpdateOrderLines() {
        OrderItem orderItem = [SELECT Id, Quantity, UnitPrice FROM OrderItem LIMIT 1];
        OrderMacoLinesController.OrderMacoItemUpdate updateItem = new OrderMacoLinesController.OrderMacoItemUpdate();
        updateItem.id = orderItem.Id;
        updateItem.quantity = '3';
        updateItem.unitPrice = 120;
        updateItem.totalPrice = 100;
        updateItem.name = 'TEST';
        updateItem.productCode = 'TEST';

        List<OrderMacoLinesController.OrderMacoItemUpdate> itemsUpdate = new List<OrderMacoLinesController.OrderMacoItemUpdate>{updateItem};
        String jsonString = JSON.serialize(itemsUpdate);
        
		Test.startTest();
        Boolean result = OrderMacoLinesController.updateOrderLines(jsonString);
        Test.stopTest();
    }

    @IsTest
    static void testDeleteListOfOrderLines() {
        OrderItem orderItem = [SELECT Id FROM OrderItem LIMIT 1];
        
        Test.startTest();
        Boolean result = OrderMacoLinesController.deleteListOfOrderLines(orderItem.Id);
        Test.stopTest();
    }

    @IsTest
    static void testDeleteAllOrderItems() {
        Order order = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        Boolean result = OrderMacoLinesController.deleteAllOrderItems(order.Id);
        Test.stopTest();
    }
}