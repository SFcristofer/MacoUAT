public class GenerateQuotePDFDocument {

    @InvocableMethod
    public static void createQuote(List<Id> quoteIds) { 
        createQuoteFutureMethod(quoteIds);
    }

    @future(callout=true)
    public static void createQuoteFutureMethod(List<Id> quoteIds) {
        String quoteUrl = '/quote/quoteTemplateDataViewer.apexp?';
        String quoteTemplateId = Label.quoteTemplateId;
        List<ContentVersion> lstContentVersions = new List<ContentVersion>();

        if (!quoteIds.isEmpty()) {
            // Obtener numeros de las cotizaciones
            Map<Id, String> quoteNumbers = new Map<Id, String>();
            for (Quote q : [SELECT Id, QuoteNumber FROM Quote WHERE Id IN :quoteIds]) {
                quoteNumbers.put(q.Id, q.QuoteNumber);
            }

            for (Id quoteId : quoteIds) {
                if (!quoteNumbers.containsKey(quoteId)) continue;

                String fullQuoteUrl = quoteUrl + 'id=' + quoteId + '&headerHeight=180&footerHeight=10&summlid=' + quoteTemplateId;
                PageReference pageRef = new PageReference(fullQuoteUrl);
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