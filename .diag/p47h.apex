Id srcId = '801WD00000zKrHxYAK';
Map<String,Schema.SObjectField> fm = Schema.SObjectType.Order.fields.getMap();
List<String> fs = new List<String>();
for (String f : fm.keySet()) if (fm.get(f).getDescribe().isCreateable()) fs.add(f);
Order src = Database.query('SELECT ' + String.join(fs, ',') + ' FROM Order WHERE Id = :srcId');
Order o = src.clone(false, true);
o.AccountId = '001WD00000HwHSXYA3';
o.Status = 'Draft';
o.Description = 'PRUEBA #47: copia del 768 con cliente ZF 4573. Cancelar en Zafiro.';
insert o;
Map<String,Schema.SObjectField> im = Schema.SObjectType.OrderItem.fields.getMap();
List<String> ifs = new List<String>();
for (String f : im.keySet()) if (im.get(f).getDescribe().isCreateable() && f != 'orderid') ifs.add(f);
List<OrderItem> items = new List<OrderItem>();
for (OrderItem it : Database.query('SELECT ' + String.join(ifs, ',') + ' FROM OrderItem WHERE OrderId = :srcId')) {
  OrderItem c = it.clone(false, true); c.OrderId = o.Id; items.add(c);
}
insert items;
Order n = [SELECT Id, OrderNumber, Status, Account.Name, (SELECT Id FROM OrderItems) FROM Order WHERE Id = :o.Id];
System.debug('NEW|' + n.OrderNumber + '|' + n.Id + '|' + n.Status + '|' + n.Account.Name + '|' + n.OrderItems.size());
