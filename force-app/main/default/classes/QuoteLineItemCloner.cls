public with sharing class QuoteLineItemCloner {

    public class CloneQLIRequest {
        @InvocableVariable(required=true)
        public Id originalQuoteId;

        @InvocableVariable(required=true)
        public Id newQuoteId;
    }

    @InvocableMethod(label='Clonar QLIs a un nuevo presupuesto')
    public static void cloneQuoteLineItems(List<CloneQLIRequest> requests) {
        for (CloneQLIRequest req : requests) {
            try {
                cloneQLIs(req.originalQuoteId, req.newQuoteId);
            } catch (Exception ex) {
                System.debug('🛑 Error al clonar QLIs: ' + ex.getMessage());
                throw new FlowException('Error al clonar los productos del presupuesto: ' + ex.getMessage());
            }
        }
    }

    private static void cloneQLIs(Id originalQuoteId, Id newQuoteId) {
        if (originalQuoteId == null || newQuoteId == null) {
            throw new FlowException('IDs del presupuesto original o nuevo no pueden ser nulos.');
        }

        // 1. Obtener QLIs del presupuesto original
        List<QuoteLineItem> originalQLIs = [
            SELECT Product2Id, Quantity, Discount, Description,Location__c,Classification__c,Stock__c,Commited__c,Unity__c,aies__CustomSortOrder__c,ToBeDelivered__c,ToBeSupplied__c,OpportunityLineItemId
            FROM QuoteLineItem
            WHERE QuoteId = :originalQuoteId
            ORDER BY aies__CustomSortOrder__c ASC NULLS LAST, LineNumber ASC, Id ASC
        ];

        if (originalQLIs.isEmpty()) {
            throw new FlowException('El presupuesto original no tiene productos cargados.');
        }

        // 2. Obtener Pricebook del nuevo presupuesto
        Quote newQuote = [
            SELECT Pricebook2Id FROM Quote WHERE Id = :newQuoteId
        ];

        if (newQuote.Pricebook2Id == null) {
            throw new FlowException('El nuevo presupuesto no tiene una lista de precios asignada.');
        }

        // 3. Obtener PricebookEntries en la nueva Pricebook
        Set<Id> productIds = new Set<Id>();
        for (QuoteLineItem qli : originalQLIs) {
            productIds.add(qli.Product2Id);
        }

        Map<Id, PricebookEntry> pricebookEntryMap = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :newQuote.Pricebook2Id
            AND Product2Id IN :productIds
        ]) {
            pricebookEntryMap.put(pbe.Product2Id, pbe);
        }

        // 4. Construir QLIs clonados usando método desacoplado
        List<QuoteLineItem> newQLIs = buildClonedQLIs(originalQLIs, pricebookEntryMap, newQuoteId);

        if (!newQLIs.isEmpty()) {
            insert newQLIs;
        }

        // Opcional: log de productos no encontrados
        List<Id> notFoundProducts = new List<Id>();
        for (QuoteLineItem oldQLI : originalQLIs) {
            if (!pricebookEntryMap.containsKey(oldQLI.Product2Id)) {
                notFoundProducts.add(oldQLI.Product2Id);
            }
        }

        if (!notFoundProducts.isEmpty()) {
            System.debug('⚠️ Productos no encontrados en la nueva Pricebook: ' + notFoundProducts);
        }
    }

    // 🔧 Lógica desacoplada y testeable
    public static List<QuoteLineItem> buildClonedQLIs(
        List<QuoteLineItem> originalQLIs,
        Map<Id, PricebookEntry> productToPBE,
        Id newQuoteId
    ) {
        List<QuoteLineItem> newQLIs = new List<QuoteLineItem>();

        for (QuoteLineItem oldQLI : originalQLIs) {
            if (productToPBE.containsKey(oldQLI.Product2Id)) {
                PricebookEntry pbe = productToPBE.get(oldQLI.Product2Id);

                QuoteLineItem newQLI = new QuoteLineItem();
              	newQLI.QuoteId = newQuoteId;
                newQLI.PricebookEntryId = pbe.Id;
                newQLI.Quantity = oldQLI.Quantity;
                newQLI.UnitPrice = pbe.UnitPrice;
                newQLI.Discount = oldQLI.Discount;
                newQLI.Description = oldQLI.Description;
                newQLI.Location__c = oldQLI.Location__c;
                newQLI.Classification__c = oldQLI.Classification__c;
                newQLI.Commited__c = oldQLI.Commited__c;
                newQLI.Discount = oldQLI.Discount;
                newQLI.Stock__c = oldQLI.Stock__c;
                newQLI.aies__CustomSortOrder__c = oldQLI.aies__CustomSortOrder__c;
                newQLI.OpportunityLineItemId = oldQLI.OpportunityLineItemId;
                newQLI.Product2Id = oldQLI.Product2Id;
                newQLI.ToBeDelivered__c = oldQLI.ToBeDelivered__c;
                newQLI.ToBeSupplied__c = oldQLI.ToBeSupplied__c;

                newQLIs.add(newQLI);
            }
        }

        return newQLIs;
    }

    public class FlowException extends Exception {}
}