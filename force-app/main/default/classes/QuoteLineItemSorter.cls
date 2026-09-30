/**
 * Ordena una colección de partidas de cotización respetando el orden que el
 * usuario definió con Easy Sort.
 *
 * Criterio: SortOrder ASC, con los nulos AL FINAL, y LineNumber ASC como
 * desempate.
 *
 * El "nulos al final" es deliberado. En UAT solo ~10% de las partidas tienen
 * SortOrder poblado (nadie ha usado Easy Sort en el resto). Si los nulos
 * fueran primero, una cotización parcialmente ordenada mandaría al inicio
 * justo las partidas sin ordenar. Con nulos al final, las ordenadas mandan y
 * las demás conservan su orden de captura.
 *
 * Flow no puede hacer esto solo: Get Records admite un único campo de
 * ordenamiento y no controla la posición de los nulos.
 */
public with sharing class QuoteLineItemSorter {

    public class Request {
        @InvocableVariable(label='Partidas de cotización' required=true)
        public List<QuoteLineItem> lineItems;
    }

    public class Result {
        @InvocableVariable(label='Partidas ordenadas')
        public List<QuoteLineItem> lineItems;
    }

    @InvocableMethod(
        label='Ordenar partidas de cotización'
        description='Devuelve las partidas ordenadas por SortOrder (nulos al final) y LineNumber.'
        category='MACO'
    )
    public static List<Result> sortLineItems(List<Request> requests) {
        List<Result> results = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();

            if (req == null || req.lineItems == null || req.lineItems.isEmpty()) {
                res.lineItems = new List<QuoteLineItem>();
                results.add(res);
                continue;
            }

            List<SortableLine> sortables = new List<SortableLine>();
            for (QuoteLineItem qli : req.lineItems) {
                sortables.add(new SortableLine(qli));
            }
            sortables.sort();

            List<QuoteLineItem> ordered = new List<QuoteLineItem>();
            Integer currentIndex = 1;
            for (SortableLine s : sortables) {
                s.record.SortOrder = currentIndex++;
                ordered.add(s.record);
            }

            res.lineItems = ordered;
            results.add(res);
        }

        return results;
    }

    /**
     * Envoltorio comparable. Se usa Comparable en lugar del Comparator de
     * plataforma para no depender de la versión de API del contexto que
     * invoque la clase.
     */
    @TestVisible
    private class SortableLine implements Comparable {
        public QuoteLineItem record;

        public SortableLine(QuoteLineItem record) {
            this.record = record;
        }

        public Integer compareTo(Object other) {
            SortableLine that = (SortableLine) other;

            Decimal thisSort = this.record.SortOrder;
            Decimal thatSort = that.record.SortOrder;

            // Nulos al final
            if (thisSort == null && thatSort != null) { return 1; }
            if (thisSort != null && thatSort == null) { return -1; }

            if (thisSort != null && thatSort != null && thisSort != thatSort) {
                return thisSort > thatSort ? 1 : -1;
            }

            // Desempate por LineNumber (autonumérico, comparación textual)
            String thisLine = this.record.LineNumber;
            String thatLine = that.record.LineNumber;

            if (thisLine == null && thatLine == null) { return 0; }
            if (thisLine == null) { return 1; }
            if (thatLine == null) { return -1; }

            return thisLine.compareTo(thatLine);
        }
    }
}