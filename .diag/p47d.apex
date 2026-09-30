Integer l=0,q=0; String qs='';
for (OrderItem a : [SELECT Description, Order.OrderNumber, Order.CreatedDate FROM OrderItem WHERE Order.ZF_Pedido_ID__c != null AND Description != null]) {
  if (a.Description.length() > 54) l++;
  if (a.Description.contains('"')) { q++; qs += a.Order.OrderNumber + '@' + a.Order.CreatedDate.date() + ' '; }
}
System.debug('SUM|long=' + l + '|quote=' + q + '|' + qs);
