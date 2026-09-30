public with sharing class SalesMacoSearchController {

    // Tope de resultados que se devuelven al buscador. Se mantiene el valor
    // historico (200). Con ~39,000 productos en catalogo, una busqueda amplia
    // se sigue truncando: lo que cambia es QUE se trunca. Antes se cortaba
    // sobre una lista mezclada; ahora las coincidencias por codigo entran
    // primero, asi que lo que se pierde es siempre lo menos relevante.
    private static final Integer MAX_RESULTADOS = 200;

    // OJO - En esta org los campos de Product2 estan invertidos respecto a lo
    // que sugieren sus nombres de API. Lo confirma el encabezado de la tabla
    // en salesMacoSearch.html:
    //
    //     <th data-field="productName">Codigo</th>       -> Product2.Name
    //     <th data-field="productCode">Descripcion</th>   -> ProductCode
    //
    // Es decir: Product2.Name guarda el CODIGO ("202E-06", "BLUE-PLIOVIC-04")
    // y ProductCode guarda la DESCRIPCION ("DC603-6 GRIFO ATG").
    //
    // Todo lo que sigue ordena y prioriza por CODIGO, o sea por Product2.Name.

    // -------------------------
    // Get information Functions
    // -------------------------

    @AuraEnabled(cacheable=false)
    public static Warehouse__c getWarehouseInfo(String warehouseId) {
        return [SELECT Id, Name, Code__c FROM Warehouse__c WHERE Id = :warehouseId LIMIT 1];
    }

    @AuraEnabled(cacheable=false)
    public static Pricebook2 getPricebookInfo(String pricebookid){
        return [SELECT Id, Name, IsStandard FROM Pricebook2 WHERE Id=:pricebookid];
    }

    @AuraEnabled(cacheable=true)
    public static List<Warehouse__c> getActiveWarehouses(){
        return [SELECT Id, Name, Code__c FROM Warehouse__c ORDER BY Name ASC];
    }

    // ----------------
    // Search Functions
    // ----------------

    @AuraEnabled(cacheable=false)
    public static List<ProductInformation> getAllPricebookEntries(String pricebookId, String warehouseId, Boolean searchGeneric) {
        List<PricebookEntry> pricebookEntries = [ 
            SELECT Id, Pricebook2Id, Product2Id, UnitPrice, IsActive, Name, Product2.Name, ProductCode, ProductoGenerico__c, ExternalId__c  
            FROM PricebookEntry 
            WHERE Pricebook2Id=:pricebookId 
            AND Product2.IsActive = true
            AND Product2.ProductoGenerico__c = false
            AND IsActive = true
            ORDER BY Product2.Name ASC
            LIMIT :MAX_RESULTADOS
        ];
        if(!searchGeneric){
            pricebookEntries = filterProductsNoGeneric(pricebookEntries);
        }

        List<ProductWarehouse__c> existencias = getExistenciasData(warehouseId, pricebookEntries);
        return buildProductInformationList(pricebookEntries, existencias);
    }

    @AuraEnabled(cacheable=false)
    public static List<ProductInformation> getPricebookEntriesFiltered(String pricebookId, String warehouseId, String searchTerm, Boolean searchGeneric) {
        String searchQuery = '%' + searchTerm + '%';

        // Se consulta en dos pasadas en lugar de una sola con OR.
        //
        // Con una sola consulta el orden era plano sobre un conjunto mezclado:
        // buscando GH493, un articulo cuya DESCRIPCION menciona GH493 quedaba
        // arriba del articulo cuyo CODIGO es GH493. La coincidencia
        // irrelevante ganaba.
        //
        // SOQL no permite ordenar por "tipo de coincidencia", asi que se
        // resuelve en dos pasadas: primero las que casan por codigo
        // (Product2.Name), despues las que solo casan por descripcion
        // (ProductCode). Cada bloque ordenado alfanumericamente por codigo.
        List<PricebookEntry> porCodigo = [
            SELECT Id, Pricebook2Id, Product2Id, UnitPrice, IsActive, Name, Product2.Name, ProductCode, ProductoGenerico__c, ExternalId__c
            FROM PricebookEntry
            WHERE Product2.Name LIKE :searchQuery
            AND Product2.IsActive = true
            AND Product2.ProductoGenerico__c = false
            AND Pricebook2Id = :pricebookId
            AND IsActive = true
            ORDER BY Product2.Name ASC
            LIMIT :MAX_RESULTADOS
        ];

        List<PricebookEntry> filteredEntries = new List<PricebookEntry>(porCodigo);

        if (filteredEntries.size() < MAX_RESULTADOS) {
            Integer restantes = MAX_RESULTADOS - filteredEntries.size();

            // El "Product2.Name = null OR NOT LIKE" evita perder articulos sin
            // codigo: en SOQL, NOT (null LIKE '%x%') no evalua a true.
            List<PricebookEntry> porDescripcion = [
                SELECT Id, Pricebook2Id, Product2Id, UnitPrice, IsActive, Name, Product2.Name, ProductCode, ProductoGenerico__c, ExternalId__c
                FROM PricebookEntry
                WHERE ProductCode LIKE :searchQuery
                AND (Product2.Name = null OR (NOT Product2.Name LIKE :searchQuery))
                AND Product2.IsActive = true
                AND Product2.ProductoGenerico__c = false
                AND Pricebook2Id = :pricebookId
                AND IsActive = true
                ORDER BY Product2.Name ASC
                LIMIT :restantes
            ];

            filteredEntries.addAll(porDescripcion);
        }
        if(!searchGeneric){
            filteredEntries = filterProductsNoGeneric(filteredEntries);
        }

        List<ProductWarehouse__c> existencias = getExistenciasData(warehouseId, filteredEntries);
        return buildProductInformationList(filteredEntries, existencias);
    }

    // ---------------
    // Private Methods
    // ---------------

    private static List<ProductWarehouse__c> getExistenciasData(String almacenID, List<PricebookEntry> searchResults){
        List<String> productsId = new List<String>();
        for(PricebookEntry entry : searchResults){
            productsId.add(entry.Product2Id);
        }
        return [ 
            SELECT Id, Classification__c, ProductCode__c, ToBeSupplied__c, Product2__c, Location__c, Unity__c, Existencias__c, ToBeDelivered__c
            FROM ProductWarehouse__c 
            WHERE Warehouse__c = :almacenID 
            AND Product2__c IN :productsId
        ];
    }

    private static List<PricebookEntry> filterProductsNoGeneric(List<PricebookEntry> searchResults){
        List<PricebookEntry> entriesToReturn = new List<PricebookEntry>();
        for(PricebookEntry entry : searchResults){
            if(entry.ProductoGenerico__c == false){
                entriesToReturn.add(entry);
            }
        }
        return entriesToReturn;
    }

    private static List<ProductInformation> buildProductInformationList(List<PricebookEntry> pricebookEntries, List<ProductWarehouse__c> warehouseData) {
        Map<String, ProductWarehouse__c> warehouseMap = new Map<String, ProductWarehouse__c>();
        for(ProductWarehouse__c existencia : warehouseData) {
            warehouseMap.put(existencia.Product2__c, existencia);
        }

        List<ProductInformation> productInfoList = new List<ProductInformation>();
        for(PricebookEntry entry : pricebookEntries) {
            ProductInformation productInfo = new ProductInformation();
            
            // Pricebook Entry data
            productInfo.entryId = entry.Id;
            productInfo.pricebookId = entry.Pricebook2Id;
            productInfo.productId = entry.Product2Id;
            productInfo.unitPrice = entry.UnitPrice;
            productInfo.productName = entry.Product2.Name;
            productInfo.productCode = entry.ProductCode;
            productInfo.externalId = entry.ExternalId__c;
            productInfo.isGeneric = entry.ProductoGenerico__c;
            
            // Warehouse data (if exists)
            ProductWarehouse__c warehouseInfo = warehouseMap.get(entry.Product2Id);
            if(warehouseInfo != null) {
                productInfo.warehouseId = warehouseInfo.Id;
                productInfo.classification = warehouseInfo.Classification__c;
                productInfo.warehouseProductCode = warehouseInfo.ProductCode__c;
                productInfo.toBeSupplied = warehouseInfo.ToBeSupplied__c;
                productInfo.location = warehouseInfo.Location__c;
                productInfo.unity = warehouseInfo.Unity__c;
                productInfo.stock = warehouseInfo.Existencias__c;
                productInfo.toBeDelivered = warehouseInfo.ToBeDelivered__c;
            }
            
            productInfoList.add(productInfo);
        }
        
        return productInfoList;
    }

    // ---------------
    // Utility Classes
    // ---------------

    public class ProductInformation {
        // Pricebook Entry data
        @AuraEnabled public String entryId { get; set; }
        @AuraEnabled public String pricebookId { get; set; }
        @AuraEnabled public String productId { get; set; }
        @AuraEnabled public Decimal unitPrice { get; set; }
        @AuraEnabled public String productName { get; set; }
        @AuraEnabled public String productCode { get; set; }
        @AuraEnabled public String externalId { get; set; }
        @AuraEnabled public Boolean isGeneric { get; set; }
        
        // Warehouse data
        @AuraEnabled public String warehouseId { get; set; }
        @AuraEnabled public String classification { get; set; }
        @AuraEnabled public String warehouseProductCode { get; set; }
        @AuraEnabled public Decimal toBeSupplied { get; set; }
        @AuraEnabled public String location { get; set; }
        @AuraEnabled public String unity { get; set; }
        @AuraEnabled public Decimal stock { get; set; }
        @AuraEnabled public Decimal toBeDelivered { get; set; }
    }
}