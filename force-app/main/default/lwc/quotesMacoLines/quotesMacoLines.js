import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

// APEX
import getQuoteInfo from '@salesforce/apex/QuoteMacoLinesController.getQuoteInfo';
import getQuoteLines from '@salesforce/apex/QuoteMacoLinesController.getQuoteLines';
import insertQuoteLines from '@salesforce/apex/QuoteMacoLinesController.insertQuoteLines';
import updateQuoteLines from '@salesforce/apex/QuoteMacoLinesController.updateQuoteLines';
import deleteListOfQuoteLines from '@salesforce/apex/QuoteMacoLinesController.deleteListOfQuoteLines';
import getCreditoDisponible from '@salesforce/apex/CreditoClienteController.getCreditoDisponible';

// Modals
import SalesMacoModalSearch from "c/salesMacoModalSearch"
import SalesMacoModalStock from "c/salesMacoModalStock"

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
    { label: 'Clasificacion', fieldName: 'classification' },
    { label: 'Ubicacion', fieldName: 'location' },
    {
        type: "action",
        typeAttributes: {
            rowActions: { fieldName: "rowActions" },
        },
    },
];

// Hardcode
const MESSAGE_CONFIRM_CLEAR = 'Esta seguro que desea elminar todos los productos?'
const MESSAGE_CONFIRM_SAVE = 'Desea guardar sus cambios?'
const MESSAGE_CONFIRM_DELETE = 'Esta seguro que desea hacer esto'

const TOAST_VARIANT_SUCCESS = 'success'
const TOAST_VARIANT_INFO = 'info'
const TOAST_VARIANT_WARNING = 'warning'
const TOAST_VARIANT_ERROR = 'error'

const ROW_ACTION_DELETE = 'delete'
const ROW_ACTION_STOCK = 'stock'

export default class QuotesMacoLines extends LightningElement {

    // Quote
    @api recordId;
    quoteData;

    // Main render
    showSpinner = true
    showComponent = false
    productsEmpty = false
    showDeleteButton = false
    isModalOpen = false

    almacenId;
    pricebookName = ''
    columns = columns;
    creditoInfo

    get showCreditoDisponible() {
        return this.creditoInfo && !this.creditoInfo.errorMessage;
    }

    get creditoNoDisponible() {
        return this.creditoInfo && this.creditoInfo.errorMessage;
    }

    data = []
    originalData = []
    selectedLines = []
    recordsToDelete = []
    recordsToInsert = []
    recordsToUpate = []

    connectedCallback(){
        this.loadComponent('First Load')
    }

    loadComponent(context){
        console.log('Loading component: ', context)
        this.clearComponentData();
        this.apex_getQuoteInfo();
        this.apex_getQuoteLines();
    }

    syncComponent(){
        this.helperRenderDatatable(false)
        this.prepareDataForSave()
    }

    /** -------------------*/
    /** Delete entrypoints */
    /** -------------------*/

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

    editDataOnRowFromSave(dataEdited) {
        const updatedData = this.data.map(row => {
            const editedRow = dataEdited.find(edit => edit.Id === row.id || edit.id === row.id);
            return editedRow ? { ...row, ...editedRow } : row;
        });
        this.data = JSON.parse(JSON.stringify(updatedData));
        this.syncComponent();
    }

    // Lo que ya trae la cotización, para que el buscador pueda advertir
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
    // detecta como cambiada y la manda a updateQuoteLines.
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

    parseNewProductsToDatatable(data) {
        if (data !== undefined && data.length > 0) {
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
            if (this.data.length < 1) {
                this.data = parsedData;
            } else {
                this.data = [...this.data, ...parsedData];
            }
            if (this.data.length > 0) {
                this.productsEmpty = false;
            }
            this.syncComponent();
        }
    }

    /** ------------------------------------- */
    /** Apex Handling to retrieve information */
    /** ------------------------------------- */

    apex_getQuoteInfo(){
        getQuoteInfo({ quoteId: this.recordId })
        .then(data => {
            this.quoteData = data;
            if('PricebookName__c' in this.quoteData){
                this.pricebookName = this.quoteData['PricebookName__c']
            } 
            if('Warehouse__c' in this.quoteData){
                this.almacenId = this.quoteData['Warehouse__c']
            }
            this.apex_getCreditoDisponible()
        })
        .catch(err => {
            this.showNotificationError(err)
        });
    }

    apex_getCreditoDisponible(){
        if (!this.quoteData || !this.quoteData.AccountId) {
            return;
        }
        getCreditoDisponible({ accountId: this.quoteData.AccountId })
        .then(data => {
            this.creditoInfo = data;
        })
        .catch(err => {
            this.creditoInfo = null;
            console.log('Error apex_getCreditoDisponible', err);
        });
    }

    apex_getQuoteLines(){
        getQuoteLines({ quoteId: this.recordId })
        .then(data => {
            if(data.length>0){
                this.parseExistingQuoteLines(data)
            } else {
                this.productsEmpty = true  
                this.helperRenderDatatable(true)           
            }
        })
        .catch(err => {
            this.showNotificationError(err)
        })
        .finally(()=>{
            this.validateDeleteButton()
        })
    }

    // DML: Apex to Insert, Update and Delete

    apex_updateQuoteLines(stringToUpdate){
        return updateQuoteLines({jsonString:stringToUpdate})
    }

    apex_recordsToDelete(stringToDelete){
        return deleteListOfQuoteLines({quoteLinesDelete:stringToDelete})
    }

    apex_recordsToInsert(dataToSave){
        return insertQuoteLines({ jsonString: dataToSave })
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

    /** ------------ */
    /** Row Actions */
    /** ------------ */

    handleRowAction(event){
        const recordId = event.detail.row.id
        const actionName = event.detail.action.name;
        if(actionName==ROW_ACTION_DELETE){
            if(confirm(MESSAGE_CONFIRM_DELETE)){
                this.deleteRecordFromArray(recordId)
            }
        }
        if(actionName==ROW_ACTION_STOCK){
            SalesMacoModalStock.open({quoteLineId:recordId})
        }
    }

    /** -------------- */
    /** Modal handling */
    /** -------------- */

    openModalProducts(){
        if(this.isModalOpen){
            return
        }
        this.isModalOpen = true
        SalesMacoModalSearch.open({
            size: 'large',
            existinglines: this.buildExistingLines(),
            pricebookid:this.quoteData['Pricebook2Id'],
            almacenId: this.almacenId,
        })
        .then(data => {
            this.parseNewProductsToDatatable(data)
        })
        .catch(err => {
            this.showNotificationError(err)
        })
        .finally(() => {
            this.isModalOpen = false
        })
    }



    async executeApexCalls() {
        const promises = [];
    
        if (this.recordsToDelete.length > 0) {
            const recordsDelete = this.parseRecordsToDelete();
            promises.push(this.apex_recordsToDelete(recordsDelete));
        }
    
        if (this.recordsToInsert.length > 0) {
            const recordsInsert = this.parseRecordsToInsert();
            promises.push(this.apex_recordsToInsert(recordsInsert));
        }
    
        if (this.recordsToUpdate.length > 0) {
            const recordsUpdate = this.parseRecordsToUpdate();
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

    async prepareDataForSave() {
        this.initializeRecordLists();
        this.identifyRecordsToDelete();
        this.identifyRecordsToInsertAndUpdate();
        await this.executeApexCalls();
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
    
    handleRowSelection(event){
        this.selectedLines = event.detail.selectedRows
        this.validateDeleteButton()
    }

    validateDeleteButton(){
        if(this.selectedLines.length>1){
            this.showDeleteButton = true
        } else {
            this.showDeleteButton = false
        }
    }

    parseItemUpdate(item){
        return {
            id: 'id' in item ? item.id : null,
            quantity: 'quantity' in item ? item.quantity : null,
            unitPrice: 'unitPrice' in item ? item.unitPrice : null,
            totalPrice: null,
            name: 'productName' in item ? item.productName : null,
            productCode: 'productCode' in item ? item.productCode : null,
            description: 'description' in item ? item.description : null,
        };
    }

    parseItemInsert(item){
        return {
            description: 'productName' in item ? item.productName : null,
            product2Id: 'product2Id' in item ? item.product2Id : null,
            pricebookEntryId: 'pricebookEntryId' in item ? item.pricebookEntryId : null,
            pricebook2Id: 'pricebookId' in item? item.pricebookId:null,
            quantity: 'quantity' in item ? item.quantity : null,
            quoteId: this.recordId,
            unitPrice: 'unitPrice' in item ? item.unitPrice : null,
            productCode: 'productCode' in item ? item.productCode : null,
            generic: 'productoGenerico' in item ? item.productoGenerico : null
        };
    }

    parseExistingQuoteLines(existingQuoteLines){
        this.data = existingQuoteLines.map(item => ({
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

    helperRenderDatatable(show){
        if(show){
            this.showSpinner = false
            this.showComponent = true
        } else {
            this.showSpinner = true
            this.showComponent = false
        }
    }

    handleSaveEdit(event){
        event.preventDefault();
        const draftValues = event.detail.draftValues;
        this.editDataOnRowFromSave(draftValues)
    }

    handleClear(){
        if(confirm(MESSAGE_CONFIRM_CLEAR)){
            this.data = []
            this.productsEmpty = true
        }
    }

    addRowActions(){
        const rowActions = [
            { label: 'Eliminar', name: ROW_ACTION_DELETE },
        ];
        this.data = this.data.map(item => ({
            ...item,
            rowActions
        }))
    }

    /** --------------- */
    /** Private Helpers */
    /** --------------- */

    initializeRecordLists() {
        this.recordsToDelete = [];
        this.recordsToInsert = [];
        this.recordsToUpdate = [];
    }

    clearComponentData(){
        this.data = []
        this.originalData = []
        this.selectedLines = []
        this.recordsToDelete = [];
        this.recordsToInsert = [];
        this.recordsToUpdate = [];
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