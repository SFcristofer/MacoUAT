// Bisección #47 ronda 3: el 776 (partidas 1-4) falló -> una copia del 768 por cada partida 1-4, cliente ZF 4573
Id srcId = '801WD00000zKrHxYAK';
Map<String,Schema.SObjectField> fm = Schema.SObjectType.Order.fields.getMap();
List<String> fs = new List<String>();
for (String f : fm.keySet()) if (fm.get(f).getDescribe().isCreateable()) fs.add(f);
Order src = Database.query('SELECT ' + String.join(fs, ',') + ' FROM Order WHERE Id = :srcId');
List<Order> os = new List<Order>();
for (Integer k = 1; k <= 4; k++) {
  Order o = src.clone(false, true);
  o.AccountId = '001WD00000HwHSXYA3'; o.Status = 'Draft';
  o.Description = 'PRUEBA #47 partida ' + k + ': copia del 768 con cliente ZF 4573. Cancelar en Zafiro.';
  os.add(o);
}
insert os;
Map<String,Schema.SObjectField> im = Schema.SObjectType.OrderItem.fields.getMap();
List<String> ifs = new List<String>();
for (String f : im.keySet()) if (im.get(f).getDescribe().isCreateable() && f != 'orderid') ifs.add(f);
List<OrderItem> items = new List<OrderItem>();
Integer i = 0;
for (OrderItem it : Database.query('SELECT ' + String.join(ifs, ',') + ' FROM OrderItem WHERE OrderId = :srcId ORDER BY SortOrderProducts__c LIMIT 4')) {
  OrderItem c = it.clone(false, true); c.OrderId = os[i].Id; items.add(c); i++;
}
insert items;
for (Order n : [SELECT OrderNumber, Id, (SELECT Articulo__c FROM OrderItems) FROM Order WHERE Id IN :os ORDER BY OrderNumber]) {
  System.debug('NEW|' + n.OrderNumber + '|' + n.Id + '|' + n.OrderItems[0].Articulo__c);
}
Order f = [SELECT ZF_Pedido_ID__c, Status FROM Order WHERE OrderNumber = '00000777'];
System.debug('F777|' + f.ZF_Pedido_ID__c + '|' + f.Status);
