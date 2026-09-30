public class QuoteLineItemTriggerHandler extends TriggerHandler {

    private static Boolean hasRun = false; // Static variable to prevent recursion
    
    private Map<Id, QuoteLineItem> newQuoteLineItemMap;
    private Map<Id, QuoteLineItem> oldQuoteLineItemMap;
    private List<QuoteLineItem> newQuoteLineItems;
    private List<QuoteLineItem> oldQuoteLineItems;

    public QuoteLineItemTriggerHandler() {
        this.newQuoteLineItemMap = (Map<Id, QuoteLineItem>) Trigger.newMap;
        this.oldQuoteLineItemMap = (Map<Id, QuoteLineItem>) Trigger.oldMap;
        this.newQuoteLineItems = (List<QuoteLineItem>) Trigger.new;
        this.oldQuoteLineItems = (List<QuoteLineItem>) Trigger.old;
    }
    
    public override void afterUpdate() {
        if (!hasRun) {
            hasRun = true;
            validateExistencias();
        }
    }
    
    private void validateExistencias(){
        Set<Id> quoteIds = new Set<Id>();
        for (QuoteLineItem item : this.newQuoteLineItems) {
            if (item.QuoteId != null) {
                quoteIds.add(item.QuoteId);
            }
        }
        for (Id quoteId : quoteIds) {
            ObtenerExistencias.updateExistenciasInQuote(quoteId);
        }
    }
}