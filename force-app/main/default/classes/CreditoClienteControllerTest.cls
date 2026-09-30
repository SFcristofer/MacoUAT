@IsTest
public class CreditoClienteControllerTest {

    @TestSetup
    static void setupTestData() {
        insert new Account(
            Name = 'Cliente Con Credito Test',
            RFC__c = 'XAXX010101000',
            ZF_Cliente_ID__c = Decimal.valueOf('123456'),
            LimitedeCredito__c = 100000
        );

        insert new Account(
            Name = 'Cliente Sin Zafiro Test',
            RFC__c = 'XAXX010101000',
            LimitedeCredito__c = 50000
        );
    }

    @IsTest
    static void testGetCreditoDisponibleConSaldos() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Account acc = [SELECT Id FROM Account WHERE Name = 'Cliente Con Credito Test' LIMIT 1];

        Test.startTest();
        CreditoClienteController.CreditoInfo info = CreditoClienteController.getCreditoDisponible(acc.Id);
        Test.stopTest();

        System.assertEquals(100000, info.limiteCredito, 'Debe traer el limite de credito de la cuenta');
        System.assertEquals(62780.30, info.saldoActual, 'Debe sumar el SaldoActual de todos los documentos del mock');
        System.assertEquals(100000 - 62780.30, info.creditoDisponible, 'Credito disponible = limite - saldo actual');
        System.assertEquals(null, info.errorMessage);
    }

    @IsTest
    static void testGetCreditoDisponibleSinZafiroId() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Cliente Sin Zafiro Test' LIMIT 1];

        Test.startTest();
        CreditoClienteController.CreditoInfo info = CreditoClienteController.getCreditoDisponible(acc.Id);
        Test.stopTest();

        System.assertEquals(50000, info.limiteCredito);
        System.assertNotEquals(null, info.errorMessage, 'Sin ZF_Cliente_ID__c debe reportar error sin romper');
        System.assertEquals(null, info.creditoDisponible);
    }
}