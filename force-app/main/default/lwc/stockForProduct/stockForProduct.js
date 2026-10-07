import { LightningElement, api } from 'lwc';

// Apex
import obtenerExistencias from '@salesforce/apex/ObtenerExistencias.obtenerExistencias';
import obtenerProductZafiroId from '@salesforce/apex/ObtenerExistencias.obtenerProductZafiroId';

const ALMACEN_VALID = ['001','004','007','023','026','028']
const columns = [
    { label: 'Almacen', fieldName: 'AlmacenName' },
    { label: 'Existencias', fieldName: 'Existencias' }
]

export default class StockForProduct extends LightningElement {

    data = []
    columns = columns;
    productExternalId;
    showSpinner = true;
    emptyData = false;
    @api recordId;

    connectedCallback(){
        console.log('StockForProduct.connectedCallback()-recordId: ', this.recordId)
        this.runIntegration()
    }

    runIntegration() {
        console.log('Running integration');
        this.showSpinner = true;
        this.apex_obtenerProductZafiroId()
    }

    /** ---- */
    /** Apex */
    /** ---- */

    apex_obtenerProductZafiroId(){
        console.log('apex_obtenerProductZafiroId()-start')
        obtenerProductZafiroId({productId:this.recordId})
        .then(data=>{
            console.log('obtenerProductZafiroId-data: ', data)
            this.productExternalId = data
            this.apex_obtenerExistencias();
        })
        .catch(err=>{
            console.error(err);
            this.showSpinner = false;
        })
    }
        
    apex_obtenerExistencias() {
        obtenerExistencias({ articuloId: this.productExternalId  })
            .then(result => {
                console.log('apex_obtenerExistencias()-result: ', result, typeof result, result.length);
                if (result.length > 0) {
                    this.mapAlamacenNames(result);
                } else {
                    this.emptyData = true
                    this.showSpinner = false;
                }
            })
            .catch(err => {
                console.error(err);
                this.validateError(err)
                this.showSpinner = false;
            });
    }

    /** -------- */
    /** Handlers */
    /** -------- */

    handleClick(){
        this.runIntegration()
    }

    /** ------- */
    /** Helpers */
    /** ------- */
    
    mapAlamacenNames(result) {
        this.data = result
        .filter(item => ALMACEN_VALID.includes(item.AlmacenID))
        .map(item => ({
            AlmacenName: 'Almacen ' + item.AlmacenID,
            Existencias: item.Existencias
        }));
        this.showSpinner=false
        this.emptyData = false
    }
    
    validateError(error){
        let errorMessage = ''
        let errorTittle = ''
        if(error.status==500){
            console.log('error.body.message: ', error.body.message)
            errorTittle = 'Error de Servidor'
            errorMessage = error.body.message
        }
        this.showNotification(errorTittle, errorMessage, 'error')
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