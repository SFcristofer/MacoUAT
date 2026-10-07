import LightningModal from 'lightning/modal';
import { api } from 'lwc';

export default class ComprobantesDisplayTableModal extends LightningModal  {
    @api recordsdata = [];
    showTable = true
}