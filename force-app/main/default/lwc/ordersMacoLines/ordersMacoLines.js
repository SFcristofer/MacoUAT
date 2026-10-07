import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

// APEX
import getOrderInfo from '@salesforce/apex/OrderMacoLinesController.getOrderInfo';
import getOrderLines from '@salesforce/apex/OrderMacoLinesController.getOrderLines';
import insertOrderLines from '@salesforce/apex/OrderMacoLinesController.insertOrderLines';
import updateOrderLines from '@salesforce/apex/OrderMacoLinesController.updateOrderLines';
import deleteListOfOrderLines from '@salesforce/apex/OrderMacoLinesController.deleteListOfOrderLines';
import getCreditoDisponible from '@salesforce/apex/CreditoClienteController.getCreditoDisponible';

// Modals
import SalesMacoModalReplace from "c/salesMacoModalReplace"
import SalesMacoModalEnsamble from "c/salesMacoModalEnsamble"
import SalesMacoModalStock from "c/salesMacoModalStock"
import SalesMacoModalSearch from "c/salesMacoModalSearch"


// Config
const columns = [
    { label: 'Código', fieldName: 'productName' },
    { label: 'Descripción', fieldName: 'productCode' },
    { label: 'Cantidad', fieldName: 'quantity', editable: true },
    { label: 'Precio', fieldName: 'unitPrice', editable: true },
    { label: 'Precio Total', fieldName: 'totalPrice', editable: true },
    { label: 'Product Description', fieldName: 'description', editable: true },
    {
        label: 'Existencias',
        fieldName: 'existencias',
        type: 'number',
        typeAttributes: {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }
    },
    { label: 'Clasificación', fieldName: 'classification' },
    { label: 'Ubicación', fieldName: 'location' },
    {
        type: "action",
        typeAttributes: {
            rowActions: { fieldName: "rowActions" },
        },
    },
];

// El pedido solo se puede modificar mientras está en Borrador (validation
// rule LockRecordAfterDraft en Order); en cualquier otro estatus las columnas
// se muestran de solo lectura, sin columna de acciones.
const columnsReadOnly = columns
    .filter(col => col.type !== 'action')
    .map(col => (col.editable ? { ...col, editable: false } : col));

const ORDER_STATUS_DRAFT = 'Draft';

const DELIVERY_TYPE_LABELS = {
    CR: 'Mostrador',
    ED: 'Domicilio',
    EP: 'Entrega en Paquetería',
};


// Hardcode
const MESSAGE_CONFIRM_CLEAR = 'Esta seguro que desea elminar todos los productos?'
const MESSAGE_CONFIRM_SAVE = 'Desea guardar sus cambios?'
const MESSAGE_CONFIRM_DELETE = 'Esta seguro que desea hacer esto'

const TOAST_VARIANT_SUCCESS = 'success'
const TOAST_VARIANT_INFO = 'info'
const TOAST_VARIANT_WARNING = 'warning'
const TOAST_VARIANT_ERROR = 'error'

const ROW_ACTION_REPLACE = 'replace'
const ROW_ACTION_DELETE = 'delete'
const ROW_ACTION_STOCK = 'stock'

export default class OrdersMacoLines extends LightningElement {

    almacenId;
    @api recordId;
    orderData;

    // Render
    showSpinner = true
    showComponent = false
    productsEmpty = false
    showButtonReplace = false
    showButtonEnsamble = false
    showButtonProducts = false
    showButtonDelete = false
    isModalOpen = false

    // Info
    pricebookName = ''
    totalPrice = 0
    creditoInfo
    orderIsDraft = true

    get orderIsLocked() {
        return !this.orderIsDraft;
    }

    get showCreditoDisponible() {
        return this.creditoInfo && !this.creditoInfo.errorMessage;
    }

    get creditoNoDisponible() {
        return this.creditoInfo && this.creditoInfo.errorMessage;
    }

    // Datatable
    data = []
    originalData = []
    selectedLines = []
    columns = columns;

    // Apex DML control
    recordsToDelete = []
    recordsToInsert = []
    recordsToUpate = []    

    connectedCallback(){
        this.loadComponent('ConnectedCallback')
    }

    loadComponent(context){
        console.log('Loading component: ', context)
        this.clearComponentData();
        this.apex_getOrderInfo();
        this.apex_getOrderLines();
    }

    syncComponent(){
        this.helperRenderDatatable(false)
        this.prepareDataForSave()
    }

    async prepareDataForSave() {
        this.initializeRecordLists();
        this.identifyRecordsToDelete();
        this.identifyRecordsToInsertAndUpdate();

        // Debug only
        console.log('Records to delete: ', JSON.stringify(this.recordsToDelete));
        console.log('Records to insert: ', JSON.stringify(this.recordsToInsert));
        console.log('Records to update: ', JSON.stringify(this.recordsToUpdate));

        await this.executeApexCalls();
    }

    async executeApexCalls() {
        const promises = [];
        if (this.recordsToDelete.length > 0) {
            console.log('There are records to delete');
            const recordsDelete = this.parseRecordsToDelete();
            console.log('Records to delete: ', JSON.stringify(recordsDelete));
            promises.push(this.apex_recordsToDelete(recordsDelete));
        }
        if (this.recordsToInsert.length > 0) {
            console.log('There are records to insert');
            const recordsInsert = this.parseRecordsToInsert();
            console.log('Records to insert: ', JSON.stringify(recordsInsert));
            promises.push(this.apex_recordsToInsert(recordsInsert));
        }
        if (this.recordsToUpdate.length > 0) {
            console.log('There are records to update');
            const recordsUpdate = this.parseRecordsToUpdate();
            console.log('Records to update: ', JSON.stringify(recordsUpdate));
            promises.push(this.apex_updateQuoteLines(recordsUpdate));
        }
        try {
            await Promise.all(promises);
            this.loadComponent('Load after update');
            this.showNotification('Éxito', 'Productos guardados correctamente', TOAST_VARIANT_SUCCESS);
        } catch (error) {
            console.error('Error during Apex calls:', error);
            this.showNotificationError(error);
            this.loadComponent('Reload after error');
        }
    }

    /** ----------- */
    /** Sync points */
    /** ----------- */

    editDataOnRowFromSave(dataEdited){
        console.log('Editing data on row from save: ', dataEdited)
        const updatedData = this.data.map(row => {
            const editedRow = dataEdited.find(edit => edit.id === row.id);
            return editedRow ? { ...row, ...editedRow } : row;
        });
        this.data = JSON.parse(JSON.stringify(updatedData));
        console.log('Data after edit: ', JSON.stringify(this.data))
        this.syncComponent()
    }

    buildOrderHeader(){
        return {
            pedido: this.orderData.ZF_Pedido_ID__c || this.orderData.OrderNumber,
            cliente: this.orderData.Account ? this.orderData.Account.Name : '',
            vendedor: this.orderData.Owner ? this.orderData.Owner.Name : '',
            tipoVenta: this.orderData.Method_of_Payment__c || '',
            fecha: this.orderData.EffectiveDate,
            tipoEntrega: DELIVERY_TYPE_LABELS[this.orderData.Tipo_Entrega_Venta__c] || this.orderData.Tipo_Entrega_Venta__c || '',
            tipoEntregaCode: this.orderData.Tipo_Entrega_Venta__c || '',
        };
    }

    openModalProducts(){
        if(this.isModalOpen){
            return
        }
        this.isModalOpen = true
        SalesMacoModalSearch.open({
            size: 'large',
            existinglines: this.buildExistingLines(),
            pricebookid:this.orderData['Pricebook2Id'],
            almacenId: this.almacenId,
            allowwarehousechange: this.orderIsDraft && this.productsEmpty,
            allowheaderedit: this.orderIsDraft,
            recordid: this.recordId,
            orderheader: this.buildOrderHeader()
        })
        .then(data => {
            if(data!=undefined){
                this.parseNewProductsToDatatable(data)
                this.syncComponent()
            } else {
                // Sin productos nuevos: si el usuario cambió el almacén y canceló,
                // refrescamos igual para que this.almacenId no quede desincronizado.
                this.apex_getOrderInfo()
            }
        })
        .catch(err => {
            this.showNotificationError(err)
        })
        .finally(() => {
            this.isModalOpen = false
        })
    }

    openModalEnsamble(){
        SalesMacoModalEnsamble.open({
            pricebookid:this.orderData['Pricebook2Id'],
        })
        .then(data => {
            this.showButtonEnsamble = false
            if(data!=undefined){
                this.parseNewProductsToDatatable(data, true)
                this.syncComponent()
            }
        })
        .catch(err => {
            this.showNotificationError(err)
        })
    }

    openModalReplace(recordId){
        console.log('Abriendo Modal Reemplazar - Record: ', recordId)
        SalesMacoModalReplace.open({
            pricebookid:this.orderData['Pricebook2Id'],
        })
        .then(data => {
            if(data!=undefined){
                this.parseNewProductsToDatatable(data)
                this.deleteRecordFromArray(recordId)
            }
        })
        .catch(err => {
            this.showNotificationError(err)
        })
    }

    /** ------------------------------------- */
    /** Apex Handling to retrieve information */
    /** ------------------------------------- */

    

    apex_getOrderInfo(){
        getOrderInfo({ orderId: this.recordId })
        .then(data => {
            this.orderData = data;
            this.orderIsDraft = this.orderData.Status === ORDER_STATUS_DRAFT;
            this.columns = this.orderIsDraft ? columns : columnsReadOnly;
            this.validateOrderPricebook()
            this.valudateButtonProducts()
            if('Warehouse__c' in this.orderData){
                this.almacenId = this.orderData['Warehouse__c']
            }
            this.apex_getCreditoDisponible()
        })
        .catch(err => {
            this.showNotificationError(err)
        });
    }

    apex_getCreditoDisponible(){
        if (!this.orderData || !this.orderData.AccountId) {
            return;
        }
        getCreditoDisponible({ accountId: this.orderData.AccountId })
        .then(data => {
            this.creditoInfo = data;
        })
        .catch(err => {
            this.creditoInfo = null;
            console.log('Error apex_getCreditoDisponible', err);
        });
    }

    apex_getOrderLines(){
        getOrderLines({ orderId: this.recordId })
        .then(data => {
            if(data.length>0){
                this.parseExistingOrderLines(data)
            } else {
                this.productsEmpty = true                
            }
        })
        .catch(err => {
            this.showNotificationError(err)
        });
    }

    // DML: Parse Insert, Update and Delete

    parseRecordsToDelete(){
        var itemsDelete = []
        this.recordsToDelete.forEach(item => {
            itemsDelete.push(item.id)
        })
        return itemsDelete.join(',')
    }

    parseRecordsToInsert(){
        var itemsInsert = []
        this.recordsToInsert.forEach(item => {
            const parsedItem = this.parseItemInsert(item)
            itemsInsert.push(parsedItem);
        })
        return JSON.stringify(itemsInsert)
    }

    parseRecordsToUpdate(){
        var itemsUpdate = []
        this.recordsToUpdate.forEach(item => {
            const parsedItem = this.parseItemUpdate(item)
            itemsUpdate.push(parsedItem);
        })
        return JSON.stringify(itemsUpdate)
    }

    // DML: Apex to Insert, Update and Delete

    apex_updateQuoteLines(stringToUpdate){
        return updateOrderLines({jsonString:stringToUpdate})
    }

    apex_recordsToDelete(stringToDelete){
        return deleteListOfOrderLines({orderLinesDelete:stringToDelete})
    }

    apex_recordsToInsert(dataToSave){
        return insertOrderLines({jsonString:dataToSave})
    }

    /** ------------ */
    /** Row Actions */
    /** ------------ */

    handleRowAction(event){
        const recordId = event.detail.row.id
        const actionName = event.detail.action.name;

        if(actionName==ROW_ACTION_REPLACE){
            this.openModalReplace(recordId)
        }
        if(actionName==ROW_ACTION_STOCK){   
            SalesMacoModalStock.open({quoteLineId:recordId})
        }
        if(actionName==ROW_ACTION_DELETE){
            if(confirm(MESSAGE_CONFIRM_DELETE)){
                this.deleteRecordFromArray(recordId)
            }
        }
    }

    /** --------------- */
    /** Private Helpers */
    /** --------------- */

    // Parsing function after Modal Ensamble or Modal replace
    // Lo que ya trae pedido, para que el buscador pueda advertir
    // cuando se captura un producto repetido. Incluye las partidas aun no
    // guardadas: si no, se avisaria solo de la primera repeticion.
    buildExistingLines(){
        return (this.data || []).map(row => ({
            id: row.id,
            productId: row.productId,
            productName: row.productName,
            quantity: Number(row.quantity) || 0
        }))
    }

    // Suma la cantidad al renglon que ya existe, en vez de crear otro.
    // No hace falta Apex: al modificar la fila, la maquinaria de guardado la
    // detecta como cambiada y la manda a updateOrderLines / updateQuoteLines.
    mergeIntoExistingRow(item){
        const idx = this.data.findIndex(row => row.productId === item.productId)
        if (idx < 0) { return false }
        const actual = Number(this.data[idx].quantity) || 0
        const suma = actual + (Number(item.Quantity) || 0)
        const precio = Number(this.data[idx].unitPrice) || 0
        const copia = [...this.data]
        copia[idx] = { ...copia[idx], quantity: suma, totalPrice: suma * precio }
        this.data = copia
        return true
    }

    parseNewProductsToDatatable(data, deleteSelected=false){
        if(data!=undefined){
            if(data.length>0){
                // Los marcados como "Sumar" se integran al renglon existente;
                // el resto sigue el camino normal de alta.
                const aSumar = data.filter(item => item.mergeMode === 'sumar' && item.hasExisting)
                const aAgregar = data.filter(item => !(item.mergeMode === 'sumar' && item.hasExisting))
                aSumar.forEach(item => {
                    if (!this.mergeIntoExistingRow(item)) { aAgregar.push(item) }
                })

                const parsedData = aAgregar.map(item => ({
                    pricebookEntryId: item.entryId,
                    pricebookId: item.pricebookId,
                    productId: item.productId,
                    productCode: item.productCode || item.ProductCode,
                    productName: item.productName || item.Name,
                    quantity: Number(item.Quantity) || 1,
                    unitPrice: Number(item.unitPrice || item.UnitPrice) || 0,
                    productoGenerico: item.isGeneric || item.genericProduct || false,
                    newProduct: true,
                }));
                if(this.data.length<1){
                    this.data = parsedData;
                } else {
                    this.data = [...this.data, ...parsedData];
                }
                if(this.data.length>0){
                    this.productsEmpty = false
                }
                if(deleteSelected){
                    this.deleteSelectedLines()
                }
            }
        }
    }

    identifyRecordsToDelete() {
        const currentIds = this.data.map(item => item.id);
        this.recordsToDelete = this.originalData.filter(
            originalRecord => !currentIds.includes(originalRecord.id)
        );
    }

    identifyRecordsToInsertAndUpdate() {
        this.data.forEach(currentRecord => {
            if (currentRecord.newProduct==true) {
                this.recordsToInsert.push(currentRecord);
            } else if ( currentRecord.newProduct==false ) {
                const originalRecord = this.originalData.find(item => item.Id === currentRecord.Id);
                const { rowActions, ...originalWithoutActions } = originalRecord;
                const { rowActions: _, ...currentWithoutActions } = currentRecord;
                if (JSON.stringify(originalWithoutActions) !== JSON.stringify(currentWithoutActions)) {
                    this.recordsToUpdate.push(currentRecord);
                }
            }
        });
    }

    parseExistingOrderLines(existingOrderLines){
        this.data = existingOrderLines.map(item => ({
            id: item.id,
            productId: item.productId,
            productCode: item.productCode,
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            totalPrice: item.totalPrice,
            description: item.description,
            productoGenerico: item.productoGenerico,
            existencias: item.existencias,
            classification: item.classification,
            location: item.location,
            newProduct: false,
        }));
        this.originalData = JSON.parse(JSON.stringify(this.data));
        this.addRowActions();
        this.productsEmpty = false;
        this.helperRenderDatatable(true);
    }
    
    handleRowSelection(event){
        if(!this.orderIsDraft){
            return
        }
        if(event.detail.selectedRows.length==1){
            this.showButtonReplace = true
            this.showButtonEnsamble = false
            this.showButtonDelete = false
        } else if (event.detail.selectedRows.length > 1){
            this.showButtonReplace = false
            this.showButtonEnsamble = true
            this.showButtonDelete = true
        } else {
            this.showButtonReplace = false
            this.showButtonEnsamble = false
            this.showButtonDelete = false
        }
        this.selectedLines = event.detail.selectedRows
    }

    /** ------------------- */
    /** Delete entry points */
    /** ------------------- */

    deleteRecordFromArray(recordToDelete) {
        const recordIndex = this.data.findIndex(item => item.id === recordToDelete);
        if (recordIndex !== -1) {
            this.data = [...this.data.slice(0, recordIndex), ...this.data.slice(recordIndex + 1)];
        }
        this.syncComponent()
    }

    deleteMultipleProducts(){
        if(confirm(MESSAGE_CONFIRM_DELETE)){
            const idsToDelete = this.selectedLines.map(record => record.id);
            const updatedData = this.data.filter(record => !idsToDelete.includes(record.id));
            this.data = JSON.parse(JSON.stringify(updatedData));
            this.syncComponent()
        }
    }

    deleteSelectedLines(){
        this.selectedLines.forEach(item => {
            this.deleteRecordFromArray(item.id)
        })
    }

    parseItemUpdate(item){
        return {
            id: 'id' in item ? item.id : null,
            quantity: 'quantity' in item ? item.quantity : null,
            unitPrice: 'unitPrice' in item ? item.unitPrice : null,
            totalPrice: 'totalPrice' in item ? item.totalPrice : null,
            name: 'Name' in item ? item.Name : null,
            productCode: 'productCode' in item ? item.productCode : null,
            description: 'description' in item ? item.description : null
        };
    }

    parseItemInsert(item){
        return {
            description: 'productName' in item ? item.productName : null,
            product2Id: 'productId' in item ? item.productId : null,
            pricebookEntryId: 'pricebookEntryId' in item ? item.pricebookEntryId : null,
            pricebook2Id: 'pricebookId' in item? item.pricebookId:null,
            quantity: 'quantity' in item ? item.quantity : null,
            orderId: this.recordId,
            unitPrice: 'unitPrice' in item ? item.unitPrice : null,
            productCode: 'productCode' in item ? item.productCode : null,
            generic: 'productoGenerico' in item ? item.productoGenerico : null
        };
    }

    handleSaveEdit(event){
        event.preventDefault();
        const draftValues = event.detail.draftValues;
        this.editDataOnRowFromSave(draftValues)
    }

    addRowActions() {
        this.data = this.data.map(item => {
            const rowActions = [
                { label: 'Ver Stock', name: ROW_ACTION_STOCK },
                { label: 'Eliminar', name: ROW_ACTION_DELETE },
            ];
    
            if (item.ProductoGenerico__c) {
                rowActions.unshift({
                    label: 'Reemplazar',
                    name: ROW_ACTION_REPLACE
                });
            }
            return {
                ...item,
                rowActions
            };
        });
    }

    validateOrderPricebook(){
        if ('PricebookName__c' in this.orderData) {
            this.pricebookName = this.orderData.PricebookName__c;
        }
        this.helperRenderDatatable(true)
    }

    valudateButtonProducts(){
        this.showButtonProducts = this.orderIsDraft && ('PricebookName__c' in this.orderData);
    }

    initializeRecordLists() {
        this.recordsToDelete = [];
        this.recordsToInsert = [];
        this.recordsToUpdate = [];
    }

    clearComponentData(){
        console.log('Cleaning component data')
        this.data = [];
        this.originalData = [];
        this.selectedLines = [];
        this.recordsToDelete = [];
        this.recordsToInsert = [];
        this.recordsToUpdate = [];
        this.showButtonDelete = false;
        this.showButtonEnsamble = false;
    }

    helperRenderDatatable(show){
        if(show){
            this.showSpinner = false
            this.showComponent = true
        } else {
            this.showSpinner = true
            this.showComponent = false
        }
    }

    /** ------------------------ */
    /** Toast Event Notification */
    /** ------------------------ */

    showNotificationError(error){
        console.log('LWC_ERROR: ', JSON.stringify(error))
        console.log(error.body.pageErrors)
        this.showNotification('Error', JSON.stringify(error), TOAST_VARIANT_ERROR)
    }

    showNotification(title, message, variant) {
        const evt = new ShowToastEvent({
          title: title,
          message: message,
          variant: variant,
        });
        this.dispatchEvent(evt);
    }
}