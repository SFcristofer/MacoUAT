// Controlador del PDF de cotización (QuotePDF.page). Mismo formato que el PDF
// de pedido (OrderPDFController), reutiliza su formateo de montos/cantidades.
public with sharing class QuotePDFController {
    public Quote quoteRecord { get; set; }
    public List<OrderPDFController.FormattedOrderItem> formattedItems { get; set; }
    public String createdDateFormatted { get; set; }
    public String expirationDateFormatted { get; set; }
    public String formattedSubtotal { get; set; }
    public String formattedTax { get; set; }
    public String formattedTotal { get; set; }

    public QuotePDFController(ApexPages.StandardController controller) {
        Id quoteId = controller.getId();

        quoteRecord = [
            SELECT Id, QuoteNumber, Name, CreatedDate, ExpirationDate, End_Date__c,
                   TotalPrice, Total_Tax_Items__c, Total__c, Warehouse__c, Description, Observaciones__c,
                   Account.Name, Account.AccountNumber, Owner.Name
            FROM Quote
            WHERE Id = :quoteId
        ];

        ApexPages.currentPage().getHeaders().put('content-disposition', 'inline; filename="' + quoteRecord.QuoteNumber + '.pdf"');

        createdDateFormatted = formatDate(quoteRecord.CreatedDate.date());
        expirationDateFormatted = formatDate(quoteRecord.End_Date__c != null ? quoteRecord.End_Date__c : quoteRecord.ExpirationDate);

        formattedSubtotal = OrderPDFController.formatDecimal(quoteRecord.TotalPrice);
        formattedTax = OrderPDFController.formatDecimal(quoteRecord.Total_Tax_Items__c);
        formattedTotal = OrderPDFController.formatDecimal(quoteRecord.Total__c);

        List<QuoteLineItem> lines = [
            SELECT Product2Id, Product2.Name, Product2.Unidad__c, Description,
                   Quantity, UnitPrice, TotalPrice, Ubicacion__c, Location__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            ORDER BY SortOrder NULLS LAST, LineNumber
        ];

        // Ubicación por almacén, igual que en el PDF de pedido
        Set<Id> productIds = new Set<Id>();
        for (QuoteLineItem l : lines) {
            productIds.add(l.Product2Id);
        }
        Map<Id, String> locationByProduct = new Map<Id, String>();
        if (!productIds.isEmpty() && quoteRecord.Warehouse__c != null) {
            for (ProductWarehouse__c pw : [SELECT Product2__c, Location__c FROM ProductWarehouse__c WHERE Warehouse__c = :quoteRecord.Warehouse__c AND Product2__c IN :productIds]) {
                locationByProduct.put(pw.Product2__c, pw.Location__c);
            }
        }

        formattedItems = new List<OrderPDFController.FormattedOrderItem>();
        for (QuoteLineItem l : lines) {
            OrderPDFController.FormattedOrderItem f = new OrderPDFController.FormattedOrderItem();
            f.productName = l.Product2.Name;
            f.description = l.Description;
            f.quantity = OrderPDFController.formatQuantity(l.Quantity);
            f.unidadMedida = l.Product2.Unidad__c;
            f.ubicacion = locationByProduct.containsKey(l.Product2Id) ? locationByProduct.get(l.Product2Id)
                : (String.isNotBlank(l.Ubicacion__c) ? l.Ubicacion__c : l.Location__c);
            f.unitPriceFormatted = OrderPDFController.formatDecimal(l.UnitPrice);
            f.totalPriceFormatted = OrderPDFController.formatDecimal(l.TotalPrice);
            formattedItems.add(f);
        }
    }

    private static String formatDate(Date d) {
        if (d == null) return '';
        return String.valueOf(d.day()).leftPad(2, '0') + '/' + String.valueOf(d.month()).leftPad(2, '0') + '/' + d.year();
    }
}
