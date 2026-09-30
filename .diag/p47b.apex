Integer mx=0; String s='';
for (OrderItem a : [SELECT Description, Order.OrderNumber FROM OrderItem WHERE Order.ZF_Pedido_ID__c != null AND Description != null]) {
  if (a.Description.length() > mx) { mx = a.Description.length(); s = a.Order.OrderNumber + ' ' + a.Description; }
}
System.debug('MAXOK|' + mx + '|' + s + '|' + [SELECT COUNT() FROM Order WHERE ZF_Pedido_ID__c != null]);
