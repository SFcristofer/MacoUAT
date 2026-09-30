public class OrderTriggerHandler extends TriggerHandler {
    
    private static Boolean hasRun = false; // Static variable to prevent recursion

    private Map<Id, Order> newOrderMap;
    private Map<Id, Order> oldOrderMap;
    private List<Order> newOrders;
    private List<Order> oldOrders;

    public OrderTriggerHandler() {
        this.newOrderMap = (Map<Id, Order>) Trigger.newMap;
        this.oldOrderMap = (Map<Id, Order>) Trigger.oldMap;
        this.newOrders = (List<Order>) Trigger.new;
        this.oldOrders = (List<Order>) Trigger.old;
    }

    public override void beforeInsert() {
        WarehouseDefaultHelper.applyDefaultWarehouse(this.newOrders);
    }
}
//    public override void afterUpdate() {
    //	if (!hasRun) {
       //     hasRun = true;
         //   validateExistencias();


  //  private void validateExistencias(){
   //    for (Order order : this.newOrders) {
   //         if (order.Id != null) {
    //            ObtenerExistencias.updateExistenciasInOrder(order.Id);