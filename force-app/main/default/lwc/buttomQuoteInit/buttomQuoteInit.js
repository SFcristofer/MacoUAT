import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class GenerarCotizacionFlowLwc extends NavigationMixin(LightningElement) {
    @api flowName = 'Generar_Cotizacion'; // Nombre del Flow
    @api recordId; // ID del registro generado por el Flow

    handleFlowStart() {
        // Navegar al Flow incrustado
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/flow/${this.flowName}`
            }
        });
    }

    handleFlowStatusChange(event) {
        if (event.detail.status === 'FINISHED') {
            const outputVars = event.detail.outputVariables;
            let generatedRecordId;

            // Buscar el valor de salida del Flow
            outputVars.forEach((ov) => {
                if (ov.name === 'Var_Cotizacion_Id') {
                    generatedRecordId = ov.value;
                }
            });

            if (generatedRecordId) {
                console.log('Redirigiendo al registro con ID:', generatedRecordId);

                // Redirigir al registro generado
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: generatedRecordId,
                        actionName: 'view'
                    }
                });
            } else {
                console.error('No se encontró un recordId en las variables de salida.');
            }
        }
    }
}