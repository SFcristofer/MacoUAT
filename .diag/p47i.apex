for (OrderItem a : [SELECT Articulo__c, Quantity, UnitPrice, Tipo_Precio__c, Impuesto_Porcentaje__c, Impuesto__c, Description FROM OrderItem WHERE Order.OrderNumber IN ('00000773','00000769') ORDER BY Order.OrderNumber, SortOrderProducts__c]) {
  System.debug('I|' + JSON.serialize(new Map<String,Object>{'A'=>a.Articulo__c,'Q'=>a.Quantity,'P'=>a.UnitPrice,'T'=>a.Tipo_Precio__c,'IP'=>a.Impuesto_Porcentaje__c,'I'=>a.Impuesto__c,'D'=>a.Description}));
}
