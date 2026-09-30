@IsTest
public class SalesMacoSearchControllerTest {

    @TestSetup
    static void setupTestData() {
        // Pricebooks
        Id standardPbId = Test.getStandardPricebookId();
        Pricebook2 standardPb = new Pricebook2(
            Id = standardPbId,
            IsActive = true,
            ExternalId__c = 'STD'
        );
        update standardPb;

        Pricebook2 customPb = new Pricebook2(
            Name = 'Custom Pricebook',
            IsActive = true,
            ExternalId__c = 'PB_1'
        );
        insert customPb;

        // Products
        Product2 product1 = new Product2(
            Name = 'Generic Product',
            IsActive = true,
            ProductoGenerico__c = true,
            ExternalId__c = 'CA_1'
        );
        Product2 product2 = new Product2(
            Name = 'Non-Generic Product',
            ProductCode = 'CODE-99',
            IsActive = true,
            ProductoGenerico__c = false,
            ExternalId__c = 'CA_2'
        );
        insert new List<Product2>{ product1, product2 };

        // NOTA: no insertamos PricebookEntry manualmente. El flow activo
        // "ST_Maco_ProductCreation" (RecordAfterSave en Product2, sin filtro de entrada)
        // ya crea automáticamente una PricebookEntry por cada Pricebook2 activo
        // (Standard incluido) para todo Product2 recién insertado. Insertarlas aquí
        // también duplicaba el registro y hacía fallar el setup con DUPLICATE_VALUE.
        // Las entries auto-creadas quedan IsActive=true y UnitPrice=1, suficiente
        // para los asserts de estos tests (no dependen de un UnitPrice específico).

        // Warehouse
        Warehouse__c wh = new Warehouse__c(Name = 'Main WH', Code__c = 'WH001');
        insert wh;

        // ProductWarehouse - existencias para los productos
        ProductWarehouse__c stock1 = new ProductWarehouse__c(
            Product2__c = product1.Id,
            Warehouse__c = wh.Id,
            Existencias__c = 10
        );
        ProductWarehouse__c stock2 = new ProductWarehouse__c(
            Product2__c = product2.Id,
            Warehouse__c = wh.Id,
            Existencias__c = 20
        );
        insert new List<ProductWarehouse__c>{ stock1, stock2 };
    }

    @IsTest
    static void testGetPricebookInfo() {
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Custom Pricebook' LIMIT 1];
        Pricebook2 result = SalesMacoSearchController.getPricebookInfo(pb.Id);
        System.assertEquals(pb.Id, result.Id);
    }

    @IsTest
    static void testGetAllPricebookEntries() {
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Custom Pricebook' LIMIT 1];
        Warehouse__c wh = [SELECT Id FROM Warehouse__c WHERE Code__c = 'WH001' LIMIT 1];

        List<SalesMacoSearchController.ProductInformation> results = 
            SalesMacoSearchController.getAllPricebookEntries(pb.Id, wh.Id, true);

        System.assertNotEquals(0, results.size(), 'Debe retornar productos del pricebook custom');
    }

    @IsTest
    static void testGetPricebookEntriesFiltered() {
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Custom Pricebook' LIMIT 1];
        Warehouse__c wh = [SELECT Id FROM Warehouse__c WHERE Code__c = 'WH001' LIMIT 1];

        // Usamos 'Product' como searchTerm porque matchea con ambos productos
        List<SalesMacoSearchController.ProductInformation> results =
            SalesMacoSearchController.getPricebookEntriesFiltered(pb.Id, wh.Id, 'Product', true);

        System.assertNotEquals(0, results.size(), 'Debe encontrar productos con el término de búsqueda');
    }

    @IsTest
    static void testGetPricebookEntriesFilteredByProductCode() {
        Pricebook2 pb = [SELECT Id FROM Pricebook2 WHERE Name = 'Custom Pricebook' LIMIT 1];
        Warehouse__c wh = [SELECT Id FROM Warehouse__c WHERE Code__c = 'WH001' LIMIT 1];

        // 'CODE-99' no aparece en Name, solo en ProductCode del producto no-genérico
        List<SalesMacoSearchController.ProductInformation> results =
            SalesMacoSearchController.getPricebookEntriesFiltered(pb.Id, wh.Id, 'CODE-99', true);

        System.assertEquals(1, results.size(), 'Debe encontrar el producto por su ProductCode aunque no aparezca en Name');
        System.assertEquals('CODE-99', results[0].productCode);
    }
}