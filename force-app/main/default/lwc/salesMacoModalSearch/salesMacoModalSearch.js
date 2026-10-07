import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class SalesMacoModalSearch extends LightningModal {
    @api pricebookid = ''
    @api almacenId = ''
    @api allowwarehousechange = false
    @api allowheaderedit = false
    @api recordid = ''
    @api orderheader
    formData = {};

    connectedCallback(){
    }

    changeHandler(event) {
        const { name, value, checked, type } = event.target;
        const isCheckbox = type === 'checkbox' || type === 'checkbox-button' || type === 'toggle';
        this.formData = { 
            ...this.formData, 
            [name]: isCheckbox ? checked : value,
        };
    }

    // -------------------
    // Product data format
    // -------------------

    sendProductsToWrapper(event) {
        const updatedData = event.detail.data.map(item => ({ ...item, genericProduct: false }));
        this.returnDataToParent(updatedData)
    }
    
    addGenericProduct(){
        const genericObject = {
            Quantity: this.formData.quantity,
            UnitPrice: this.formData.price,
            genericProduct: true,
            ProductCode: this.formData.name,
            Name: 'GENERICO',
        }
        this.returnDataToParent([genericObject])
    }

    // ---------------------
    // Close and return data
    // ---------------------

    returnDataToParent(dataToReturn){
        this.close(dataToReturn)
    }

    handleCancel(){
        this.close()
    }
}