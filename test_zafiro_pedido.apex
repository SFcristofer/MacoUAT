String token = ZafiroAuthManager.getToken();
Http http = new Http();
HttpRequest req = new HttpRequest();
// Pedido 001-96934 -> AlmacenID 001, PedidoID 96934
req.setEndpoint('callout:IntegracionZafiro/pedidos/001/96934');
req.setMethod('GET');
req.setHeader('Authorization', 'Bearer ' + token);
req.setHeader('Content-Type', 'application/json');

try {
    HttpResponse res = http.send(req);
    System.debug('STATUS: ' + res.getStatusCode());
    System.debug('BODY: ' + res.getBody());
} catch(Exception e) {
    System.debug('ERROR: ' + e.getMessage());
}
