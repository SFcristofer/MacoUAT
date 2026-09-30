public class OrderItemTriggerHandler extends TriggerHandler {
    
    private static Boolean hasRun = false; // Static variable to prevent recursion

    private Map<Id, OrderItem> newOrderItemMap;
    private Map<Id, OrderItem> oldOrderItemMap;
    private List<OrderItem> newOrderItems;
    private List<OrderItem> oldOrderItems;

    public OrderItemTriggerHandler() {
        this.newOrderItemMap = (Map<Id, OrderItem>) Trigger.newMap;
        this.oldOrderItemMap = (Map<Id, OrderItem>) Trigger.oldMap;
        this.newOrderItems = (List<OrderItem>) Trigger.new;
        this.oldOrderItems = (List<OrderItem>) Trigger.old;
    }
}
    
  //  public override void afterUpdate() {
    //	if (!hasRun) {
        //    hasRun = true;
       //     validateExistencias();
    //    }
 // 	}
    
  //  private void validateExistencias(){
     //   Set<Id> orderIds = new Set<Id>();
     //   for (OrderItem item : this.newOrderItems) {
       //     if (item.OrderId != null) {
       //         orderIds.add(item.OrderId);
         //   }
    //    }
   //     for (Id orderId : orderIds) {
       //     ObtenerExistencias.updateExistenciasInOrder(orderId);
    //    }
  //  }
//}