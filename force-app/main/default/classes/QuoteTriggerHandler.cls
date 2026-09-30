public class QuoteTriggerHandler extends TriggerHandler {
    
    private static Boolean hasRun = false; // Static variable to prevent recursion
	
    private Map<Id, Quote> newQuoteMap;
    private Map<Id, Quote> oldQuoteMap;
    private List<Quote> newQuotes;
    private List<Quote> oldQuotes;

  	public QuoteTriggerHandler() {
   		this.newQuoteMap = (Map<Id, Quote>) Trigger.newMap;
        this.oldQuoteMap = (Map<Id, Quote>) Trigger.oldMap;
        this.newQuotes = (List<Quote>) Trigger.new;
        this.oldQuotes = (List<Quote>) Trigger.old;
  	}
    
    public override void beforeInsert() {
        WarehouseDefaultHelper.applyDefaultWarehouse(this.newQuotes);
    }

    public override void afterUpdate() {
    	if (!hasRun) {
            hasRun = true;
            validateExistencias();
        }
  	}
    
    private void validateExistencias(){
        for (Quote quote : this.newQuotes) {
            if (quote.Id != null) {
                ObtenerExistencias.updateExistenciasInQuote(quote.Id);
            }
        }
    }
}