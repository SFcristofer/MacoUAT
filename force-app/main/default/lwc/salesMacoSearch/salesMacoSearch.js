import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";

// Apex
import getPricebookInfo from "@salesforce/apex/SalesMacoSearchController.getPricebookInfo"
import getAllPricebookEntries from "@salesforce/apex/SalesMacoSearchController.getAllPricebookEntries"
import getPricebookEntriesFiltered from "@salesforce/apex/SalesMacoSearchController.getPricebookEntriesFiltered"
import getWarehouseInfo from "@salesforce/apex/SalesMacoSearchController.getWarehouseInfo"
import getActiveWarehouses from "@salesforce/apex/SalesMacoSearchController.getActiveWarehouses"
import updateOrderWarehouse from "@salesforce/apex/OrderMacoLinesController.updateOrderWarehouse"
import updateOrderHeaderFields from "@salesforce/apex/OrderMacoLinesController.updateOrderHeaderFields"

// Components
import SalesMacoModalStock from "c/salesMacoModalStock"

// Tabla propia en HTML plano (no lightning-datatable): así Cantidad es editable
// directo, sin el paso de "click al lápiz -> editar -> guardar" que pedía
// quitar el negocio, y las clases de color de Existencias son 100% nuestras
// (sin depender de que una clase cruce el shadow DOM de un componente base).
function getStockClass(stock) {
    if (stock > 5) {
        return 'ct-stock ct-stock-ok';
    }
    if (stock > 0) {
        return 'ct-stock ct-stock-low';
    }
    return 'ct-stock ct-stock-none';
}

const SEARCH_PURPOSE_ADD = 'add'
// Que hacer cuando el producto capturado ya existe en el pedido
const MERGE_APARTE = 'aparte'
const MERGE_SUMAR = 'sumar'
const SEARCH_PURPOSE_REPLACE = 'replace'
const SEARCH_PURPOSE_ENSAMBLE = 'ensamble'

const SALE_TYPE_OPTIONS = [
    { label: 'Crédito', value: 'Crédito' },
    { label: 'Contado', value: 'Contado' },
];

const DELIVERY_TYPE_OPTIONS = [
    { label: 'Mostrador', value: 'CR' },
    { label: 'Domicilio', value: 'ED' },
    { label: 'Entrega en Paquetería', value: 'EP' },
];

function toDateInputValue(value) {
    if (!value) {
        return '';
    }
    return String(value).slice(0, 10);
}

export default class SalesMacoSearch extends LightningElement {

    @track sortBy;
    @track sortDirection;
    @api searchpurpose = SEARCH_PURPOSE_ADD
    @api pricebookid = ''
    @api almacenid = ''
    @api recordid = ''
    @api allowwarehousechange = false
    @api allowheaderedit = false
    @api orderheader
    // Partidas que ya existen en el pedido o la cotizacion. Se usan solo para
    // advertir cuando se captura un producto repetido; no se modifican aqui.
    @api existinglines = []

    get showOrderHeader() {
        return this.orderheader && this.orderheader.pedido;
    }

    saleTypeOptions = SALE_TYPE_OPTIONS
    deliveryTypeOptions = DELIVERY_TYPE_OPTIONS
    headerTipoVenta = ''
    headerFecha = ''
    headerTipoEntregaCode = ''

    @track data = [] // This initializes the data empty
    @track warehouseOptions = []
    almacenData = {}
    productName = ''
    // Fuente unica de verdad de la seleccion, indexada por Id de
    // PricebookEntry. Antes habia dos listas (productsToAdd y
    // productsSavedBuffer) que se concatenaban al guardar; si un producto
    // quedaba en ambas se enviaba DUPLICADO. Con un mapa por Id eso es
    // imposible por construccion.
    @track selectedById = {}
    // Sin @track a propósito: el texto en vuelo de Cantidad no debe
    // disparar re-render (ver handleQuantityInput).
    _qtyDrafts = new Map()
    pricebookData = {}
    pricebookName = ''

    // Render boolean
    showProductList = false
    showSpinner = false
    showEmptyResponse = false
    showAddGenericProduct = false
    datatableAdd = true
    datatableRA = false
    searchProductGeneric = true

    connectedCallback(){
        this.apex_getPricebookInfo()
        this.apex_getWarehouseInfo()
        if(this.allowwarehousechange){
            this.apex_getActiveWarehouses()
        }
        if(this.allowheaderedit && this.orderheader){
            this.headerTipoVenta = this.orderheader.tipoVenta || ''
            this.headerFecha = toDateInputValue(this.orderheader.fecha)
            this.headerTipoEntregaCode = this.orderheader.tipoEntregaCode || ''
        }
        if((this.searchpurpose==SEARCH_PURPOSE_REPLACE)||(this.searchpurpose==SEARCH_PURPOSE_ENSAMBLE)){
            this.datatableAdd = false
            this.datatableRA = true
            this.searchProductGeneric = false
        }
    }

    /** ------------------- */
    /** Cambio de almacén   */
    /** ------------------- */

    apex_getActiveWarehouses(){
        getActiveWarehouses()
        .then(result => {
            this.warehouseOptions = result.map(wh => ({ label: wh.Name, value: wh.Id }));
        })
        .catch(err => {
            console.log('Error in getActiveWarehouses: ', err)
        })
    }

    handleWarehouseChange(event){
        const newWarehouseId = event.detail.value;
        if(!newWarehouseId || newWarehouseId === this.almacenid){
            return;
        }
        updateOrderWarehouse({ orderId: this.recordid, warehouseId: newWarehouseId })
        .then(() => {
            this.almacenid = newWarehouseId;
            this.apex_getWarehouseInfo();
            if(this.showProductList){
                this.searchProducts();
            }
        })
        .catch(err => {
            this.showNotificationError(err);
        })
    }

    showNotificationError(error){
        const message = (error && error.body && error.body.message) ? error.body.message : 'Ocurrió un error inesperado.';
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: 'error',
        }));
    }

    /** ------------------------------- */
    /** Edición del encabezado del pedido */
    /** ------------------------------- */

    handleHeaderTipoVentaChange(event){
        this.headerTipoVenta = event.detail.value;
        this.persistHeaderFields();
    }

    handleHeaderFechaChange(event){
        this.headerFecha = event.detail.value;
        this.persistHeaderFields();
    }

    handleHeaderTipoEntregaChange(event){
        this.headerTipoEntregaCode = event.detail.value;
        this.persistHeaderFields();
    }

    persistHeaderFields(){
        updateOrderHeaderFields({
            orderId: this.recordid,
            methodOfPayment: this.headerTipoVenta,
            effectiveDate: this.headerFecha,
            tipoEntrega: this.headerTipoEntregaCode,
        })
        .catch(err => {
            this.showNotificationError(err);
        })
    }

    /** ------------------ */
    /** Selección de filas  */
    /** ------------------ */

    // true = selección única (radio), usado en Reemplazar/Ensamblar
    get isSingleSelect() {
        return this.datatableRA;
    }

    get isAllSelected() {
        return this.data.length > 0 && this.data.every(row => row.isSelected);
    }

    handleSelectAllChange(event) {
        const checked = event.target.checked;
        this.data = this.data.map(row => ({ ...row, isSelected: checked }));
        this.updateProductsToAdd();
    }

    handleRowCheckboxChange(event) {
        const id = event.target.dataset.id;
        const checked = event.target.checked;
        const singleSelect = this.isSingleSelect;
        this.data = this.data.map(row => {
            if (row.Id === id) {
                return { ...row, isSelected: checked };
            }
            if (singleSelect && checked) {
                return { ...row, isSelected: false };
            }
            return row;
        });
        this.updateProductsToAdd();
    }

    // Sincroniza el mapa de seleccion con lo que se ve en la tabla.
    // Solo toca las filas presentes: lo capturado en busquedas anteriores
    // permanece en el mapa aunque ya no este en pantalla. Eso es lo que
    // elimina el paso de "Almacenar".
    updateProductsToAdd() {
        const mapa = { ...this.selectedById }

        // En seleccion unica (Reemplazar / Ensamblar) solo puede vivir un
        // producto: el mapa se reconstruye desde cero en cada cambio.
        if (this.isSingleSelect) {
            const elegido = this.data.find(row => row.isSelected)
            this.selectedById = elegido ? { [elegido.Id]: { ...elegido } } : {}
            return
        }

        this.data.forEach(row => {
            if (row.isSelected) {
                mapa[row.Id] = { ...row }
            } else {
                delete mapa[row.Id]
            }
        })
        this.selectedById = mapa
    }

    // ---- Panel de seleccionados ----

    // Equivale al lwc:elseif que tenia el spinner antes de que la tabla
    // quedara dentro de .ct-workarea: solo se muestra si no hay tabla.
    get showSpinnerBlock() {
        return !this.showProductList && this.showSpinner
    }

    get existingByProduct() {
        const idx = {}
        ;(this.existinglines || []).forEach(l => {
            if (l && l.productId) { idx[l.productId] = l }
        })
        return idx
    }

    // Marca los productos que ya estan en el pedido y precalcula lo que
    // necesita el template: LWC no evalua expresiones dentro del HTML.
    decorarSeleccion(row) {
        const yaEsta = this.existingByProduct[row.productId]
        const modo = row.mergeMode || MERGE_APARTE
        return {
            ...row,
            mergeMode: modo,
            hasExisting: !!yaEsta,
            existingQty: yaEsta ? yaEsta.quantity : 0,
            existingItemId: yaEsta ? yaEsta.id : null,
            claseSumar: modo === MERGE_SUMAR ? 'ct-merge-opt ct-merge-on' : 'ct-merge-opt',
            claseAparte: modo === MERGE_APARTE ? 'ct-merge-opt ct-merge-on' : 'ct-merge-opt'
        }
    }

    get selectedList() {
        return Object.values(this.selectedById).map(row => this.decorarSeleccion(row))
    }

    // Alterna entre sumar al renglon existente o agregar uno aparte.
    handleToggleMerge(event) {
        const id = event.currentTarget.dataset.id
        const modo = event.currentTarget.dataset.mode
        const fila = this.selectedById[id]
        if (!fila) { return }
        this.selectedById = { ...this.selectedById, [id]: { ...fila, mergeMode: modo } }
    }

    get selectedCount() {
        return this.selectedList.length
    }

    get hasSelection() {
        return this.selectedCount > 0
    }

    // El panel solo aplica al alta de productos. En Reemplazar y Ensamblar
    // se elige un unico producto y un acumulado no tiene sentido.
    get showSelectionPanel() {
        return this.searchpurpose == SEARCH_PURPOSE_ADD && !this.isSingleSelect
    }

    get showAddProductButton() {
        return this.hasSelection
    }

    // Quita un producto desde el panel. Si la fila esta visible en la tabla,
    // tambien se limpia ahi para que ambos lados coincidan.
    handleRemoveSelected(event) {
        const id = event.currentTarget.dataset.id
        const mapa = { ...this.selectedById }
        delete mapa[id]
        this.selectedById = mapa
        this._qtyDrafts.delete(id)
        this.data = this.data.map(row =>
            row.Id === id ? { ...row, Quantity: 0, isSelected: false } : row
        )
    }

    handleClearSelection() {
        if (!this.hasSelection) { return }
        if (!confirm('¿Quitar todos los productos seleccionados?')) { return }
        this.selectedById = {}
        this._qtyDrafts.clear()
        this.data = this.data.map(row => ({ ...row, Quantity: 0, isSelected: false }))
    }

    // Cantidad admite hasta 2 decimales.
    //
    // Antes esto se rompía por dos motivos, ambos en el mismo handler:
    //   1. this.data es @track. Reasignarlo en cada tecla re-renderiza el
    //      input, el atributo value se reescribe y el cursor salta al inicio.
    //      Al teclear "30.48" el cursor iba al principio tras cada dígito.
    //   2. Number("30.") es NaN y el "|| 0" lo convertía en 0, así que el
    //      punto decimal borraba lo capturado.
    //
    // Ahora mientras se teclea solo se guarda el texto crudo en un mapa NO
    // reactivo (sin re-render, sin salto de cursor) y el valor se normaliza y
    // se escribe en this.data hasta que el campo pierde el foco.
    handleQuantityInput(event) {
        this._qtyDrafts.set(event.target.dataset.id, event.target.value)
    }

    handleQuantityCommit(event) {
        const id = event.target.dataset.id
        const raw = this._qtyDrafts.has(id) ? this._qtyDrafts.get(id) : event.target.value
        this._qtyDrafts.delete(id)

        const value = this.normalizeQuantity(raw)
        // Reflejar el valor ya normalizado (p. ej. "30.486" -> 30.49, "" -> 0)
        event.target.value = value

        this.applyQuantity(id, value)
    }

    // Vuelca al modelo cualquier cantidad tecleada que aún no haya perdido el
    // foco. Red de seguridad para cuando el usuario teclea y hace clic directo
    // en Agregar/Almacenar.
    flushQuantityDrafts() {
        if (this._qtyDrafts.size === 0) { return }
        const pending = Array.from(this._qtyDrafts.entries())
        this._qtyDrafts.clear()
        pending.forEach(([id, raw]) => this.applyQuantity(id, this.normalizeQuantity(raw)))
    }

    applyQuantity(id, value) {
        const singleSelect = this.isSingleSelect
        this.data = this.data.map(row => {
            if (row.Id === id) {
                // Al capturar una cantidad > 0 se selecciona automático la fila
                // (no hace falta marcar el checkbox a mano). Si el usuario la
                // desmarca después manualmente, eso queda respetado: solo forzamos
                // el check hacia "true", nunca hacia "false" desde aquí.
                const isSelected = value > 0 ? true : row.isSelected
                return { ...row, Quantity: value, isSelected }
            }
            if (singleSelect && value > 0) {
                return { ...row, isSelected: false }
            }
            return row
        })
        this.updateProductsToAdd()
    }

    // Tolera estados intermedios ("30.", "") y la coma como separador decimal,
    // habitual en teclados es-MX. Redondea a 2 decimales de forma explícita:
    // el +EPSILON evita que 1.005 se vaya a 1.00 por el error de coma flotante.
    normalizeQuantity(raw) {
        if (raw === null || raw === undefined) { return 0 }
        const text = String(raw).trim().replace(',', '.')
        if (text === '' || text === '.') { return 0 }

        const parsed = Number(text)
        if (!isFinite(parsed) || parsed < 0) { return 0 }

        return Math.round((parsed + Number.EPSILON) * 100) / 100
    }

    handleStockButtonClick(event) {
        const productId = event.currentTarget.dataset.productid;
        SalesMacoModalStock.open({almacenId: this.almacenid, productId: productId })
    }

    /** --------------- */
    /** Modal functions */
    /** --------------- */

    // Ya no existe el paso intermedio de "Almacenar": la seleccion se acumula
    // sola al capturar cantidad y este boton envia todo de una vez.
    addProducts() {
        this.flushQuantityDrafts()
        this.dispatchEvent(new CustomEvent('addproducts', {
            detail: { data: this.selectedList }
        }));
        this.selectedById = {}
    }

    closeAndClearModal(){
        this.data = []
        this.productName = ''
        this.selectedById = {}
        this._qtyDrafts.clear()
        this.showProductList = false
        this.showSpinner = false
    }

    /** --------------- */
    /** Screen handling */
    /** --------------- */

    validatePricebookInfo(){
        if ('Name' in this.pricebookData) {
            this.pricebookName = this.pricebookData['Name']
        }
    }

    /** ------------------ */
    /** Searchbar handling */
    /** ------------------ */

    handleInputChange(event){
         this.productName = event.target.value;
    }

    searchProducts(){
        this.data = []
        this.showSpinner = true
        if((this.productName==null)||(this.productName=='')||(this.productName==undefined)){
            this.apex_getAllPricebookEntries()
        } else {
            this.apex_getPricebookEntriesFiltered()
        }
    }

    /** ------------- */
    /** Apex Handling */
    /** ------------- */

    apex_getWarehouseInfo(){
        getWarehouseInfo({warehouseId:this.almacenid})
        .then(data=>{
            this.almacenData = data
        })
        .catch(err=>{
            console.log('err: ', err)
        })
    }

    apex_getPricebookInfo(){
        getPricebookInfo({pricebookid:this.pricebookid})
        .then(data=> {
            this.pricebookData = data
            this.validatePricebookInfo()
        })
        .catch(err=>{
            console.log('err: ', err)
        })
    }

    apex_getAllPricebookEntries(){
        getAllPricebookEntries({pricebookId:this.pricebookid, warehouseId:this.almacenid, searchGeneric:this.searchProductGeneric})
        .then(result=>{
            this.dataTableShowResults(result)
        })
        .catch(err=>{
            console.log('Error in getAllPricebookEntries: ', err)
        })
        .finally(() => {
            this.showSpinner = false
        })
    }

    apex_getPricebookEntriesFiltered(){
        this.productName = this.productName.trim();
        getPricebookEntriesFiltered({pricebookId:this.pricebookid, warehouseId:this.almacenid, searchTerm:this.productName, searchGeneric:this.searchProductGeneric})
        .then(result=>{
            this.dataTableShowResults(result)
        })
        .catch(err=>{
            console.log('Error in getPricebookEntriesFiltered: ', err)
        })
        .finally(() => {
            this.showSpinner = false
        })
    }

    /** ------------------ */
    /** Tabla: resultados   */
    /** ------------------ */

    dataTableShowResults(result){
        if(result.length>0){
            this.data = result
            this.parseResults()
            this.showEmptyResponse = false
            this.showSpinner = false
            this.showProductList = true
        } else {
            this.showProductList = false
            this.showSpinner = false
            this.showEmptyResponse = true
        }
    }

    parseResults(){
        // Rehidratar: si un producto ya estaba seleccionado en una busqueda
        // anterior y vuelve a aparecer, debe reaparecer con su cantidad y su
        // palomita. Si no, el usuario cree que se perdio y lo captura otra vez.
        this.data = this.data.map(item => ({
            ...item,
            Id: item.entryId,
            Quantity: this.selectedById[item.entryId] ? this.selectedById[item.entryId].Quantity : 0,
            isSelected: !!this.selectedById[item.entryId],
            Name: item.productName,
            ProductCode: item.productCode,
            UnitPrice: item.unitPrice,
            stock: item.stock || 0,
            stockClass: getStockClass(item.stock || 0),
            toBeDelivered: item.toBeDelivered || 0,
            unity: item.unity || '',
            classification: item.classification || '',
            location: item.location || ''
        }));
    }


    /**
     * ---------------
     * Sort Functions
     * ---------------
     */

    handleSortByColumn(event) {
        const fieldname = event.currentTarget.dataset.field;
        const direction = this.sortBy === fieldname && this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.sortBy = fieldname;
        this.sortDirection = direction;
        this.sortData(fieldname, direction);
    }

    sortData(fieldname, direction) {
        let parseData = [...this.data];
        let keyValue = (a) => {
            return a[fieldname];
        };
        let isReverse = direction === 'asc' ? 1: -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        this.data = parseData;
    }
}