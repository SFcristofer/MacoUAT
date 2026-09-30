@isTest
private class UpdateContentNoteTest {

    @isTest
    static void testTrigger() {
        Test.startTest();

        // ✅ 1. Crear una Cuenta de prueba con los campos obligatorios
        Account testAccount = new Account(Name = 'Test Account', RFC__c = 'XAXX010101000');
        insert testAccount;

        // ✅ 2. Obtener la Pricebook estándar
        Id standardPBId = Test.getStandardPricebookId();

        // ✅ 3. Crear una Oportunidad
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = standardPBId,
            AccountId = testAccount.Id
        );
        insert testOpp;

        // ✅ 4. Crear una Cotización relacionada con la Oportunidad
        Quote testQuote = new Quote(
            Name = 'Test Quote',
            Status = 'Draft',
            OpportunityId = testOpp.Id
        );
        insert testQuote;

        // ✅ 5. Crear una `ContentNote` correctamente
        ContentNote testNote = new ContentNote(
            Title = 'Test Note',
            Content = Blob.valueOf('Contenido de prueba'),
            OwnerId = UserInfo.getUserId()  // ⚠️ Asegurar que tiene un propietario
        );
        insert testNote;

        // ✅ 6. Recuperar el `ContentDocumentId` generado
        ContentDocument testDocument = [SELECT Id FROM ContentDocument WHERE Id = :testNote.Id LIMIT 1];

        // ✅ 7. Relacionar la `ContentNote` con la `Quote`
        ContentDocumentLink noteLink = new ContentDocumentLink(
            ContentDocumentId = testDocument.Id, // ⚠️ Usar `ContentDocument.Id`, NO `ContentNote.Id`
            LinkedEntityId = testQuote.Id,
            ShareType = 'V',
            Visibility = 'AllUsers' // ⚠️ Evita restricciones de permisos
        );
        insert noteLink;

        // ✅ 8. Crear una Orden con `QuoteId`
        Order testOrder = new Order(
            Name = 'Test Order',
            AccountId = testAccount.Id,
            Status = 'Draft', // ⚠️ Inicialmente "Draft"
            EffectiveDate = Date.today(),
            QuoteId = testQuote.Id
        );
        insert testOrder;

        // ✅ 9. Validar que la `ContentDocumentLink` se creó correctamente para la Orden
        List<ContentDocumentLink> orderLinks = [SELECT Id FROM ContentDocumentLink WHERE LinkedEntityId = :testOrder.Id];
        System.assertEquals(1, orderLinks.size(), 'Debe haber una nota asociada a la Orden.');

        Test.stopTest();
    }
}