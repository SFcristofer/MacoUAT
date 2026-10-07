public class WarehouseDefaultHelper {

    private static Map<String, String> warehouseCodeByTerritory;
    private static Map<String, Id> warehouseIdByCode;
    private static Map<String, String> warehouseCodeByRegion;

    public static void applyDefaultWarehouse(List<SObject> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        List<SObject> recordsNeedingWarehouse = new List<SObject>();
        for (SObject record : records) {
            if (record.get('Warehouse__c') == null) {
                recordsNeedingWarehouse.add(record);
            }
        }
        if (recordsNeedingWarehouse.isEmpty()) {
            return;
        }

        Id defaultWarehouseId = resolveWarehouseIdForCurrentUser();
        if (defaultWarehouseId == null) {
            return;
        }

        for (SObject record : recordsNeedingWarehouse) {
            record.put('Warehouse__c', defaultWarehouseId);
        }
    }

    private static Id resolveWarehouseIdForCurrentUser() {
        User runningUser = [SELECT Territorio__c FROM User WHERE Id = :UserInfo.getUserId()];
        String territorioKey = String.isBlank(runningUser.Territorio__c) ? null : runningUser.Territorio__c;

        Map<String, String> codeByTerritory = getWarehouseCodeByTerritoryMap();
        String warehouseCode = codeByTerritory.containsKey(territorioKey)
            ? codeByTerritory.get(territorioKey)
            : codeByTerritory.get(null);

        if (String.isBlank(warehouseCode)) {
            return null;
        }
        return getWarehouseIdByCodeMap().get(warehouseCode);
    }

    // Usado por los flows de cotización para preseleccionar el almacén según Account.Region__c.
    // Región sin registro o en blanco -> registro Default.
    @InvocableMethod(label='Almacén por región de la cuenta')
    public static List<Id> resolveWarehouseIdForAccounts(List<Id> accountIds) {
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Region__c FROM Account WHERE Id IN :accountIds]);
        Map<String, Id> idByCode = getWarehouseIdByCodeMap();
        String defaultCode = getWarehouseCodeByTerritoryMap().get(null);
        List<Id> result = new List<Id>();
        for (Id accountId : accountIds) {
            Account acc = accounts.get(accountId);
            String code = acc != null && getWarehouseCodeByRegionMap().containsKey(acc.Region__c)
                ? getWarehouseCodeByRegionMap().get(acc.Region__c)
                : defaultCode;
            result.add(idByCode.get(code));
        }
        return result;
    }

    private static Map<String, String> getWarehouseCodeByRegionMap() {
        if (warehouseCodeByRegion == null) {
            warehouseCodeByRegion = new Map<String, String>();
            for (Warehouse_Default_By_Territory__mdt config : Warehouse_Default_By_Territory__mdt.getAll().values()) {
                if (String.isNotBlank(config.Region__c)) {
                    warehouseCodeByRegion.put(config.Region__c, config.Warehouse_Code__c);
                }
            }
        }
        return warehouseCodeByRegion;
    }

    private static Map<String, String> getWarehouseCodeByTerritoryMap() {
        if (warehouseCodeByTerritory == null) {
            warehouseCodeByTerritory = new Map<String, String>();
            for (Warehouse_Default_By_Territory__mdt config : Warehouse_Default_By_Territory__mdt.getAll().values()) {
                if (String.isNotBlank(config.Region__c)) {
                    continue;
                }
                String key = String.isBlank(config.Territorio__c) ? null : config.Territorio__c;
                warehouseCodeByTerritory.put(key, config.Warehouse_Code__c);
            }
        }
        return warehouseCodeByTerritory;
    }

    private static Map<String, Id> getWarehouseIdByCodeMap() {
        if (warehouseIdByCode == null) {
            warehouseIdByCode = new Map<String, Id>();
            for (Warehouse__c warehouse : [SELECT Id, Code__c FROM Warehouse__c WHERE Code__c != null]) {
                warehouseIdByCode.put(warehouse.Code__c, warehouse.Id);
            }
        }
        return warehouseIdByCode;
    }

    @TestVisible
    private static void resetCache() {
        warehouseCodeByTerritory = null;
        warehouseIdByCode = null;
        warehouseCodeByRegion = null;
    }
}