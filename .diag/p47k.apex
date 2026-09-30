// Solo lectura: reproduce Update_Status del flow sobre el 773 y hace rollback
Savepoint sp = Database.setSavepoint();
Database.SaveResult r = Database.update(new Order(Id = '801WD000010B5DjYAK', Status = 'Ready_to_Send'), false);
Database.rollback(sp);
System.debug('R|' + r.isSuccess() + '|' + JSON.serialize(r.getErrors()));
Order o = [SELECT Status, ZF_Pedido_ID__c FROM Order WHERE Id = '801WD000010B5DjYAK'];
System.debug('O|' + o.Status + '|' + o.ZF_Pedido_ID__c);
