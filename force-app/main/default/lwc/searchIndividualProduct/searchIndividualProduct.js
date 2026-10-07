import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

// Apex
import getProductByProductCode from "@salesforce/apex/SearchIndividualProductController.getProductByProductCode"
import getProductByName from "@salesforce/apex/SearchIndividualProductController.getProductByName"
import getPossibleProducts from "@salesforce/apex/SearchIndividualProductController.getPossibleProducts"
import getSpecificPricebookEntry from "@salesforce/apex/SearchIndividualProductController.getSpecificPricebookEntry"
import getProductExistencias from "@salesforce/apex/SearchIndividualProductController.getProductExistencias"

const PRICEBOOK_CHARACTARES = '01s'
const SEARCH_CODE = 'code';
const SEARCH_NAME = 'name';

const SCREEN_SPINNER = 'spinner';
const SCREEN_POSSIBLE = 'possible';
const SCREEN_SINGLE = 'single';
const SCREEN_NO_RECORDS = 'noRecords';
const SCREEN_EXISTENCIAS = 'existencias';

// Record to test
// https://maco--uat.sandbox.lightning.force.com/lightning/r/Quote/0Q0WD000001dlsv0AA/view
// SELECT Id, Product2.ProductCode FROM PricebookEntry WHERE Pricebook2Id='01sal000001GBa1AAG'

export default class SearchIndividualProduct extends LightningElement {

    // Variables that come from the parent component or API
    @api recordId;
    @api recordIdParameter;
    @api almacenIdParameter;

    data;
    pricebookId;
    searchKey = ''
    existenciasErrorMessage = '';
    selectedSearchKey = SEARCH_CODE;
    productsToAdd = []


    singleProduct = {
        entryId:'',
        productName: '',
        productCode: '',
        productId: '',
        quantity:0,
        price:0,
        comprometido: '',
        unidadMedida: '',
        clasificacion: '',
        ubicacion: ''
    }

    // Datatable configuration
    data_possible = [];
    data_existencias = [];
    columns_existencias = [
        { label: 'Almacen', fieldName: 'almacenName' },
        { label: 'Existencias', fieldName: 'almacenExistencias' }
    ];
    columns_posibble = [
        { label: 'Name', fieldName: 'productName' },
        { label: 'Code', fieldName: 'productCode' },
    ];

    // Screen management
    showDataPossible = false;
    showExistencias = false;
    showSingleProduct = false;
    showSpinner = false;
    showNoRecords = false;
    showExistenciasError = false;
    showExistenciasTable = false

    connectedCallback() {
        this.validateInputVariables()
    }

    // --------------
    // Event handlers
    // --------------

    handleUpdate(){
        if(this.singleProduct.quantity<1){
            this.showNotification('Cantidad', 'Debe indicar una cantidad', 'error')
            return
        }
        this.productsToAdd = [
            {
                Id:this.singleProduct.entryId,
                Pricebook2Id: this.pricebookId,
                Product2Id: this.singleProduct.productId,
                UnitPrice: this.singleProduct.price,
                IsActive: this.singleProduct.isActive,
                Name:  this.singleProduct.productName,
                ProductCode:this.singleProduct.productCode,
                ExternalId__c: this.singleProduct.externalId,
                Quantity: this.singleProduct.quantity,
                ProductoGenerico__c:false,
            }
        ]
        this.dispatchEvent(new CustomEvent('addproducts', {
            detail: { data: this.productsToAdd }
        }));
    }

    handleInputQuantity(event){
        // parseInt truncaba: parseInt("30.48") === 30. La cantidad admite
        // hasta 2 decimales.
        const parsed = parseFloat(String(event.target.value).replace(',', '.'));
        this.singleProduct.quantity = isFinite(parsed) && parsed >= 0
            ? Math.round((parsed + Number.EPSILON) * 100) / 100
            : 0;
    }

    handleInputPrice(event){
        this.singleProduct.price = parseFloat(event.target.value);
    }

    handleVerExistencias(){
        this.screenSelect(SCREEN_EXISTENCIAS);
    }

    handleVerProductInfo(){
        this.screenSelect(SCREEN_SINGLE);
    }

    handleSearchKeyChange(event) {
        this.searchKey = event.target.value;
    }

    handleSearchClick(){
        if(this.isEmpty(this.searchKey)){
            this.showNotification('Input Error', 'Please enter a search key.', 'error');
            return;
        }
        if(this.searchKey.charAt(0) === '%'){
            this.apex_getPossibleProducts(this.searchKey.slice(1));
        } else {
            if(this.selectedSearchKey == SEARCH_CODE){
                this.apex_getProductByProductCode();
            } else if(this.selectedSearchKey == SEARCH_NAME) {
                this.apex_getProductByName();
            } 
        }   
    }

    handlePossibleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length === 0) {
            return;
        }
        const selected = selectedRows[0];
        const datatable = this.template.querySelector('#datatable-possible');
        if (datatable) {
            datatable.selectedRows = [];
        }
        this.apex_getSpecificPricebookEntry(selected.entryId);
    }

    // Old for button in the datatable
    handleSelectPossibleRecord(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'add') {
            this.apex_getSpecificPricebookEntry(row.entryId);
        }
    }

    // ----
    // Apex
    // ----

    apex_getProductExistencias(){
        getProductExistencias({productId:this.singleProduct.productId})
        .then(data=>{
            if(data.length > 0){
                this.data_existencias = data.map(item=>{
                    item.almacenName = item.WarehouseName__c || 'N/A';
                    item.almacenExistencias = item.Existencias__c || 0;
                    return item;
                });
                this.showExistenciasTable = true;
                this.showExistenciasError = false;
            } else if (this.data_existencias.length == 0){
                this.existenciasErrorMessage = 'No hay existencias para este producto';
                this.showExistenciasTable = false;
                this.showExistenciasError = true;
            }
        })
        .catch(error=> {
            console.log('Error from Apex getProductExistencias: ', error);
        })
    }

    apex_getSpecificPricebookEntry(entryId){
        this.screenSelect(SCREEN_SPINNER);
        getSpecificPricebookEntry({pricebookEntryId: entryId})
        .then(data=>{
            this.screenSelect(SCREEN_SINGLE);
        })
        .catch(error=>{
            console.error('Error from Apex getSpecificPricebookEntry: ', error);
        });
    }

    apex_getPossibleProducts(searchString){
        this.screenSelect(SCREEN_SPINNER);
        getPossibleProducts({searchTerm:searchString, pricebookId:this.pricebookId})
        .then(data=>{
            if(data==null){
                this.showNotification('Not found', 'No se encontro ningun nombre o codigo: ' + searchString, 'info');
                this.screenSelect(SCREEN_NO_RECORDS);
            } else {
                this.data_possible = data;
                this.screenSelect(SCREEN_POSSIBLE);
            }
        })
        .catch(error=>{
            console.error('Error from Apex getProductByProductCode: ', error);
        })
    }

    apex_getProductByProductCode(){
        this.screenSelect(SCREEN_SPINNER);
        getProductByProductCode({productCode: this.searchKey, pricebookId: this.pricebookId, almacenId: this.almacenIdParameter})
        .then(data=>{
            if((data==null)||(data==undefined)){
                this.showNotification('Not found', ' No se encontro un producto con el codigo: ' + this.searchKey, 'info');
                this.screenSelect(SCREEN_NO_RECORDS);
            } else {
                this.mapResultToSingleProduct(data);
                this.screenSelect(SCREEN_SINGLE);
            }
        })
        .catch(error=>{
            console.log('Error from Apex getProductByProductCode: ', error);
            console.log('Error message: ', error.body?.message);
            console.log('Error details: ', JSON.stringify(error));
            console.log('Error stack: ', error.stack);
        })
    }
    
    apex_getProductByName(){
        this.screenSelect(SCREEN_SPINNER);
        getProductByName({productCode: this.searchKey, pricebookId: this.pricebookId, almacenId: this.almacenIdParameter})
        .then(data=>{
            if((data==null)||(data==undefined)){
                this.showNotification('Not found', ' No se encontro un producto con el nombre: ' + this.searchKey, 'info');
                this.screenSelect(SCREEN_NO_RECORDS);
            } else {
                this.mapResultToSingleProduct(data);
                this.screenSelect(SCREEN_SINGLE);
            }
        })
        .catch(error=>{
            console.error('Error from Apex getProductByName: ', error);
        })
    }

    mapResultToSingleProduct(data) {
        console.log('Mapping result to single product: ', data);

        this.singleProduct.entryId = data.entryId;
        this.singleProduct.productName = data.productName;
        this.singleProduct.productCode = data.productCode;
        this.singleProduct.price = data.unitPrice;
        this.singleProduct.productId = data.productId;
        this.singleProduct.isActive = data.isActive;
        this.singleProduct.externalId = data.externalId;

        this.singleProduct.unidadMedida = data.unidadMedida;
        this.singleProduct.ubicacion = data.ubicacion;
        this.singleProduct.clasificacion = data.clasificacion;
        this.singleProduct.comprometido = data.comprometido;

        this.apex_getProductExistencias();
    }

    // -----------------
    // Reactive screens
    // -----------------

    screenSelect(option){
        if(option == SCREEN_POSSIBLE){
            this.showDataPossible = true;
            this.showSingleProduct = false;
            this.showSpinner = false;
            this.showNoRecords = false;
            this.showExistencias = false;
        } else if(option == SCREEN_SINGLE){
            this.showDataPossible = false;
            this.showSingleProduct = true;
            this.showSpinner = false;
            this.showNoRecords = false;
            this.showExistencias = false;
        } else if (option == SCREEN_SPINNER) {
            this.showDataPossible = false;
            this.showSingleProduct = false;
            this.showSpinner = true;
            this.showNoRecords = false;
            this.showExistencias = false;
        } else if (option == SCREEN_NO_RECORDS) {
            this.showDataPossible = false;
            this.showSingleProduct = false;
            this.showSpinner = false;
            this.showNoRecords = true;
            this.showExistencias = false;
        } else if (option == SCREEN_EXISTENCIAS) {
            this.showDataPossible = false;
            this.showSingleProduct = false;
            this.showSpinner = false;
            this.showNoRecords = false;
            this.showExistencias = true;
        } else {
            console.error('Invalid screen option: ', option);
        }
    }

    // ------------------
    // Validation Helpers
    // ------------------

    validateInputVariables() {
        console.log('Validating input variables...');
        console.log('recordId: ', this.recordId);
        console.log('recordIdParameter: ', this.recordIdParameter);
        console.log('almacenIdParameter: ', this.almacenIdParameter);

        if(this.validPricebookId(this.recordId)) {
            this.pricebookId = this.recordId;
        } else if(this.validPricebookId(this.recordIdParameter)) {
            this.pricebookId = this.recordIdParameter;
        } else {
            console.error('Invalid Pricebook ID provided.');
        }

        if (!this.almacenIdParameter || 
            this.almacenIdParameter === '' || 
            this.almacenIdParameter.trim() === '') {
            this.almacenIdParameter = null;
        }
    }

    validPricebookId(value){
        return this.isValidString(value)&&(this.isPricebookId(value));
    }

    isValidString(value) {
        return typeof value === 'string' && value.trim() !== '';
    }

    isPricebookId(id) {
        return typeof id === 'string' && id.startsWith(PRICEBOOK_CHARACTARES);
    }

    isEmpty(str) {
        return str === null || str === undefined || str === '';
    }

    // -------------
    // Notifications
    // -------------

    showNotification(title, message, variant) {
        const evt = new ShowToastEvent({
          title: title,
          message: message,
          variant: variant,
        });
        this.dispatchEvent(evt);
    }

    // -------
    // Getters
    // -------

    get isProductCode() {
        return this.selectedSearchKey === SEARCH_CODE;
    }

    get isProductName() {
        return this.selectedSearchKey === SEARCH_NAME;
    }

    handleCheckboxChange(event) {
        const selected = event.target.dataset.key;
        this.selectedSearchKey = selected;
    }
}