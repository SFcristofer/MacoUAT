Map<String,Integer> c = new Map<String,Integer>();
for (OrderItem a : [SELECT Description, Order.OrderNumber, Order.CreatedBy.Alias, Order.CreatedDate FROM OrderItem WHERE Order.ZF_Pedido_ID__c != null AND Description != null AND Order.CreatedDate >= 2026-06-01T00:00:00Z]) {
  if (a.Description.length() > 54) System.debug('LONG|' + a.Order.OrderNumber + '|' + a.Order.CreatedBy.Alias + '|' + a.Description.length());
  if (a.Description.contains('"')) System.debug('QUOTE|' + a.Order.OrderNumber + '|' + a.Order.CreatedBy.Alias);
}
Order o = [SELECT CreatedBy.Alias, CreatedDate, ZF_Pedido_ID__c FROM Order WHERE OrderNumber='00000501'];
System.debug('O501|' + o.CreatedBy.Alias + '|' + o.CreatedDate + '|' + o.ZF_Pedido_ID__c);
