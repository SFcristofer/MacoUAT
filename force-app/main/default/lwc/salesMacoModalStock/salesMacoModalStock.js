import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getExistenciasFromLocal from '@salesforce/apex/ObtenerExistencias.getExistenciasFromLocal';

const columns = [
    { label: 'Almacen', fieldName: 'almacen' },
    { label: 'Existencias', fieldName: 'existencia'},
    { label: 'Comprometido', fieldName: 'comprometido' },
];

export default class SalesMacoModalStock extends LightningModal {

    data = [];
    columns = columns;
    @api almacenId = ''
    @api productId = ''
    
    connectedCallback(){
        
        this.apex_getExistenciasFromLocal()
    }

    /** ---- */
    /** Apex */
    /** ---- */

    apex_getExistenciasFromLocal() {
        console.log('MODAL_STOCK - almacenId: ', this.almacenId)
        console.log('MODAL_STOCK - productId: ', this.productId)
        getExistenciasFromLocal({productId: this.productId, almacenId: this.almacenId})
        .then(result => {
            console.log('MODAL_STOCK - Local stock result: ', result);
            this.data = result;
        })
        .catch(err => {
            console.log(err)
        })
    }

    /** ------- */
    /** Helpers */
    /** ------- */

    showNotification(title, message, variant) {
        const evt = new ShowToastEvent({
          title: title,
          message: message,
          variant: variant,
        });
        this.dispatchEvent(evt);
    }

    handleClose() {
        this.close();
    }
}