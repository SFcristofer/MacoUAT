Set<String> arts = new Set<String>();
for (OrderItem a : [SELECT Articulo__c FROM OrderItem WHERE OrderId='801WD00000zKrHxYAK']) arts.add(String.valueOf(a.Articulo__c));
Set<String> ok = new Set<String>();
for (OrderItem a : [SELECT Articulo__c FROM OrderItem WHERE Order.ZF_Pedido_ID__c != null]) ok.add(String.valueOf(a.Articulo__c));
Set<String> nuevos = arts.clone(); nuevos.removeAll(ok);
System.debug('R|EP_ok=' + [SELECT COUNT() FROM Order WHERE ZF_Pedido_ID__c != null AND Tipo_Entrega_Venta__c='EP'] + '|cli4027_ok=' + [SELECT COUNT() FROM Order WHERE ZF_Pedido_ID__c != null AND Account.ZF_Cliente_ID__c=4027] + '|artsNuncaEnviados=' + nuevos + '|acct=' + [SELECT Account.Name, Account.CreatedDate FROM Order WHERE Id='801WD00000zKrHxYAK'].Account.Name);
