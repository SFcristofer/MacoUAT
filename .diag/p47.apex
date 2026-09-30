for (OrderItem a : [SELECT Articulo__c, Description FROM OrderItem WHERE OrderId='801WD00000zKrHxYAK' ORDER BY SortOrderProducts__c ASC NULLS LAST, CreatedDate ASC, Id ASC]) {
  System.debug('LEN|' + a.Articulo__c + '|' + (a.Description==null?0:a.Description.length()) + '|' + JSON.serialize(a.Description));
}
