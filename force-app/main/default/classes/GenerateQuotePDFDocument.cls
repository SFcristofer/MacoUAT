public class GenerateQuotePDFDocument {

    @InvocableMethod
    public static void createQuote(List<Id> quoteIds) { 
        createQuoteFutureMethod(quoteIds);
    }

    @future(callout=true)
    public static void createQuoteFutureMethod(List<Id> quoteIds) {
        List<ContentVersion> lstContentVersions = new List<ContentVersion>();

        if (!quoteIds.isEmpty()) {
            // Obtener numeros de las cotizaciones
            Map<Id, String> quoteNumbers = new Map<Id, String>();
            for (Quote q : [SELECT Id, QuoteNumber FROM Quote WHERE Id IN :quoteIds]) {
                quoteNumbers.put(q.Id, q.QuoteNumber);
            }

            for (Id quoteId : quoteIds) {
                if (!quoteNumbers.containsKey(quoteId)) continue;

                // Formato nuevo (#58): misma página que el PDF de pedido, adaptada a cotización
                PageReference pageRef = Page.QuotePDF;
                pageRef.getParameters().put('id', quoteId);
                Blob quoteBlob = Test.isRunningTest() ? Blob.valueOf('Generate Pdf') : pageRef.getContentAsPDF();

                // Contar cuántos archivos de cotización ya existen para poner el _VX
                List<ContentDocumentLink> existingLinks = [
                    SELECT ContentDocument.Title FROM ContentDocumentLink 
                    WHERE LinkedEntityId = :quoteId
                ];
                
                String qNum = quoteNumbers.get(quoteId);
                Integer versionCount = 0;
                
                for(ContentDocumentLink link : existingLinks) {
                    if (link.ContentDocument.Title != null && link.ContentDocument.Title.contains(qNum)) {
                        versionCount++;
                    }
                }
                
                Integer nextVersion = versionCount + 1;
                String fileName = qNum + '_V' + nextVersion + '.pdf';

                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = quoteBlob;
                cv.FirstPublishLocationId = quoteId; 
                
                lstContentVersions.add(cv);
            }
        }

        if (!lstContentVersions.isEmpty()) {
            insert lstContentVersions;
        }
    }
}