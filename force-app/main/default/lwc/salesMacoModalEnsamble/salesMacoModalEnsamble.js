import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class SalesMacoModalEnsamble extends LightningModal {

    @api pricebookid = ''

    connectedCallback(){
        console.log('SalesMacoModalReplace.connectedCallback()-pricebookid:', JSON.stringify(this.pricebookid))
        console.log('SalesMacoModalReplace.connectedCallback()-productToReplace:', JSON.stringify(this.productToReplace))
    }

    sendProductsToWrapper(event){
        const updatedData = event.detail.data.map(item => ({ ...item, genericProduct: false }));
        this.close(updatedData);
    }
}