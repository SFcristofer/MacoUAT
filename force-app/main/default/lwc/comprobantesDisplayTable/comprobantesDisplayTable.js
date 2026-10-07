import { LightningElement, api } from 'lwc';
import obtenerAntiguedadSaldo from "@salesforce/apex/ObtenerAntiguedadSaldos.obtenerAntiguedadSaldo"
import comprobantesDisplayTableModal from 'c/comprobantesDisplayTableModal';

export default class ComprobantesDisplayTable extends LightningElement {

    SCREEN_SPINNER = 'spinner'
    SCREEN_TABLE = 'table'
    SCREEN_EMPTY = 'empty'

    @api recordId;

    showMessage = false
    showSpinner = false
    showTable = false

    displayMessage = ''
    apexError = ''

    data;
    dataFormatted;
    dataTotals = {
        Rango1Value: 0,
        Rango2Value: 0,
        Rango3Value: 0,
        Rango4Value: 0,
        Rango5Value: 0,
        SaldoActual: 0,
        SaldoPorVencer: 0,
        SaldoVencido: 0,
        SaldoFavor: 0
    }

    connectedCallback(){
        this.renderTable()
    }

    renderTable(){
        this.screenSelect(this.SCREEN_SPINNER)
        this.apex_obtenerAntiguedadSaldo()
    }

    apex_obtenerAntiguedadSaldo(){
        obtenerAntiguedadSaldo({clienteId:this.recordId})
        .then(result => {
            if (result.length == 0){
                this.setErrorScreen('No se encontraron registros para mostrar', '')
            } else if(result.length > 0){
                console.log('Datos obtenidos:', result);
                this.data = result
                this.screenSelect(this.SCREEN_TABLE)
            }
        })
        .catch(error => {
            this.setErrorScreen(`Error: Pase el siguiente mensaje a su administrador: `,error.body.message)
        })
    }

    setErrorScreen(mainError,apexError){
        this.displayMessage = mainError;
        this.apexError = apexError
        this.screenSelect(this.SCREEN_EMPTY)
    }

    screenSelect(option){
        if(option==this.SCREEN_SPINNER){
            this.showMessage = false
            this.showSpinner = true
            this.showTable = false
        } else if(option==this.SCREEN_TABLE){
            this.formatTableData()
            this.showMessage = false
            this.showSpinner = false
            this.showTable = true
        } else if(option==this.SCREEN_EMPTY){
            this.showMessage = true
            this.showSpinner = false
            this.showTable = false
        }
    }

    formatTableData(){

        this.dataTotals = {
            Rango1Value: 0,
            Rango2Value: 0,
            Rango3Value: 0,
            Rango4Value: 0,
            Rango5Value: 0,
            SaldoActual: 0,
            SaldoPorVencer: 0,
            SaldoVencido: 0,
            SaldoFavor: 0
        };
    
        this.dataFormatted = this.data.map(item => {
        
            // Calculate totals (keep as numbers for accurate math)
            this.dataTotals.Rango1Value += item.Rango1Value || 0;
            this.dataTotals.Rango2Value += item.Rango2Value || 0;
            this.dataTotals.Rango3Value += item.Rango3Value || 0;
            this.dataTotals.Rango4Value += item.Rango4Value || 0;
            this.dataTotals.Rango5Value += item.Rango5Value || 0;
            this.dataTotals.SaldoActual += item.SaldoActual || 0;
            this.dataTotals.SaldoPorVencer += item.SaldoPorVencer || 0;
            this.dataTotals.SaldoVencido += item.SaldoVencido || 0;
            this.dataTotals.SaldoFavor += item.SaldoFavor || 0;


            console.log('Raw Fecha:', item.Fecha);
            let formattedFecha = this.formatDateCorrectly(item.Fecha);
            console.log('Formatted Fecha:', formattedFecha);

            console.log('Raw FechaVencimiento:', item.FechaVencimiento);
            let formattedFechaVencimiento = this.formatDateCorrectly(item.FechaVencimiento);
            console.log('Formatted FechaVencimiento:', formattedFechaVencimiento);
        
            return {
                ...item,
                formattedFecha: new Date(item.Fecha).toLocaleDateString(),
                formattedFechaVencimiento: new Date(item.FechaVencimiento).toLocaleDateString(),
                // Format numeric values to 2 decimal places
                Rango1Value: (item.Rango1Value || 0).toFixed(2),
                Rango2Value: (item.Rango2Value || 0).toFixed(2),
                Rango3Value: (item.Rango3Value || 0).toFixed(2),
                Rango4Value: (item.Rango4Value || 0).toFixed(2),
                Rango5Value: (item.Rango5Value || 0).toFixed(2),
                SaldoActual: (item.SaldoActual || 0).toFixed(2),
                SaldoPorVencer: (item.SaldoPorVencer || 0).toFixed(2),
                SaldoVencido: (item.SaldoVencido || 0).toFixed(2),
                SaldoFavor: (item.SaldoFavor || 0).toFixed(2)
            };
        });
    
        // Format totals to 2 decimal places as well
        Object.keys(this.dataTotals).forEach(key => {
            this.dataTotals[key] = this.dataTotals[key].toFixed(2);
        });
    
        this.addTotalsRow()
        comprobantesDisplayTableModal.open({recordsdata:this.dataFormatted})
    }

    addTotalsRow(){
        this.dataFormatted.push({
            Segmento: "Totales",
            Grupo: "",
            ClienteNombre: "",
            PlazoPago: 0,
            Documento: "",
            Fecha: "",
            FechaVencimiento: "",
            SaldoActual: this.dataTotals.SaldoActual,
            SaldoPorVencer: this.dataTotals.SaldoPorVencer,
            SaldoVencido: this.dataTotals.SaldoVencido,
            SaldoFavor: this.dataTotals.SaldoFavor,
            Rango1Display: "",
            Rango1Value: this.dataTotals.Rango1Value,
            Rango2Display: "",
            Rango2Value: this.dataTotals.Rango2Value,
            Rango3Display: "",
            Rango3Value: this.dataTotals.Rango3Value,
            Rango4Display: "",
            Rango4Value: this.dataTotals.Rango4Value,
            Rango5Display: "",
            Rango5Value: this.dataTotals.Rango5Value
        })
    }

    openTableInModal(){
        comprobantesDisplayTableModal.open({recordsdata:this.dataFormatted})
    }

    formatDateCorrectly(isoString) {
        const date = new Date(isoString);
        const year = date.getUTCFullYear();
        const month = date.getUTCMonth() + 1;
        const day = date.getUTCDate();
        return `${month}/${day}/${year}`;
    }
}

/* 
"SaldoActual": 35654.99,
"SaldoPorVencer": 35654.99,
"SaldoVencido": 0,
"SaldoFavor": 0,
"Rango1Display": "1 - 30",
"Rango1Value": 0,
"Rango2Display": "31 - 60",
"Rango2Value": 0,
"Rango3Display": "61 - 90",
"Rango3Value": 0,
"Rango4Display": "91 - 120",
"Rango4Value": 0,
"Rango5Display": "Más de 120",
"Rango5Value": 0
*/