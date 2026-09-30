@isTest
private class OrderItemClonerTest {

    @isTest
    static void testCloneOrderItems_success() {
        // Crear cuenta
        Account acct = new Account(Name = 'Test Account', RFC__C ='MCP900601M4A',Phone = '2222239050', Maildecontacto__c = 'test@test.com');
        insert acct;

        // Activar pricebook estándar
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // Crear productos
        Product2 prod = new Product2(Name = 'Producto A', IsActive = true);
        insert prod;

        // Crear pricebook entry en estándar
        PricebookEntry pbeStd = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            ExternalId__c='pbStd'      
        );
        insert pbeStd;

        // Crear pricebooks custom
        Pricebook2 pbOrig = new Pricebook2(Name = 'PB Original', IsActive = true,ExternalId__c='pbOrig');
        Pricebook2 pbDest = new Pricebook2(Name = 'PB Nuevo', IsActive = true,ExternalId__c='pbDest');
        insert new List<Pricebook2>{ pbOrig, pbDest };

        // Crear pricebook entries custom
        PricebookEntry pbeOrig = new PricebookEntry(Pricebook2Id = pbOrig.Id, Product2Id = prod.Id, UnitPrice = 110, IsActive = true,ExternalId__c='pb1');
        PricebookEntry pbeDest = new PricebookEntry(Pricebook2Id = pbDest.Id, Product2Id = prod.Id, UnitPrice = 120, IsActive = true,ExternalId__c='pb2');
        insert new List<PricebookEntry>{ pbeOrig, pbeDest };

        // Crear pedidos
        Order origOrder = new Order(AccountId = acct.Id, Status = 'Draft', EffectiveDate = Date.today(), Pricebook2Id = pbOrig.Id);
        Order destOrder = new Order(AccountId = acct.Id, Status = 'Draft', EffectiveDate = Date.today(), Pricebook2Id = pbDest.Id);
        insert new List<Order>{ origOrder, destOrder };

        // Crear OrderItem en el original
        OrderItem oi = new OrderItem(OrderId = origOrder.Id, Quantity = 2, UnitPrice = 110, PricebookEntryId = pbeOrig.Id);
        insert oi;

        // Ejecutar método
        OrderItemCloner.CloneOrderItemRequest req = new OrderItemCloner.CloneOrderItemRequest();
        req.originalOrderId = origOrder.Id;
        req.newOrderId = destOrder.Id;

        Test.startTest();
        OrderItemCloner.cloneOrderItems(new List<OrderItemCloner.CloneOrderItemRequest>{ req });
        Test.stopTest();

        // Verificar
        List<OrderItem> clonedItems = [SELECT Quantity, UnitPrice FROM OrderItem WHERE OrderId = :destOrder.Id];
        System.assertEquals(1, clonedItems.size());
        System.assertEquals(2, clonedItems[0].Quantity);
        System.assertEquals(120, clonedItems[0].UnitPrice);
    }

    @isTest
    static void testCloneOrderItems_missingProductInPricebook() {
        // Setup básico sin PricebookEntry en destino
        Account acct = new Account(Name = 'Test Account', RFC__C ='MCP900601M4A',Phone = '2222239050', Maildecontacto__c = 'test@test.com');
        insert acct;
        Id stdPbId = Test.getStandardPricebookId(); update new Pricebook2(Id=stdPbId, IsActive=true);
        Product2 prod = new Product2(Name = 'P', IsActive = true); insert prod;
        insert new PricebookEntry(Pricebook2Id = stdPbId,Product2Id = prod.Id,UnitPrice = 0.01,IsActive = true,ExternalId__c='pbestd');
        Pricebook2 pb1 = new Pricebook2(Name='PB1', IsActive=true,ExternalId__c='pbOrig'); Pricebook2 pb2 = new Pricebook2(Name='PB2', IsActive=true,ExternalId__c='pbdest');
        insert new List<Pricebook2>{pb1, pb2};
        PricebookEntry pbe1 = new PricebookEntry(Pricebook2Id = pb1.Id, Product2Id = prod.Id, UnitPrice = 100, IsActive=true,ExternalId__c='pbe1'); insert pbe1;
        Order o1 = new Order(AccountId=acct.Id, Pricebook2Id=pb1.Id, Status='Draft', EffectiveDate=Date.today());
        Order o2 = new Order(AccountId=acct.Id, Pricebook2Id=pb2.Id, Status='Draft', EffectiveDate=Date.today());
        insert new List<Order>{o1, o2};
        insert new OrderItem(OrderId=o1.Id, PricebookEntryId=pbe1.Id, Quantity=1, UnitPrice=100);

        OrderItemCloner.CloneOrderItemRequest req = new OrderItemCloner.CloneOrderItemRequest();
        req.originalOrderId = o1.Id;
        req.newOrderId = o2.Id;

        Test.startTest();
        OrderItemCloner.cloneOrderItems(new List<OrderItemCloner.CloneOrderItemRequest>{ req });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM OrderItem WHERE OrderId = :o2.Id]);
    }

    @isTest
    static void testCloneOrderItems_nullIds() {
        Test.startTest();
        try {
            OrderItemCloner.cloneOrderItems(new List<OrderItemCloner.CloneOrderItemRequest>{
                new OrderItemCloner.CloneOrderItemRequest()
            });
            System.assert(false, 'Se esperaba una excepción por IDs nulos');
        } catch (OrderItemCloner.FlowException e) {
            System.assert(e.getMessage().contains('no pueden ser nulos'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCloneOrderItems_emptyOrderItems() {
     	Account acct = new Account(Name = 'Test Account', RFC__C ='MCP900601M4A',Phone = '2222239050', Maildecontacto__c = 'test@test.com');
        insert acct;
        Pricebook2 pb = new Pricebook2(Name='PB', IsActive=true,ExternalId__c='pbOrig'); 
        insert pb;
        Order o1 = new Order(AccountId=acct.Id, Pricebook2Id=pb.Id, Status='Draft', EffectiveDate=Date.today());
        Order o2 = new Order(AccountId=acct.Id, Pricebook2Id=pb.Id, Status='Draft', EffectiveDate=Date.today());
        insert new List<Order>{o1, o2};

        OrderItemCloner.CloneOrderItemRequest req = new OrderItemCloner.CloneOrderItemRequest();
        req.originalOrderId = o1.Id;
        req.newOrderId = o2.Id;

        Test.startTest();
        try {
            OrderItemCloner.cloneOrderItems(new List<OrderItemCloner.CloneOrderItemRequest>{ req });
            System.assert(false, 'Se esperaba excepción por pedido sin productos');
        } catch (OrderItemCloner.FlowException e) {
            System.assert(e.getMessage().contains('no tiene productos'));
        }
        Test.stopTest();
    }

    @isTest
    static void testCloneOrderItems_noPricebookInTargetOrder() {
      	Account acct = new Account(Name = 'Test Account', RFC__C ='MCP900601M4A',Phone = '2222239050', Maildecontacto__c = 'test@test.com');
        insert acct;
        Id stdPbId = Test.getStandardPricebookId();
        Product2 prod = new Product2(Name='P', IsActive=true); insert prod;
        Pricebook2 pb = new Pricebook2(Name='PB', IsActive=true,ExternalId__c='pb'); insert pb;
        insert new PricebookEntry(Pricebook2Id = stdPbId,Product2Id = prod.Id,UnitPrice = 0.01,IsActive = true,ExternalId__c='pbestd');
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id=pb.Id, Product2Id=prod.Id, UnitPrice=100, IsActive=true,ExternalId__c='pbe'); insert pbe;
        Order o1 = new Order(AccountId=acct.Id, Pricebook2Id=pb.Id, Status='Draft', EffectiveDate=Date.today());
        Order o2 = new Order(AccountId=acct.Id, Status='Draft', EffectiveDate=Date.today());
        insert new List<Order>{o1, o2};
        insert new OrderItem(OrderId=o1.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100);

        OrderItemCloner.CloneOrderItemRequest req = new OrderItemCloner.CloneOrderItemRequest();
        req.originalOrderId = o1.Id;
        req.newOrderId = o2.Id;

        Test.startTest();
        try {
            OrderItemCloner.cloneOrderItems(new List<OrderItemCloner.CloneOrderItemRequest>{ req });
            System.assert(false, 'Se esperaba error por falta de Pricebook en nuevo pedido');
        } catch (OrderItemCloner.FlowException e) {
            System.assert(e.getMessage().contains('no tiene una lista de precios'));
        }
        Test.stopTest();
    }
}