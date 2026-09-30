public with sharing class CreditoClienteController {

    @AuraEnabled(cacheable=false)
    public static CreditoInfo getCreditoDisponible(Id accountId) {
        CreditoInfo info = new CreditoInfo();

        Account acc = [SELECT Id, LimitedeCredito__c, ZF_Cliente_ID__c FROM Account WHERE Id = :accountId LIMIT 1];
        info.limiteCredito = acc.LimitedeCredito__c;

        if (acc.ZF_Cliente_ID__c == null) {
            info.errorMessage = 'Sin Id de cliente en Zafiro';
            return info;
        }

        try {
            List<Object> saldos = ObtenerAntiguedadSaldos.obtenerAntiguedadSaldo(accountId);
            Decimal totalSaldoActual = 0;
            for (Object row : saldos) {
                Map<String, Object> saldoRow = (Map<String, Object>) row;
                Object saldoActualValue = saldoRow.get('SaldoActual');
                if (saldoActualValue != null) {
                    totalSaldoActual += Decimal.valueOf(String.valueOf(saldoActualValue));
                }
            }
            info.saldoActual = totalSaldoActual;
            if (info.limiteCredito != null) {
                info.creditoDisponible = info.limiteCredito - totalSaldoActual;
            }
        } catch (Exception e) {
            info.errorMessage = 'No disponible';
        }

        return info;
    }

    public class CreditoInfo {
        @AuraEnabled public Decimal limiteCredito { get; set; }
        @AuraEnabled public Decimal saldoActual { get; set; }
        @AuraEnabled public Decimal creditoDisponible { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }
}