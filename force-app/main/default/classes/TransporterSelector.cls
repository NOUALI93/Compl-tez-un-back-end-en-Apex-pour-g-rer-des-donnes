public with sharing class TransporterSelector {

    public static List<Tarif_Livraison__c> getTarifsByPaysAndType(String pays, String typeClient) {
        return [
            SELECT Id, Pays__c, Tarif__c, Delai__c,
                   Transporteur__c, Transporteur__r.Name, Transporteur__r.Type_Client__c
            FROM Tarif_Livraison__c
            WHERE Pays__c = :pays
              AND Transporteur__r.Type_Client__c = :typeClient
        ];
    }
}


