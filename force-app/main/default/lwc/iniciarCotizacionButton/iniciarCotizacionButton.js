import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class IniciarCotizacionButton extends NavigationMixin(LightningElement) {

    // Botón 1: Crear Visita
    handleVisita() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/flow/Crear_Registro_Objetivo_Visita'
            }
        });
    }

    // Botón 2: Iniciar Cotización
    handleCotizacion() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/flow/Generar_Cotizacion'
            }
        });
    }

    // Botón 3: Generar Pedido de Home
    handlePedidoHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url	: '/flow/Generar_Pedido_de_Home'
            }
        });
    }
}