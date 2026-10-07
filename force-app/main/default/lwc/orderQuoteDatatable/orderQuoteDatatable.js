import LightningDatatable from 'lightning/datatable';
import statusBadgeTemplate from './statusBadge.html';
import paymentBadgeTemplate from './paymentBadge.html';
import stockBadgeTemplate from './stockBadge.html';

export default class OrderQuoteDatatable extends LightningDatatable {
    static customTypes = {
        statusBadge: {
            template: statusBadgeTemplate,
            standardCellLayout: true,
            typeAttributes: ['variant']
        },
        paymentBadge: {
            template: paymentBadgeTemplate,
            standardCellLayout: true,
            typeAttributes: ['variant']
        },
        stockBadge: {
            template: stockBadgeTemplate,
            standardCellLayout: true,
            typeAttributes: ['variant']
        }
    };
}