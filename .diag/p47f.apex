String tk = ZafiroAuthManager.getToken();
List<String> urls = new List<String>{'/clientes/InformacionCredito/4027','/clientes/InformacionCredito/4573'};
for (OrderItem a : [SELECT Articulo__c FROM OrderItem WHERE OrderId='801WD00000zKrHxYAK']) urls.add('/salesforce/ObtenerExistencias?ArticuloID=' + a.Articulo__c);
for (String u : urls) {
  HttpRequest r = new HttpRequest(); r.setEndpoint('callout:IntegracionZafiro' + u); r.setMethod('GET');
  r.setHeader('Authorization','Bearer ' + tk); r.setTimeout(20000);
  HttpResponse s = new Http().send(r);
  System.debug('Z|' + u + '|' + s.getStatusCode() + '|' + s.getBody().left(300));
}
