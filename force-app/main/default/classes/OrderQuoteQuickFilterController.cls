public with sharing class OrderQuoteQuickFilterController {

    private static final Set<String> ALLOWED_OBJECTS = new Set<String>{ 'Order', 'Quote' };
    private static final Integer MAX_PAGE_SIZE = 100;
    private static final Integer DEFAULT_PAGE_SIZE = 25;

    // -------------------------------------------------------------------
    // Whitelists: logical filter key -> real SOQL field path.
    // The client (LWC) only ever sends these logical keys, never a raw
    // field name, so a filters map can't be used to inject arbitrary SOQL.
    // -------------------------------------------------------------------

    private static Map<String, String> getTextFilterFields(String objectApiName) {
        if (objectApiName == 'Order') {
            return new Map<String, String>{
                'recordNumber' => 'OrderNumber',
                'externalId' => 'ZF_Pedido_ID__c',
                'accountNumber' => 'Account.AccountNumber',
                'accountName' => 'Account.Name'
            };
        }
        if (objectApiName == 'Quote') {
            return new Map<String, String>{
                'recordNumber' => 'Name',
                'accountName' => 'Account.Name'
            };
        }
        return new Map<String, String>();
    }

    // Picklists reales de Salesforce (opciones vía Schema).
    private static Map<String, String> getSchemaPicklistFilterFields(String objectApiName) {
        if (objectApiName == 'Order' || objectApiName == 'Quote') {
            return new Map<String, String>{
                'status' => 'Status',
                'methodOfPayment' => 'Method_of_Payment__c'
            };
        }
        return new Map<String, String>();
    }

    // Campos de texto libre (vienen del ERP) o de relación que no son picklist real,
    // pero cuyos valores distintos se agrupan (GROUP BY) para ofrecer un buscador +
    // selección múltiple en vez de un LIKE simple.
    private static Map<String, String> getGroupByFilterFields(String objectApiName) {
        if (objectApiName == 'Order') {
            return new Map<String, String>{
                'ownerName' => 'Owner.Name',
                'estatusFacturacion' => 'Estatus_Facturacion__c',
                'estatusSurtimiento' => 'Estatus_Surtimiento__c',
                'warehouseName' => 'Warehouse__r.Name'
            };
        }
        if (objectApiName == 'Quote') {
            return new Map<String, String>{
                'ownerName' => 'Owner.Name'
            };
        }
        return new Map<String, String>();
    }

    // Todos los campos que se filtran con IN (...) contra una lista de valores
    // seleccionados: picklists reales + campos agrupables.
    private static Map<String, String> getMultiValueFilterFields(String objectApiName) {
        Map<String, String> merged = new Map<String, String>();
        merged.putAll(getSchemaPicklistFilterFields(objectApiName));
        merged.putAll(getGroupByFilterFields(objectApiName));
        return merged;
    }

    private static String getDateFilterField(String objectApiName) {
        return objectApiName == 'Order' ? 'EffectiveDate' : 'Start_Date__c';
    }

    private static List<String> getSelectFields(String objectApiName) {
        if (objectApiName == 'Order') {
            return new List<String>{
                'Id', 'OrderNumber', 'ZF_Pedido_ID__c', 'Account.AccountNumber', 'Account.Name', 'Owner.Name',
                'EffectiveDate', 'Status', 'Method_of_Payment__c', 'Estatus_Facturacion__c',
                'Estatus_Surtimiento__c', 'Warehouse__r.Name', 'SubTotal__c', 'Total_Order_Amount__c'
            };
        }
        return new List<String>{
            'Id', 'Name', 'Account.Name', 'Owner.Name', 'Start_Date__c', 'ExpirationDate',
            'Status', 'Method_of_Payment__c', 'Subtotal', 'Total__c', 'LineItemCount'
        };
    }

    // -----------------
    // Public API
    // -----------------

    @AuraEnabled(cacheable=false)
    public static FilterResult getFilteredRecords(String objectApiName, Map<String, Object> filters, Integer pageSize, Integer pageOffset) {
        validateObject(objectApiName);
        pageSize = (pageSize == null || pageSize <= 0) ? DEFAULT_PAGE_SIZE : Math.min(pageSize, MAX_PAGE_SIZE);
        pageOffset = (pageOffset == null || pageOffset < 0) ? 0 : pageOffset;

        String whereClause = buildWhereClause(objectApiName, filters);
        String selectFields = String.join(getSelectFields(objectApiName), ', ');

        String soql = 'SELECT ' + selectFields + ' FROM ' + objectApiName +
            (String.isNotBlank(whereClause) ? ' WHERE ' + whereClause : '') +
            ' ORDER BY Id DESC LIMIT :pageSize OFFSET :pageOffset';

        List<SObject> records = Database.query(soql, AccessLevel.USER_MODE);

        FilterResult result = new FilterResult();
        result.records = wrapRecords(objectApiName, records);
        result.totals = buildTotals(objectApiName, whereClause);
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<PicklistOption> getPicklistOptions(String objectApiName, String logicalFieldKey) {
        validateObject(objectApiName);
        Map<String, String> picklistFields = getSchemaPicklistFilterFields(objectApiName);
        if (!picklistFields.containsKey(logicalFieldKey)) {
            throw new AuraHandledException('Campo de filtro no permitido: ' + logicalFieldKey);
        }
        String fieldApiName = picklistFields.get(logicalFieldKey);

        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldApiName).getDescribe();

        List<PicklistOption> options = new List<PicklistOption>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.isActive()) {
                PicklistOption opt = new PicklistOption();
                opt.label = entry.getLabel();
                opt.value = entry.getValue();
                options.add(opt);
            }
        }
        return options;
    }

    // Devuelve los valores distintos (GROUP BY) de un campo de texto/relación,
    // opcionalmente filtrados por un término de búsqueda, para alimentar el
    // buscador + selección múltiple en la UI (equivalente a un "typeahead").
    @AuraEnabled(cacheable=true)
    public static List<String> getDistinctValues(String objectApiName, String logicalFieldKey, String searchTerm) {
        validateObject(objectApiName);
        Map<String, String> groupableFields = getGroupByFilterFields(objectApiName);
        if (!groupableFields.containsKey(logicalFieldKey)) {
            throw new AuraHandledException('Campo de agrupación no permitido: ' + logicalFieldKey);
        }
        String fieldPath = groupableFields.get(logicalFieldKey);

        String whereClause = fieldPath + ' != null';
        if (String.isNotBlank(searchTerm)) {
            whereClause += ' AND ' + fieldPath + ' LIKE \'%' + String.escapeSingleQuotes(searchTerm.trim()) + '%\'';
        }

        String soql = 'SELECT ' + fieldPath + ' groupValue FROM ' + objectApiName +
            ' WHERE ' + whereClause +
            ' GROUP BY ' + fieldPath +
            ' ORDER BY ' + fieldPath +
            ' LIMIT 50';

        List<AggregateResult> results = Database.query(soql, AccessLevel.USER_MODE);
        List<String> values = new List<String>();
        for (AggregateResult ar : results) {
            Object groupValue = ar.get('groupValue');
            if (groupValue != null) {
                values.add(String.valueOf(groupValue));
            }
        }
        return values;
    }

    // -----------------
    // Private helpers
    // -----------------

    private static void validateObject(String objectApiName) {
        if (!ALLOWED_OBJECTS.contains(objectApiName)) {
            throw new AuraHandledException('Objeto no permitido: ' + objectApiName);
        }
    }

    private static String buildWhereClause(String objectApiName, Map<String, Object> filters) {
        if (filters == null || filters.isEmpty()) {
            return '';
        }
        List<String> conditions = new List<String>();
        Map<String, String> textFields = getTextFilterFields(objectApiName);
        Map<String, String> multiValueFields = getMultiValueFilterFields(objectApiName);
        String dateField = getDateFilterField(objectApiName);

        for (String key : filters.keySet()) {
            Object rawValue = filters.get(key);
            if (rawValue == null) {
                continue;
            }

            if (textFields.containsKey(key)) {
                String value = String.valueOf(rawValue).trim();
                if (String.isNotBlank(value)) {
                    String escaped = String.escapeSingleQuotes(value);
                    conditions.add(textFields.get(key) + ' LIKE \'%' + escaped + '%\'');
                }
            } else if (multiValueFields.containsKey(key)) {
                List<Object> rawList = (List<Object>) rawValue;
                if (rawList != null && !rawList.isEmpty()) {
                    List<String> quotedValues = new List<String>();
                    for (Object v : rawList) {
                        quotedValues.add('\'' + String.escapeSingleQuotes(String.valueOf(v)) + '\'');
                    }
                    conditions.add(multiValueFields.get(key) + ' IN (' + String.join(quotedValues, ',') + ')');
                }
            } else if (key == 'dateFrom') {
                String dateLiteral = validateDateLiteral(rawValue);
                if (dateLiteral != null) {
                    conditions.add(dateField + ' >= ' + dateLiteral);
                }
            } else if (key == 'dateTo') {
                String dateLiteral = validateDateLiteral(rawValue);
                if (dateLiteral != null) {
                    conditions.add(dateField + ' <= ' + dateLiteral);
                }
            }
            // Cualquier otra key es ignorada: whitelist estricta, nunca se concatena
            // un fieldName libre proveniente del cliente.
        }
        return String.join(conditions, ' AND ');
    }

    // Valida el formato YYYY-MM-DD y, si es válido, lo devuelve tal cual para usarlo
    // como literal de fecha sin comillas en SOQL (Date.format() no sirve para esto:
    // devuelve la fecha con el formato regional del usuario, no un literal de SOQL).
    private static String validateDateLiteral(Object rawValue) {
        if (rawValue == null) {
            return null;
        }
        String value = String.valueOf(rawValue).trim();
        if (!Pattern.matches('^\\d{4}-\\d{2}-\\d{2}$', value)) {
            return null;
        }
        try {
            Date.valueOf(value);
        } catch (Exception e) {
            return null;
        }
        return value;
    }

    private static List<OrderQuoteRow> wrapRecords(String objectApiName, List<SObject> records) {
        List<OrderQuoteRow> rows = new List<OrderQuoteRow>();
        for (SObject record : records) {
            OrderQuoteRow row = new OrderQuoteRow();
            row.id = (Id) record.get('Id');
            row.status = (String) record.get('Status');
            row.methodOfPayment = (String) record.get('Method_of_Payment__c');
            row.ownerName = getRelatedField(record, 'Owner', 'Name');

            if (objectApiName == 'Order') {
                row.recordNumber = (String) record.get('OrderNumber');
                row.externalId = (String) record.get('ZF_Pedido_ID__c');
                row.accountNumber = getRelatedField(record, 'Account', 'AccountNumber');
                row.accountName = getRelatedField(record, 'Account', 'Name');
                row.recordDate = (Date) record.get('EffectiveDate');
                row.estatusFacturacion = (String) record.get('Estatus_Facturacion__c');
                row.estatusSurtimiento = (String) record.get('Estatus_Surtimiento__c');
                row.warehouseName = getRelatedField(record, 'Warehouse__r', 'Name');
                row.subTotal = (Decimal) record.get('SubTotal__c');
                row.total = (Decimal) record.get('Total_Order_Amount__c');
            } else {
                row.recordNumber = (String) record.get('Name');
                row.accountName = getRelatedField(record, 'Account', 'Name');
                row.recordDate = (Date) record.get('Start_Date__c');
                row.secondDate = (Date) record.get('ExpirationDate');
                row.subTotal = (Decimal) record.get('Subtotal');
                row.total = (Decimal) record.get('Total__c');
                row.lineItemCount = (Decimal) record.get('LineItemCount');
            }
            rows.add(row);
        }
        return rows;
    }

    private static String getRelatedField(SObject record, String relationshipName, String fieldName) {
        SObject related = record.getSObject(relationshipName);
        return related == null ? null : (String) related.get(fieldName);
    }

    private static Totals buildTotals(String objectApiName, String whereClause) {
        String subTotalField = objectApiName == 'Order' ? 'SubTotal__c' : 'Subtotal';
        String totalField = objectApiName == 'Order' ? 'Total_Order_Amount__c' : 'Total__c';

        String soql = 'SELECT COUNT(Id) recordCount, SUM(' + subTotalField + ') subTotalSum, SUM(' + totalField + ') totalSum ' +
            'FROM ' + objectApiName + (String.isNotBlank(whereClause) ? ' WHERE ' + whereClause : '');

        List<AggregateResult> results = Database.query(soql, AccessLevel.USER_MODE);
        Totals totals = new Totals();
        if (!results.isEmpty()) {
            AggregateResult ar = results[0];
            totals.recordCount = (Integer) ar.get('recordCount');
            totals.subTotalSum = (Decimal) ar.get('subTotalSum');
            totals.totalSum = (Decimal) ar.get('totalSum');
        }
        return totals;
    }

    // -----------------
    // Wrapper classes
    // -----------------

    public class FilterResult {
        @AuraEnabled public List<OrderQuoteRow> records;
        @AuraEnabled public Totals totals;
    }

    public class Totals {
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public Decimal subTotalSum;
        @AuraEnabled public Decimal totalSum;
    }

    public class PicklistOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    public class OrderQuoteRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String recordNumber;
        @AuraEnabled public String externalId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Date recordDate;
        @AuraEnabled public Date secondDate;
        @AuraEnabled public String status;
        @AuraEnabled public String methodOfPayment;
        @AuraEnabled public String estatusFacturacion;
        @AuraEnabled public String estatusSurtimiento;
        @AuraEnabled public String warehouseName;
        @AuraEnabled public Decimal subTotal;
        @AuraEnabled public Decimal total;
        @AuraEnabled public Decimal lineItemCount;
    }
}