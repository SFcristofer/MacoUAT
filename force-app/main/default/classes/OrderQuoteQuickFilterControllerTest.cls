@IsTest
public class OrderQuoteQuickFilterControllerTest {

    @TestSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'Cuenta Filtro Uno', RFC__c = 'XAXX010101000', AccountNumber = 'ACC-001'),
            new Account(Name = 'Cuenta Filtro Dos', RFC__c = 'XAXX010101000', AccountNumber = 'ACC-002')
        };
        insert accounts;

        Id standardPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPbId, IsActive = true);

        List<Order> orders = new List<Order>{
            new Order(
                AccountId = accounts[0].Id,
                Status = 'Draft',
                Method_of_Payment__c = 'Crédito',
                EffectiveDate = Date.today(),
                Pricebook2Id = standardPbId,
                Estatus_Facturacion__c = 'Facturado'
            ),
            new Order(
                AccountId = accounts[1].Id,
                Status = 'Draft',
                Method_of_Payment__c = 'Contado',
                EffectiveDate = Date.today().addDays(-5),
                Pricebook2Id = standardPbId,
                Estatus_Facturacion__c = 'Por Facturar'
            )
        };
        insert orders;

        orders[0].Status = 'Authorized';
        orders[0].ByPassValidation__c = true;
        update orders;

        Opportunity opp = new Opportunity(
            Name = 'Opp Filtro Test',
            AccountId = accounts[0].Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opp;

        insert new Quote(
            Name = 'Quote Filtro Test',
            OpportunityId = opp.Id,
            Status = 'Accepted',
            Method_of_Payment__c = 'Crédito'
        );
    }

    @IsTest
    static void testGetFilteredRecordsOrderNoFilters() {
        Test.startTest();
        OrderQuoteQuickFilterController.FilterResult result = OrderQuoteQuickFilterController.getFilteredRecords('Order', null, 10, 0);
        Test.stopTest();

        System.assertEquals(2, result.records.size(), 'Debe traer las 2 Orders creadas');
        System.assertEquals(2, result.totals.recordCount);
    }

    @IsTest
    static void testGetFilteredRecordsOrderByStatus() {
        Map<String, Object> filters = new Map<String, Object>{
            'status' => new List<String>{ 'Authorized' }
        };

        Test.startTest();
        OrderQuoteQuickFilterController.FilterResult result = OrderQuoteQuickFilterController.getFilteredRecords('Order', filters, 10, 0);
        Test.stopTest();

        System.assertEquals(1, result.records.size(), 'Solo debe traer la Order Authorized');
        System.assertEquals('Authorized', result.records[0].status);
    }

    @IsTest
    static void testGetFilteredRecordsOrderByAccountNameText() {
        Map<String, Object> filters = new Map<String, Object>{
            'accountName' => 'Filtro Uno'
        };

        Test.startTest();
        OrderQuoteQuickFilterController.FilterResult result = OrderQuoteQuickFilterController.getFilteredRecords('Order', filters, 10, 0);
        Test.stopTest();

        System.assertEquals(1, result.records.size());
        System.assertEquals('Cuenta Filtro Uno', result.records[0].accountName);
    }

    @IsTest
    static void testGetFilteredRecordsQuote() {
        Test.startTest();
        OrderQuoteQuickFilterController.FilterResult result = OrderQuoteQuickFilterController.getFilteredRecords('Quote', null, 10, 0);
        Test.stopTest();

        System.assertEquals(1, result.records.size());
        System.assertEquals('Accepted', result.records[0].status);
    }

    @IsTest
    static void testGetFilteredRecordsRejectsInvalidObject() {
        Boolean threw = false;
        try {
            OrderQuoteQuickFilterController.getFilteredRecords('Contact', null, 10, 0);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Debe rechazar objetos fuera de la whitelist');
    }

    @IsTest
    static void testGetPicklistOptionsStatus() {
        Test.startTest();
        List<OrderQuoteQuickFilterController.PicklistOption> options =
            OrderQuoteQuickFilterController.getPicklistOptions('Order', 'status');
        Test.stopTest();

        System.assert(!options.isEmpty(), 'Debe traer valores activos del picklist Status');
    }

    @IsTest
    static void testGetPicklistOptionsRejectsInvalidKey() {
        Boolean threw = false;
        try {
            OrderQuoteQuickFilterController.getPicklistOptions('Order', 'accountName');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'Debe rechazar logicalFieldKey fuera de la whitelist de picklists');
    }

    // Se prueba con estatusFacturacion (Text simple en Order) en vez de ownerName:
    // ownerName viaja por Owner.Name, y en contexto de test @TestSetup el Owner
    // (el propio usuario que corre el test) resuelve null vía relación salvo con
    // SeeAllData=true, que no es compatible con clases que usan @TestSetup. La
    // lógica de getDistinctValues es genérica por campo, así que cubre lo mismo.
    @IsTest
    static void testGetDistinctValuesEstatusFacturacion() {
        Test.startTest();
        List<String> values = OrderQuoteQuickFilterController.getDistinctValues('Order', 'estatusFacturacion', null);
        Test.stopTest();

        System.assertEquals(2, values.size(), 'Debe traer los 2 valores distintos de Estatus_Facturacion__c creados');
        System.assert(values.contains('Facturado'));
        System.assert(values.contains('Por Facturar'));
    }

    @IsTest
    static void testGetDistinctValuesWithSearchTermFiltersOut() {
        Test.startTest();
        List<String> matching = OrderQuoteQuickFilterController.getDistinctValues('Order', 'estatusFacturacion', 'Facturado');
        List<String> nonMatching = OrderQuoteQuickFilterController.getDistinctValues('Order', 'estatusFacturacion', 'zzz_no_deberia_existir_zzz');
        Test.stopTest();

        System.assertEquals(1, matching.size(), '"Facturado" solo debe matchear el valor exacto "Facturado", no "Por Facturar"');
        System.assertEquals(0, nonMatching.size(), 'Un término que no matchea con nada debe traer lista vacía');
    }

    @IsTest
    static void testGetDistinctValuesRejectsInvalidKey() {
        Boolean threw = false;
        try {
            OrderQuoteQuickFilterController.getDistinctValues('Order', 'status', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'status es picklist real, no debe aceptarse en getDistinctValues');
    }
}