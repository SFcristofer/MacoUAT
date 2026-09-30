@RestResource(urlMapping='/UpdateExistencias/*')
global with sharing class UpdateExistencias {
    global class ExistenciaWrapper {
        public String almacenId;
        public String articuloId;
        public Decimal existencia;
        public Decimal porEntregar;
        public Decimal porSurtir;
        public String ubicacion;
        public String clasificacion;
    }
    
    global class ResponseWrapper {
        public String status;
        public String message;
        public String errorCode;
        public Integer updatedCount;
        public List<String> errors;
        
        public ResponseWrapper(String status, String message, String errorCode) {
            this.status = status;
            this.message = message;
            this.errorCode = errorCode;
        }
        public ResponseWrapper(String status, String message, String errorCode, Integer updatedCount, List<String> errors) {
            this.status = status;
            this.message = message;
            this.errorCode = errorCode;
            this.updatedCount = updatedCount;
            this.errors = errors;
        }
    }
    
    @HttpPost
    global static ResponseWrapper doPost() {
        try {
            RestRequest req = RestContext.request;
            String body = req.requestBody.toString();
            List<ExistenciaWrapper> data = (List<ExistenciaWrapper>) JSON.deserialize(body, List<ExistenciaWrapper>.class);
            // Bulk processing
            Map<String, ExistenciaWrapper> keyToWrapper = new Map<String, ExistenciaWrapper>();
            Set<String> warehouseCodes = new Set<String>();
            Set<String> productExternalIds = new Set<String>();
            for (ExistenciaWrapper ew : data) {
                if (ew.almacenId != null && ew.articuloId != null) {
                    String key = ew.almacenId + '|' + ew.articuloId;
                    keyToWrapper.put(key, ew);
                    warehouseCodes.add(ew.almacenId);
                    productExternalIds.add(ew.articuloId);
                }
            }
            // Query all matching ProductWarehouse__c records
            List<ProductWarehouse__c> existenciaList = [
                SELECT Id, Name, Existencias__c, ToBeDelivered__c, ToBeSupplied__c, Location__c, Classification__c,
                       Warehouse__r.Code__c, Product2__r.ExternalId__c
                FROM ProductWarehouse__c
                WHERE Warehouse__r.Code__c IN :warehouseCodes
                AND Product2__r.ExternalId__c IN :productExternalIds
            ];
            // Map for fast lookup
            Map<String, ProductWarehouse__c> keyToExistencia = new Map<String, ProductWarehouse__c>();
            for (ProductWarehouse__c pw : existenciaList) {
                String key = pw.Warehouse__r.Code__c + '|' + pw.Product2__r.ExternalId__c;
                keyToExistencia.put(key, pw);
            }
            List<ProductWarehouse__c> toUpdate = new List<ProductWarehouse__c>();
            List<String> errors = new List<String>();
            Integer updatedCount = 0;
            for (ExistenciaWrapper ew : data) {
                String key = ew.almacenId + '|' + ew.articuloId;
                if (keyToExistencia.containsKey(key)) {
                    ProductWarehouse__c pw = keyToExistencia.get(key);
                    pw.Existencias__c = ew.existencia;
                    pw.ToBeDelivered__c = ew.porEntregar;
                    pw.ToBeSupplied__c = ew.porSurtir;
                    pw.Location__c = ew.ubicacion;
                    pw.Classification__c = ew.clasificacion;
                    toUpdate.add(pw);
                } else {
                    errors.add('No ProductWarehouse record found for Warehouse Code: ' + ew.almacenId +
                        ' and Product ExternalId: ' + ew.articuloId);
                }
            }
            if (!toUpdate.isEmpty()) {
                try {
                    update toUpdate;
                    updatedCount = toUpdate.size();
                } catch (DmlException dmlEx) {
                    errors.add('DML error: ' + dmlEx.getMessage());
                }
            }
            String status = (errors.isEmpty() ? 'success' : (updatedCount > 0 ? 'partial_success' : 'error'));
            String message = 'Records updated: ' + updatedCount + (errors.isEmpty() ? '' : '. Errors: ' + String.join(errors, '; '));
            return new ResponseWrapper(status, message, (errors.isEmpty() ? null : 'PARTIAL_OR_ERROR'), updatedCount, errors);
        } catch (QueryException qe) {
            return new ResponseWrapper('error', 'Query error: ' + qe.getMessage(), 'QUERY_ERROR');
        } catch (DmlException dmlEx) {
            return new ResponseWrapper('error', 'DML error: ' + dmlEx.getMessage(), 'DML_ERROR');
        } catch (JSONException jsonEx) {
            return new ResponseWrapper('error', 'JSON parsing error: ' + jsonEx.getMessage(), 'JSON_ERROR');
        } catch (Exception ex) {
            return new ResponseWrapper('error', 'Unexpected error: ' + ex.getMessage(), 'GENERAL_ERROR');
        }
    }
}