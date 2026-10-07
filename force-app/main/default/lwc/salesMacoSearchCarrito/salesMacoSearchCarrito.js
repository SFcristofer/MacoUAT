import { api } from 'lwc';
import LightningModal from 'lightning/modal';

const columns = [
    { label: 'Name', fieldName: 'Name'},
    { label: 'Product Code', fieldName: 'ProductCode' },
    { label: 'Price', fieldName: 'UnitPrice'},
    { label: 'Cantidad', fieldName: 'Quantity'}
];


export default class SalesMacoSearchCarrito extends LightningModal {

    @api products = [];
    data = []
    columns = columns;

    connectedCallback() {
        console.log('Carrito: ', this.products)
        if(this.products.length>0){
            this.data=this.products
        }
    }
}