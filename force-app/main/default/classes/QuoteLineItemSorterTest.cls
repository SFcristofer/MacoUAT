@IsTest
private class QuoteLineItemSorterTest {

    /**
     * LineNumber es autonumérico y SortOrder no siempre es asignable en
     * memoria; se construyen por deserialización para no depender de DML.
     */
    private static QuoteLineItem buildLine(Object sortOrder, String lineNumber) {
        Map<String, Object> raw = new Map<String, Object>{
            'LineNumber' => lineNumber
        };
        if (sortOrder != null) {
            raw.put('SortOrder', sortOrder);
        }
        return (QuoteLineItem) JSON.deserialize(JSON.serialize(raw), QuoteLineItem.class);
    }

    private static List<QuoteLineItem> run(List<QuoteLineItem> input) {
        QuoteLineItemSorter.Request req = new QuoteLineItemSorter.Request();
        req.lineItems = input;
        return QuoteLineItemSorter.sortLineItems(
            new List<QuoteLineItemSorter.Request>{ req }
        )[0].lineItems;
    }

    @IsTest
    static void ordenaPorSortOrder() {
        List<QuoteLineItem> out = run(new List<QuoteLineItem>{
            buildLine(3, '00000003'),
            buildLine(1, '00000001'),
            buildLine(2, '00000002')
        });

        Assert.areEqual(3, out.size(), 'Debe devolver las 3 partidas');
        Assert.areEqual(1, out[0].SortOrder, 'Primero el SortOrder menor');
        Assert.areEqual(2, out[1].SortOrder, 'Luego el intermedio');
        Assert.areEqual(3, out[2].SortOrder, 'Al final el mayor');
    }

    @IsTest
    static void nulosAlFinal() {
        List<QuoteLineItem> out = run(new List<QuoteLineItem>{
            buildLine(null, '00000001'),
            buildLine(5,    '00000002'),
            buildLine(null, '00000003'),
            buildLine(2,    '00000004')
        });

        Assert.areEqual(2, out[0].SortOrder, 'Las ordenadas van primero');
        Assert.areEqual(5, out[1].SortOrder, 'En orden ascendente');
        Assert.areEqual(null, out[2].SortOrder, 'Los nulos al final');
        Assert.areEqual(null, out[3].SortOrder, 'Los nulos al final');
    }

    @IsTest
    static void desempataPorLineNumber() {
        // Todos nulos: debe conservar el orden de captura (LineNumber)
        List<QuoteLineItem> out = run(new List<QuoteLineItem>{
            buildLine(null, '00000030'),
            buildLine(null, '00000010'),
            buildLine(null, '00000020')
        });

        Assert.areEqual('00000010', out[0].LineNumber, 'Desempate por LineNumber');
        Assert.areEqual('00000020', out[1].LineNumber, 'Desempate por LineNumber');
        Assert.areEqual('00000030', out[2].LineNumber, 'Desempate por LineNumber');
    }

    @IsTest
    static void mismoSortOrderDesempataPorLineNumber() {
        List<QuoteLineItem> out = run(new List<QuoteLineItem>{
            buildLine(7, '00000099'),
            buildLine(7, '00000011')
        });

        Assert.areEqual('00000011', out[0].LineNumber, 'Empate en SortOrder: gana LineNumber menor');
        Assert.areEqual('00000099', out[1].LineNumber, 'Empate en SortOrder: gana LineNumber menor');
    }

    @IsTest
    static void coleccionVaciaYNula() {
        Assert.areEqual(0, run(new List<QuoteLineItem>()).size(), 'Lista vacía devuelve vacía');

        QuoteLineItemSorter.Request req = new QuoteLineItemSorter.Request();
        req.lineItems = null;
        List<QuoteLineItemSorter.Result> res = QuoteLineItemSorter.sortLineItems(
            new List<QuoteLineItemSorter.Request>{ req }
        );
        Assert.areEqual(0, res[0].lineItems.size(), 'Colección nula devuelve vacía, no error');
    }

    @IsTest
    static void variasSolicitudes() {
        QuoteLineItemSorter.Request a = new QuoteLineItemSorter.Request();
        a.lineItems = new List<QuoteLineItem>{ buildLine(2, '00000002'), buildLine(1, '00000001') };

        QuoteLineItemSorter.Request b = new QuoteLineItemSorter.Request();
        b.lineItems = new List<QuoteLineItem>{ buildLine(9, '00000009') };

        List<QuoteLineItemSorter.Result> res = QuoteLineItemSorter.sortLineItems(
            new List<QuoteLineItemSorter.Request>{ a, b }
        );

        Assert.areEqual(2, res.size(), 'Una respuesta por solicitud');
        Assert.areEqual(1, res[0].lineItems[0].SortOrder, 'Primera solicitud ordenada');
        Assert.areEqual(9, res[1].lineItems[0].SortOrder, 'Segunda solicitud intacta');
    }
}