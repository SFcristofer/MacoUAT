public with sharing class OrderPDFController {
    public Order orderRecord { get; set; }
    public List<OrderItem> orderItems { get; set; }
    public List<FormattedOrderItem> formattedOrderItems { get; set; }
    public String effectiveDateFormatted { get; set; }
    public String formattedSubtotal { get; set; }
    public String formattedTotal { get; set; }
    public String formattedTax { get; set; }
    
    public OrderPDFController(ApexPages.StandardController controller) {
        Id orderId = controller.getRecord().Id;

      orderRecord = [
    SELECT Id, OrderNumber, EffectiveDate, TotalAmount, Total_Order_Amount__c,
           Account.Name, Account.AccountNumber, Total_Impuesto__c, ZF_Pedido_ID__c, Owner.name, Warehouse__c
    FROM Order
    WHERE Id = :orderId
];

        // Formateo de fecha para el nombre del archivo
        String dateStr = '';
        if (orderRecord.EffectiveDate != null) {
            Date dName = orderRecord.EffectiveDate;
            dateStr = dName.day() + '-' + dName.month() + '-' + dName.year();
        }
        
        // Limpiar el nombre de la cuenta para evitar caracteres inválidos en el archivo
        String accountName = 'Sin_Cuenta';
        if (orderRecord.Account != null && orderRecord.Account.Name != null) {
            accountName = orderRecord.Account.Name.replaceAll('[^a-zA-Z0-9 ]', '').trim().replaceAll(' ', '_');
        }

        // Establecer el nombre del archivo PDF sugerido al descargar (Ej: 00000123_22-8-2026.pdf)
        String pdfName = orderRecord.OrderNumber + '_' + dateStr + '.pdf';
        Apexpages.currentPage().getHeaders().put('content-disposition', 'inline; filename="' + pdfName + '"');

        orderItems = [
            SELECT Id, Product2Id, Product2.Name, Product2.Description, Product2.Unidad__c, Location__c, Quantity, UnitPrice, TotalPrice, Description
            FROM OrderItem
            WHERE OrderId = :orderId
        ];

        // Formateo de fecha DD/MM/AAAA
        Date d = orderRecord.EffectiveDate;
        String dayStr = (d.day() < 10 ? '0' : '') + d.day();
        String monthStr = (d.month() < 10 ? '0' : '') + d.month();
        String yearStr = String.valueOf(d.year());
        effectiveDateFormatted = dayStr + '/' + monthStr + '/' + yearStr;

        // Subtotales
        formattedSubtotal = formatDecimal(orderRecord.TotalAmount);
        formattedTax = formatDecimal(orderRecord.Total_Impuesto__c);
        formattedTotal = formatDecimal(orderRecord.Total_Order_Amount__c);

        // Collect Product Ids
        Set<Id> productIds = new Set<Id>();
        for (OrderItem item : orderItems) {
            productIds.add(item.Product2Id);
        }

        // Query ProductWarehouse__c for locations
        Map<Id, String> productIdToLocation = new Map<Id, String>();
        if (!productIds.isEmpty() && orderRecord.Warehouse__c != null) {
            for (ProductWarehouse__c pw : [SELECT Product2__c, Location__c FROM ProductWarehouse__c WHERE Warehouse__c = :orderRecord.Warehouse__c AND Product2__c IN :productIds]) {
                productIdToLocation.put(pw.Product2__c, pw.Location__c);
            }
        }

        // Construir lista con montos formateados
        formattedOrderItems = new List<FormattedOrderItem>();
        for (OrderItem item : orderItems) {
            FormattedOrderItem f = new FormattedOrderItem();
            f.productName = item.Product2.Name;
            f.description = item.Description;
            f.quantity = formatQuantity(item.Quantity);
            f.unidadMedida = item.Product2.Unidad__c;
            f.ubicacion = productIdToLocation.containsKey(item.Product2Id) ? productIdToLocation.get(item.Product2Id) : '';
            f.unitPriceFormatted = formatDecimal(item.UnitPrice);
            f.totalPriceFormatted = formatDecimal(item.TotalPrice);
            formattedOrderItems.add(f);
        }
    }

    // La cantidad admite hasta 2 decimales. Antes se imprimía con
    // Integer.valueOf(), que TRUNCA: un pedido de 30.48 salía como 30 en el PDF
    // que ve el cliente. Se imprime entero cuando no hay decimales
    // significativos (30, no 30.00) y con decimales cuando los hay.
    public static String formatQuantity(Decimal value) {
        if (value == null) return '0';
        return value.setScale(2, System.RoundingMode.HALF_UP).stripTrailingZeros().format();
    }

    public static String formatDecimal(Decimal value) {
        if (value == null) return '$ 0.00';
        // format() quita los ceros finales (491.90 salía 491.9): entero con miles + 2 decimales fijos
        Decimal v = value.setScale(2, System.RoundingMode.HALF_UP);
        String cents = String.valueOf(Math.mod(Math.abs((v * 100).longValue()), 100)).leftPad(2, '0');
        return (v < 0 ? '-' : '') + '$ ' + Math.abs(v.longValue()).format() + '.' + cents;
    }

    public class FormattedOrderItem {
        public String productName { get; set; }
        public String description { get; set; }
        public String quantity { get; set; }
        public String unidadMedida { get; set; }
        public String ubicacion { get; set; }
        public String unitPriceFormatted { get; set; }
        public String totalPriceFormatted { get; set; }
    }
}