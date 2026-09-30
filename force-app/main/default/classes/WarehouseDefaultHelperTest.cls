@IsTest
public class WarehouseDefaultHelperTest {

    @TestSetup
    static void setupTestData() {
        insert new List<Warehouse__c>{
            new Warehouse__c(Name = 'Almacen Default Test', Code__c = '001'),
            new Warehouse__c(Name = 'Almacen Veracruz Test', Code__c = '007')
        };

        insert new Account(Name = 'Cliente Warehouse Default Test', RFC__c = 'XAXX010101000');
    }

    @IsTest
    static void testOrderWithoutTerritorioFallsBackToDefaultWarehouse() {
        WarehouseDefaultHelper.resetCache();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Warehouse__c defaultWh = [SELECT Id FROM Warehouse__c WHERE Code__c = '001' LIMIT 1];

        Test.startTest();
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = System.today()
        );
        insert ord;
        Test.stopTest();

        Order inserted = [SELECT Warehouse__c FROM Order WHERE Id = :ord.Id];
        System.assertEquals(defaultWh.Id, inserted.Warehouse__c, 'Sin Territorio__c debe caer al almacén default (001)');
    }

    @IsTest
    static void testOrderRespectsWarehouseAlreadySet() {
        WarehouseDefaultHelper.resetCache();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Warehouse__c veracruzWh = [SELECT Id FROM Warehouse__c WHERE Code__c = '007' LIMIT 1];

        Test.startTest();
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = System.today(),
            Warehouse__c = veracruzWh.Id
        );
        insert ord;
        Test.stopTest();

        Order inserted = [SELECT Warehouse__c FROM Order WHERE Id = :ord.Id];
        System.assertEquals(veracruzWh.Id, inserted.Warehouse__c, 'No debe sobreescribir un Warehouse__c ya definido');
    }

    @IsTest
    static void testOrderWithVeracruzTerritorioResolvesVeracruzWarehouse() {
        WarehouseDefaultHelper.resetCache();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Warehouse__c veracruzWh = [SELECT Id FROM Warehouse__c WHERE Code__c = '007' LIMIT 1];

        User runningUser = [SELECT Id, Territorio__c FROM User WHERE Id = :UserInfo.getUserId()];
        runningUser.Territorio__c = 'Veracruz';
        update runningUser;

        Test.startTest();
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = System.today()
        );
        insert ord;
        Test.stopTest();

        Order inserted = [SELECT Warehouse__c FROM Order WHERE Id = :ord.Id];
        System.assertEquals(veracruzWh.Id, inserted.Warehouse__c, 'Usuario con Territorio__c=Veracruz debe resolver al almacén 007');
    }
}