import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFilteredRecords from '@salesforce/apex/OrderQuoteQuickFilterController.getFilteredRecords';
import getPicklistOptions from '@salesforce/apex/OrderQuoteQuickFilterController.getPicklistOptions';
import getDistinctValues from '@salesforce/apex/OrderQuoteQuickFilterController.getDistinctValues';

const PAGE_SIZE = 25;
const DEBOUNCE_MS = 400;

const ACTION_COLUMN = {
    type: 'action',
    typeAttributes: { rowActions: [{ label: 'Ver', name: 'view' }] }
};

// Clases GLOBALES de SLDS para colorear el Estatus. Las celdas de
// lightning-datatable viven en su propio shadow DOM: una clase definida en el
// CSS scoped de este componente (o de un customType propio) nunca las alcanza.
// Las utilidades de texto de SLDS sí son globales y por eso sí funcionan aquí.
const STATUS_CLASS_MAP = {
    Authorized: 'slds-text-color_success slds-text-bold',
    Accepted: 'slds-text-color_success slds-text-bold',
    Activated: 'slds-text-color_success slds-text-bold',
    Ready_to_Send: 'slds-text-color_warning slds-text-bold',
    'To Authorize': 'slds-text-color_warning slds-text-bold',
    'Pending approval': 'slds-text-color_warning slds-text-bold',
    'Back Order': 'slds-text-color_warning slds-text-bold',
    Unauthorized: 'slds-text-color_error slds-text-bold',
    Rejected: 'slds-text-color_error slds-text-bold',
    'Lost Sale': 'slds-text-color_error slds-text-bold'
};

function getStatusClass(status) {
    return STATUS_CLASS_MAP[status] || 'slds-text-color_weak';
}

// Superset de columnas disponibles por objeto. "visible" define el estado inicial;
// el usuario puede mostrar/ocultar cualquiera desde el selector de columnas.
const ORDER_COLUMN_DEFS = [
    {
        key: 'recordNumber',
        label: 'Pedido',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'recordNumber' }, target: '_blank' },
        visible: true
    },
    { key: 'externalId', label: 'Folio Zafiro', fieldName: 'externalId', visible: true },
    { key: 'accountNumber', label: 'Cliente', fieldName: 'accountNumber', visible: true },
    { key: 'accountName', label: 'Nombre', fieldName: 'accountName', visible: true },
    { key: 'ownerName', label: 'Propietario/Usuario', fieldName: 'ownerName', visible: true },
    { key: 'agentName', label: 'Vendedor/Agente', fieldName: 'agentName', visible: true },
    { key: 'recordDate', label: 'Fecha', fieldName: 'recordDate', type: 'date-local', visible: true },
    {
        key: 'status',
        label: 'Estatus',
        fieldName: 'status',
        cellAttributes: { class: { fieldName: 'statusClass' } },
        visible: true
    },
    { key: 'methodOfPayment', label: 'Método de Pago', fieldName: 'methodOfPayment', visible: true },
    { key: 'estatusFacturacion', label: 'Estatus Facturación', fieldName: 'estatusFacturacion', visible: false },
    { key: 'estatusSurtimiento', label: 'Estatus Surtimiento', fieldName: 'estatusSurtimiento', visible: false },
    { key: 'warehouseName', label: 'Almacén', fieldName: 'warehouseName', visible: false },
    { key: 'subTotal', label: 'Subtotal', fieldName: 'subTotal', type: 'currency', visible: true },
    { key: 'total', label: 'Total', fieldName: 'total', type: 'currency', visible: true }
];

const QUOTE_COLUMN_DEFS = [
    {
        key: 'recordNumber',
        label: 'Cotización',
        fieldName: 'recordUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'recordNumber' }, target: '_blank' },
        visible: true
    },
    { key: 'accountName', label: 'Cuenta', fieldName: 'accountName', visible: true },
    { key: 'ownerName', label: 'Propietario/Usuario', fieldName: 'ownerName', visible: true },
    { key: 'agentName', label: 'Vendedor/Agente', fieldName: 'agentName', visible: true },
    { key: 'recordDate', label: 'Fecha de Inicio', fieldName: 'recordDate', type: 'date-local', visible: true },
    { key: 'secondDate', label: 'Fecha de Expiración', fieldName: 'secondDate', type: 'date-local', visible: false },
    {
        key: 'status',
        label: 'Estatus',
        fieldName: 'status',
        cellAttributes: { class: { fieldName: 'statusClass' } },
        visible: true
    },
    { key: 'methodOfPayment', label: 'Método de Pago', fieldName: 'methodOfPayment', visible: true },
    { key: 'subTotal', label: 'Subtotal', fieldName: 'subTotal', type: 'currency', visible: true },
    { key: 'total', label: 'Total', fieldName: 'total', type: 'currency', visible: true },
    { key: 'lineItemCount', label: 'Partidas', fieldName: 'lineItemCount', type: 'number', visible: false }
];

// Las keys deben coincidir EXACTAMENTE con las de *_COLUMN_DEFS: así, ocultar una
// columna desde el selector oculta automáticamente su filtro correspondiente.
// type: 'text' (LIKE simple), 'multiselect' (picklist real, checkbox fijo) o
// 'search-select' (campo de texto/relación del ERP: se busca y se van agregando
// valores distintos vía GROUP BY, con chips removibles debajo).
const ORDER_FILTER_DEFS = [
    { key: 'recordNumber', label: 'Pedido', type: 'text' },
    { key: 'externalId', label: 'Folio Zafiro', type: 'text' },
    { key: 'accountNumber', label: 'Cliente', type: 'text' },
    { key: 'accountName', label: 'Nombre', type: 'text' },
    { key: 'ownerName', label: 'Propietario/Usuario', type: 'search-select' },
    { key: 'agentName', label: 'Vendedor/Agente', type: 'search-select' },
    { key: 'status', label: 'Estatus', type: 'multiselect' },
    { key: 'methodOfPayment', label: 'Método de Pago', type: 'multiselect' },
    { key: 'estatusFacturacion', label: 'Estatus Facturación', type: 'search-select' },
    { key: 'estatusSurtimiento', label: 'Estatus Surtimiento', type: 'search-select' },
    { key: 'warehouseName', label: 'Almacén', type: 'search-select' }
];

const QUOTE_FILTER_DEFS = [
    { key: 'recordNumber', label: 'Cotización', type: 'text' },
    { key: 'accountName', label: 'Cuenta', type: 'text' },
    { key: 'ownerName', label: 'Propietario/Usuario', type: 'search-select' },
    { key: 'agentName', label: 'Vendedor/Agente', type: 'search-select' },
    { key: 'status', label: 'Estatus', type: 'multiselect' },
    { key: 'methodOfPayment', label: 'Método de Pago', type: 'multiselect' }
];

export default class OrderQuoteQuickFilter extends NavigationMixin(LightningElement) {
    @api objectApiName = 'Order'; // 'Order' | 'Quote'

    @track columnDefs = [];
    @track filterDefs = [];
    @track filterValues = {};
    @track picklistOptionsByKey = {};
    @track searchTermByKey = {};
    @track suggestionsByKey = {};
    @track records = [];
    @track totals = { recordCount: 0, subTotalSum: 0, totalSum: 0 };

    dateFrom;
    dateTo;
    isLoading = false;
    isLoadingMore = false;
    enableInfiniteLoading = true;
    showColumnPicker = false;

    offset = 0;
    debounceTimeout;
    openDropdownKey;
    dropdownSnapshot = [];
    searchDebounceTimeouts = {};

    connectedCallback() {
        this.columnDefs = (this.objectApiName === 'Order' ? ORDER_COLUMN_DEFS : QUOTE_COLUMN_DEFS).map(c => ({ ...c }));
        this.filterDefs = this.objectApiName === 'Order' ? ORDER_FILTER_DEFS : QUOTE_FILTER_DEFS;
        this.setDefaultDateRangeToCurrentMonth();
        this.loadPicklistOptions();
        this.loadPage(true);
    }

    setDefaultDateRangeToCurrentMonth() {
        const now = new Date();
        const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
        const lastDay = new Date(now.getFullYear(), now.getMonth() + 1, 0);
        this.dateFrom = this.formatDateForInput(firstDay);
        this.dateTo = this.formatDateForInput(lastDay);
    }

    formatDateForInput(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    // ----------------
    // Column visibility
    // ----------------

    get visibleColumns() {
        const visibleDefs = this.columnDefs.filter(c => c.visible);
        return [
            ...visibleDefs.map(c => {
                const col = { label: c.label, fieldName: c.fieldName, type: c.type };
                if (c.typeAttributes) {
                    col.typeAttributes = c.typeAttributes;
                }
                if (c.cellAttributes) {
                    col.cellAttributes = c.cellAttributes;
                }
                return col;
            }),
            ACTION_COLUMN
        ];
    }

    toggleColumnPicker() {
        this.showColumnPicker = !this.showColumnPicker;
    }

    handleColumnToggle(event) {
        const key = event.target.dataset.key;
        const checked = event.target.checked;
        this.columnDefs = this.columnDefs.map(c => (c.key === key ? { ...c, visible: checked } : c));

        // Si se oculta la columna, también se oculta y limpia su filtro (si tiene uno)
        // para que no quede aplicando un filtro invisible al usuario.
        if (!checked && Object.prototype.hasOwnProperty.call(this.filterValues, key)) {
            const updatedFilters = { ...this.filterValues };
            delete updatedFilters[key];
            this.filterValues = updatedFilters;
            if (this.openDropdownKey === key) {
                this.openDropdownKey = null;
            }
            this.reload();
        }
    }

    // ----------------
    // Filters
    // ----------------

    // Un solo renglón de filtros (estilo Excel): texto libre para campos de texto,
    // botón + dropdown de checkboxes (estilo Zafiro) para campos de picklist.
    // Solo se muestran los filtros cuya columna correspondiente esté visible.
    get renderableFilterDefs() {
        const visibleColumnKeys = new Set(this.columnDefs.filter(c => c.visible).map(c => c.key));
        return this.filterDefs.filter(f => visibleColumnKeys.has(f.key)).map(filterDef => {
            if (filterDef.type === 'text') {
                return { ...filterDef, isText: true, isMultiselect: false, isSearchSelect: false };
            }
            if (filterDef.type === 'search-select') {
                const selected = this.filterValues[filterDef.key] || [];
                const suggestions = (this.suggestionsByKey[filterDef.key] || [])
                    .filter(v => !selected.includes(v))
                    .map(v => ({ value: v }));
                return {
                    ...filterDef,
                    isText: false,
                    isMultiselect: false,
                    isSearchSelect: true,
                    searchTerm: this.searchTermByKey[filterDef.key] || '',
                    suggestions,
                    hasSuggestions: suggestions.length > 0,
                    selectedPills: selected.map(v => ({ label: v, name: v })),
                    hasSelectedPills: selected.length > 0
                };
            }
            const selected = this.filterValues[filterDef.key] || [];
            const options = (this.picklistOptionsByKey[filterDef.key] || []).map(opt => ({
                ...opt,
                checked: selected.includes(opt.value)
            }));
            return {
                ...filterDef,
                isText: false,
                isMultiselect: true,
                isSearchSelect: false,
                options,
                isOpen: this.openDropdownKey === filterDef.key,
                buttonLabel: selected.length > 0 ? `${filterDef.label} (${selected.length})` : filterDef.label
            };
        });
    }

    loadPicklistOptions() {
        this.filterDefs
            .filter(f => f.type === 'multiselect')
            .forEach(filterDef => {
                getPicklistOptions({ objectApiName: this.objectApiName, logicalFieldKey: filterDef.key })
                    .then(options => {
                        this.picklistOptionsByKey = {
                            ...this.picklistOptionsByKey,
                            [filterDef.key]: options.map(o => ({ label: o.label, value: o.value }))
                        };
                    })
                    .catch(err => {
                        console.log('Error cargando picklist ' + filterDef.key, err);
                    });
            });
    }

    handleTextFilterChange(event) {
        const key = event.target.dataset.key;
        const value = event.target.value;
        this.filterValues = { ...this.filterValues, [key]: value };
        this.debounceReload();
    }

    toggleDropdown(event) {
        const key = event.currentTarget.dataset.key;
        if (this.openDropdownKey === key) {
            this.openDropdownKey = null;
            return;
        }
        this.dropdownSnapshot = this.filterValues[key] ? [...this.filterValues[key]] : [];
        this.openDropdownKey = key;
    }

    handleOptionCheckboxChange(event) {
        const key = event.target.dataset.key;
        const value = event.target.dataset.value;
        const checked = event.target.checked;
        const current = new Set(this.filterValues[key] || []);
        if (checked) {
            current.add(value);
        } else {
            current.delete(value);
        }
        this.filterValues = { ...this.filterValues, [key]: Array.from(current) };
    }

    handleApplyDropdown() {
        this.openDropdownKey = null;
        this.reload();
    }

    handleCancelDropdown(event) {
        const key = event.currentTarget.dataset.key;
        this.filterValues = { ...this.filterValues, [key]: this.dropdownSnapshot };
        this.openDropdownKey = null;
    }

    // ----------------
    // Search-select filters (buscar + agregar + chips removibles)
    // ----------------

    handleSearchSelectInputChange(event) {
        const key = event.target.dataset.key;
        const term = event.target.value;
        this.searchTermByKey = { ...this.searchTermByKey, [key]: term };
        clearTimeout(this.searchDebounceTimeouts[key]);
        this.searchDebounceTimeouts[key] = setTimeout(() => this.fetchSuggestions(key, term), DEBOUNCE_MS);
    }

    fetchSuggestions(key, term) {
        getDistinctValues({ objectApiName: this.objectApiName, logicalFieldKey: key, searchTerm: term })
            .then(values => {
                this.suggestionsByKey = { ...this.suggestionsByKey, [key]: values };
            })
            .catch(err => {
                console.log('Error fetchSuggestions ' + key, err);
            });
    }

    handleAddSearchSelectValue(event) {
        const key = event.currentTarget.dataset.key;
        const value = event.currentTarget.dataset.value;
        const current = this.filterValues[key] || [];
        if (!current.includes(value)) {
            this.filterValues = { ...this.filterValues, [key]: [...current, value] };
        }
        this.searchTermByKey = { ...this.searchTermByKey, [key]: '' };
        this.suggestionsByKey = { ...this.suggestionsByKey, [key]: [] };
        this.reload();
    }

    handleRemoveSearchSelectValue(event) {
        const key = event.currentTarget.dataset.key;
        const removedValue = event.detail.item.name;
        const current = this.filterValues[key] || [];
        this.filterValues = { ...this.filterValues, [key]: current.filter(v => v !== removedValue) };
        this.reload();
    }

    handleDateFromChange(event) {
        this.dateFrom = event.target.value;
        this.reload();
    }

    handleDateToChange(event) {
        this.dateTo = event.target.value;
        this.reload();
    }

    get activeFilterChips() {
        const chips = [];
        this.filterDefs.forEach(filterDef => {
            const value = this.filterValues[filterDef.key];
            if (!value || (Array.isArray(value) && value.length === 0)) {
                return;
            }
            const displayValue = Array.isArray(value) ? value.join(', ') : value;
            chips.push({ key: filterDef.key, label: `${filterDef.label}: ${displayValue}` });
        });
        if (this.dateFrom || this.dateTo) {
            chips.push({ key: '__dateRange', label: `Fecha: ${this.dateFrom || '...'} a ${this.dateTo || '...'}` });
        }
        return chips;
    }

    get hasActiveFilters() {
        return this.activeFilterChips.length > 0;
    }

    handleClearFilters() {
        this.filterValues = {};
        this.dateFrom = undefined;
        this.dateTo = undefined;
        this.template.querySelectorAll('[data-filter-input]').forEach(input => {
            input.value = null;
        });
        this.reload();
    }

    debounceReload() {
        clearTimeout(this.debounceTimeout);
        this.debounceTimeout = setTimeout(() => this.reload(), DEBOUNCE_MS);
    }

    reload() {
        this.offset = 0;
        this.records = [];
        this.enableInfiniteLoading = true;
        this.loadPage(true);
    }

    // ----------------
    // Data loading (server-side, lazy/infinite scroll)
    // ----------------

    buildFilters() {
        const filters = { ...this.filterValues };
        if (this.dateFrom) {
            filters.dateFrom = this.dateFrom;
        }
        if (this.dateTo) {
            filters.dateTo = this.dateTo;
        }
        return filters;
    }

    // Genera la URL real del registro (respeta My Domain/contexto) para poder
    // abrirla en una pestaña nueva desde la columna de folio.
    attachRecordUrls(rows) {
        return Promise.all(
            rows.map(row =>
                this[NavigationMixin.GenerateUrl]({
                    type: 'standard__recordPage',
                    attributes: { recordId: row.id, objectApiName: this.objectApiName, actionName: 'view' }
                }).then(url => ({
                    ...row,
                    recordUrl: url,
                    statusClass: getStatusClass(row.status)
                }))
            )
        );
    }

    loadPage(isInitialLoad) {
        if (isInitialLoad) {
            this.isLoading = true;
        }
        getFilteredRecords({
            objectApiName: this.objectApiName,
            filters: this.buildFilters(),
            pageSize: PAGE_SIZE,
            pageOffset: this.offset
        })
            .then(result => this.attachRecordUrls(result.records).then(rowsWithUrls => ({ ...result, records: rowsWithUrls })))
            .then(result => {
                this.records = isInitialLoad ? result.records : [...this.records, ...result.records];
                this.totals = result.totals;
                this.offset += result.records.length;
                if (result.records.length < PAGE_SIZE) {
                    this.enableInfiniteLoading = false;
                }
            })
            .catch(err => {
                console.log('Error loadPage', err);
                this.enableInfiniteLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error al cargar registros',
                        message: (err && err.body && err.body.message) || 'Ocurrió un error inesperado.',
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
                this.isLoadingMore = false;
            });
    }

    handleLoadMore() {
        if (!this.enableInfiniteLoading || this.isLoadingMore) {
            return;
        }
        this.isLoadingMore = true;
        this.loadPage(false);
    }

    handleRefresh() {
        this.reload();
    }

    // ----------------
    // Row actions
    // ----------------

    handleRowAction(event) {
        if (event.detail.action.name === 'view') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: event.detail.row.id,
                    objectApiName: this.objectApiName,
                    actionName: 'view'
                }
            });
        }
    }

    // ----------------
    // Display helpers
    // ----------------

    get tabLabel() {
        return this.objectApiName === 'Order' ? 'Pedidos' : 'Cotizaciones';
    }

    get recordCountLabel() {
        return `${this.totals.recordCount || 0} registro(s)`;
    }
}