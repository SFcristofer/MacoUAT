// Bisección #47: dos copias del 768 para cliente ZF 4573 -> A = partidas 1-8, B = partidas 9-15
Id srcId = '801WD00000zKrHxYAK';
Map<String,Schema.SObjectField> fm = Schema.SObjectType.Order.fields.getMap();
List<String> fs = new List<String>();
for (String f : fm.keySet()) if (fm.get(f).getDescribe().isCreateable()) fs.add(f);
Order src = Database.query('SELECT ' + String.join(fs, ',') + ' FROM Order WHERE Id = :srcId');
List<Order> os = new List<Order>();
for (String t : new List<String>{'A (partidas 1-8)', 'B (partidas 9-15)'}) {
  Order o = src.clone(false, true);
  o.AccountId = '001WD00000HwHSXYA3'; o.Status = 'Draft';
  o.Description = 'PRUEBA #47 ' + t + ': copia del 768 con cliente ZF 4573. Cancelar en Zafiro.';
  os.add(o);
}
insert os;
Map<String,Schema.SObjectField> im = Schema.SObjectType.OrderItem.fields.getMap();
List<String> ifs = new List<String>();
for (String f : im.keySet()) if (im.get(f).getDescribe().isCreateable() && f != 'orderid') ifs.add(f);
List<OrderItem> items = new List<OrderItem>();
Integer i = 0;
for (OrderItem it : Database.query('SELECT ' + String.join(ifs, ',') + ' FROM OrderItem WHERE OrderId = :srcId ORDER BY SortOrderProducts__c')) {
  OrderItem c = it.clone(false, true); c.OrderId = (i < 8 ? os[0].Id : os[1].Id); items.add(c); i++;
}
insert items;
for (Order n : [SELECT OrderNumber, Id, Description, (SELECT Articulo__c FROM OrderItems) FROM Order WHERE Id IN :os ORDER BY OrderNumber]) {
  List<String> a = new List<String>(); for (OrderItem x : n.OrderItems) a.add(x.Articulo__c);
  System.debug('NEW|' + n.OrderNumber + '|' + n.Id + '|' + n.Description.left(22) + '|' + String.join(a, ','));
}
