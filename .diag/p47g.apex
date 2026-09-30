Map<String,Schema.SObjectField> fm = Schema.SObjectType.Order.fields.getMap();
List<String> fs = new List<String>();
for (String f : fm.keySet()) if (fm.get(f).getDescribe().isCreateable()) fs.add(f);
for (Order o : Database.query('SELECT ' + String.join(fs, ',') + ' FROM Order WHERE OrderNumber IN (\'00000768\',\'00000769\')')) {
  String s = '';
  for (String f : fs) if (o.get(f) != null) s += f + '=' + o.get(f) + '; ';
  System.debug('O|' + s);
}
