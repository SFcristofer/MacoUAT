public class ProductTriggerHandler extends TriggerHandler {
    
    private Map<Id, Product2> newProdMap;
    private List<Product2> newProdList;
    
	public ProductTriggerHandler() {
    	this.newProdMap = (Map<Id, Product2>) Trigger.newMap;
        this.newProdList = (List<Product2>) Trigger.new;
  	}

    /** ---------------- */
    /** Context Handling */
    /** ---------------- */
    
  	public override void beforeInsert() {
        validateGenericProduct();
  	}

    public override void beforeUpdate(){
        keepGenericProductActive();
    }

    /** --------------- */
    /** Private helpers */
    /** --------------- */

    private void keepGenericProductActive(){
        for(Product2 p:(List<Product2>)Trigger.new){
            if(p.ProductoGenerico__c){
                p.IsActive = true;
            }
        }
    }
    
    private void validateGenericProduct() {
        if(this.newProdList.size()>0){
            for(Product2 newProd:this.newProdList){
                if(newProd.ProductoGenerico__c){
                    if([SELECT Id FROM Product2 WHERE ProductoGenerico__c=true LIMIT 1].size()>0){
                       	newProd.ProductoGenerico__c.addError('Ya existe un producto generico');
                    }
                }
            }
        }
    }
}