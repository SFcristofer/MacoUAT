import { api, LightningElement } from 'lwc';
import { NavigationMixin } from "lightning/navigation";

export default class SalesMacoLauncher extends NavigationMixin(LightningElement) {

    pageLocation = 'default'
    customTabApiName = 'SalesMacoTab'
    @api recordId;

    /**
     * 
     */
    connectedCallback() {
        this.validateRecordType();
    }

    /**
     * 
     * @returns 
     */
    validateRecordType() {
        if (!this.recordId) {
            console.log('Record ID is missing.');
            this.pageLocation = 'Home / No recordPage'
            return;
        }
        const recordPrefix = this.recordId.substring(0, 3);
        let objectType;
        if (recordPrefix === '001') {
            this.pageLocation = 'Account';
        } else if (recordPrefix === '801') {
            this.pageLocation = 'Order';
        } else if (recordPrefix === '006') {
            this.pageLocation = 'Opportunity';
        } else if (recordPrefix === '0Q0') {
            this.pageLocation = 'Quote';
        } else {
            this.pageLocation = 'Unknown';
        }
    }

    /**
     * 
     */
    openSalesMaco(){
        console.log('Opening Edit')
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: this.customTabApiName
            },
            state: {
                c__recordId: this.recordId
              }
          });
    }
}