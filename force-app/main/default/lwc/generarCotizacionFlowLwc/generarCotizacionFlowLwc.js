import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class RedirectToQuote extends NavigationMixin(LightningElement) {
    @api recordId; // El ID de la cotización pasada desde el Flow

    connectedCallback() {
        if (this.recordId) {
            console.log('Redirigiendo al registro de la cotización con ID:', this.recordId);

            // Redirigir a la Record Page específica para la Quote
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Quote', // Objeto relacionado
                    actionName: 'view', // Acción: Ver el registro
                },
            });
        } else {
            console.error('No se proporcionó un recordId para la redirección.');
        }
    }
}