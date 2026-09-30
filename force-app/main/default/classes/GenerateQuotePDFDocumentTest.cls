@isTest
public class GenerateQuotePDFDocumentTest {

    @isTest
    static void testCreateQuote() {
        // Crear datos de prueba
        Account testAccount = new Account(
            Name = 'Test Account',
            RFC__c = 'XAXX010101000' // Campo obligatorio corregido
        );
        insert testAccount;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = testAccount.Id
        );
        insert testOpportunity;

        Quote testQuote = new Quote(
            Name = 'Test Quote',
            OpportunityId = testOpportunity.Id,
            Status = 'Draft',
            ExpirationDate = Date.today().addDays(30)
        );
        insert testQuote;

        // Forzar ejecución del método @future
        Test.startTest();
        GenerateQuotePDFDocument.createQuote(new List<Id>{testQuote.Id});
        Test.stopTest();  // 🚀 Esto hace que Salesforce ejecute el método asincrónico antes de seguir

        // Validar que el PDF se haya generado y adjuntado correctamente
        List<ContentVersion> quoteDocs = [SELECT Id, Title, FirstPublishLocationId FROM ContentVersion WHERE FirstPublishLocationId = :testQuote.Id];

        // Asegurar que se generó el archivo PDF correctamente
        System.assert(!quoteDocs.isEmpty(), 'Debe haberse generado un ContentVersion para la cotización.');
        System.assertEquals(testQuote.Id, quoteDocs[0].FirstPublishLocationId, 'El ContentVersion debe estar asociado a la cotización correcta.');
        System.assert(quoteDocs[0].Title.contains('Test Quote'), 'El nombre del archivo PDF debe ser el esperado.');
    }
}