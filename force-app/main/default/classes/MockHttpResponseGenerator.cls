@isTest
global class MockHttpResponseGenerator implements HttpCalloutMock {

    private static final String NAMED_CREDENTIAL = 'callout:IntegracionZafiro';

    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        String endpoint = req.getEndpoint();

        if (endpoint == NAMED_CREDENTIAL + '/auth/login') {
            res.setBody('{"UserID": "salesforce","Name": "Usuario integración Salesforce", "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.NewGeneratedToken"}');
            res.setStatusCode(201);
        } else if (endpoint == NAMED_CREDENTIAL + '/salesforce/CrearCliente') {
            res.setBody('{"ClienteID": 12345}');
            res.setStatusCode(201);
        } else if (endpoint == NAMED_CREDENTIAL + '/salesforce/ObtenerExistencias?ArticuloID=10'){
            res.setBody('[{"ArticuloID": 12,"AlmacenID": "028","Existencias": 0},{"ArticuloID": 12,"AlmacenID": "027","Existencias": 0},{"ArticuloID": 12,"AlmacenID": "026","Existencias": 0}]');
            res.setStatusCode(200);
        } else if (endpoint == NAMED_CREDENTIAL + '/salesforce/ObtenerExistencias?ArticuloID=Error'){
            res.setBody('{"statusCode": 400,"message": ["ArticuloID must be a number conforming to the specified constraints"],"error": "Bad Request"}');
            res.setStatusCode(400);
        } else if (endpoint == NAMED_CREDENTIAL + '/salesforce/CrearPedido'){
            res.setBody('{"AlmacenID":"001","PedidoID":96781,"Articulos":[{"PartidaID":1,"Articulo":101,"Cantidad":2,"Precio":500,"ImpuestoPorcentaje":16,"Impuesto":80,"Importe":1000},{"PartidaID":2,"Articulo":102,"Cantidad":1,"Precio":300,"ImpuestoPorcentaje":16,"Impuesto":48,"Importe":300}]}');
            res.setStatusCode(201);
        } else if (endpoint == NAMED_CREDENTIAL + '/salesforce/ObtenerAntiguedadSaldos?ClienteID=123456'){
            res.setBody('[{"Segmento":"General","Grupo":"034 R-Pachuca / Tulancingo GBG","ClienteNombre":"JOSE HERNANDEZ ESCAMILLA","PlazoPago":45,"Documento":"FAC01 107474-1","Fecha":"2024-10-14T00:00:00.000Z","FechaVencimiento":"2024-11-28T00:00:00.000Z","SaldoActual":17611.84,"SaldoPorVencer":0,"SaldoVencido":17611.84,"SaldoFavor":0,"Rango1Display":"1 - 30","Rango1Value":0,"Rango2Display":"31 - 60","Rango2Value":0,"Rango3Display":"61 - 90","Rango3Value":17611.84,"Rango4Display":"91 - 120","Rango4Value":0,"Rango5Display":"Más de 120","Rango5Value":0},{"Segmento":"General","Grupo":"034 R-Pachuca / Tulancingo GBG","ClienteNombre":"JOSE HERNANDEZ ESCAMILLA","PlazoPago":45,"Documento":"FAC01 107475-1","Fecha":"2024-10-14T00:00:00.000Z","FechaVencimiento":"2024-11-28T00:00:00.000Z","SaldoActual":17202.29,"SaldoPorVencer":0,"SaldoVencido":17202.29,"SaldoFavor":0,"Rango1Display":"1 - 30","Rango1Value":0,"Rango2Display":"31 - 60","Rango2Value":0,"Rango3Display":"61 - 90","Rango3Value":17202.29,"Rango4Display":"91 - 120","Rango4Value":0,"Rango5Display":"Más de 120","Rango5Value":0},{"Segmento":"General","Grupo":"034 R-Pachuca / Tulancingo GBG","ClienteNombre":"JOSE HERNANDEZ ESCAMILLA","PlazoPago":45,"Documento":"FAC01 107476-1","Fecha":"2024-10-14T00:00:00.000Z","FechaVencimiento":"2024-11-28T00:00:00.000Z","SaldoActual":11680.57,"SaldoPorVencer":0,"SaldoVencido":11680.57,"SaldoFavor":0,"Rango1Display":"1 - 30","Rango1Value":0,"Rango2Display":"31 - 60","Rango2Value":0,"Rango3Display":"61 - 90","Rango3Value":11680.57,"Rango4Display":"91 - 120","Rango4Value":0,"Rango5Display":"Más de 120","Rango5Value":0},{"Segmento":"General","Grupo":"034 R-Pachuca / Tulancingo GBG","ClienteNombre":"JOSE HERNANDEZ ESCAMILLA","PlazoPago":45,"Documento":"FAC01 107600-1","Fecha":"2024-10-17T00:00:00.000Z","FechaVencimiento":"2024-12-01T00:00:00.000Z","SaldoActual":16285.6,"SaldoPorVencer":0,"SaldoVencido":16285.6,"SaldoFavor":0,"Rango1Display":"1 - 30","Rango1Value":0,"Rango2Display":"31 - 60","Rango2Value":0,"Rango3Display":"61 - 90","Rango3Value":16285.6,"Rango4Display":"91 - 120","Rango4Value":0,"Rango5Display":"Más de 120","Rango5Value":0}]');
            res.setStatusCode(200);
        }  else if (endpoint == NAMED_CREDENTIAL + '/salesforce/ActualizarEstatusVentaPedido') {
            res.setBody('{"mensaje": "estatus actualizado"}');
    res.setStatusCode(200);
}  else if (endpoint == NAMED_CREDENTIAL + '/salesforce/ActualizarEstatusVentaPedido') {
            res.setBody('{"mensaje":"Error al actualizar estatus"}');
    res.setStatusCode(400);
        } else {
            System.debug('Acá nada pasó');
            res.setBody('{"error": "Bad Request"}');
            res.setStatusCode(400);
        }

        return res;
    }
}