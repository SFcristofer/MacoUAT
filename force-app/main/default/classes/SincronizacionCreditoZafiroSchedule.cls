public class SincronizacionCreditoZafiroSchedule implements Schedulable {
    public void execute(SchedulableContext SC) {
        // Ejecutamos el batch con un tamano de lote de 50 para no rebasar los limites de callouts
        Database.executeBatch(new SincronizacionCreditoZafiroBatch(), 50);
    }
}
