public with sharing class DeliveryService {

    // DTO
    public class DeliveryOptionDTO {
        @AuraEnabled public Id transporteurId;
        @AuraEnabled public String transporteurName;
        @AuraEnabled public Decimal tarif;
        @AuraEnabled public Integer delai;
        @AuraEnabled public String pays;
    }

    public class DeliveryOptionsResponse {
        @AuraEnabled public DeliveryOptionDTO cheapest;
        @AuraEnabled public DeliveryOptionDTO fastest;
        @AuraEnabled public List<DeliveryOptionDTO> options;
        @AuraEnabled public String pays;
        @AuraEnabled public String clientType;
    }

    // GET OPTIONS (LWC)
    @AuraEnabled(cacheable=true)
    public static DeliveryOptionsResponse getDeliveryOptions(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('OrderId manquant.');
        }

        Order o = [
            SELECT Id, AccountId, Status,
                   Account.ShippingCountry, Account.Client_Type__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (o.Account == null || String.isBlank(o.Account.ShippingCountry)) {
            throw new AuraHandledException('Le pays de livraison est manquant (Shipping Country).');
        }
        if (String.isBlank(o.Account.Client_Type__c)) {
            throw new AuraHandledException('Le type de client est manquant sur le compte (Client_Type__c).');
        }

        List<Tarif_Livraison__c> tarifs =
            TransporterSelector.getTarifsByPaysAndType(
                o.Account.ShippingCountry,
                o.Account.Client_Type__c
            );

        if (tarifs.isEmpty()) {
            throw new AuraHandledException('Aucun transporteur compatible pour ce pays et ce type de client.');
        }

        DeliveryOptionsResponse resp = new DeliveryOptionsResponse();
        resp.options = new List<DeliveryOptionDTO>();
        resp.pays = o.Account.ShippingCountry;
        resp.clientType = o.Account.Client_Type__c;

        Tarif_Livraison__c cheapest = tarifs[0];
        Tarif_Livraison__c fastest  = tarifs[0];

        for (Tarif_Livraison__c t : tarifs) {
            // cheapest : min tarif
            if (t.Tarif__c < cheapest.Tarif__c) {
                cheapest = t;
            }

            // fastest : min délai
            Integer d  = (t.Delai__c == null) ? 999999 : Integer.valueOf(t.Delai__c);
            Integer fd = (fastest.Delai__c == null) ? 999999 : Integer.valueOf(fastest.Delai__c);
            if (d < fd) {
                fastest = t;
            }

            DeliveryOptionDTO dto = new DeliveryOptionDTO();
            dto.transporteurId = t.Transporteur__c;
            dto.transporteurName = t.Transporteur__r.Name;
            dto.tarif = t.Tarif__c;
            dto.delai = (t.Delai__c == null) ? null : Integer.valueOf(t.Delai__c);
            dto.pays = t.Pays__c;
            resp.options.add(dto);
        }

        resp.cheapest = toDto(cheapest);
        resp.fastest  = toDto(fastest);
        return resp;
    }

    private static DeliveryOptionDTO toDto(Tarif_Livraison__c t) {
        DeliveryOptionDTO dto = new DeliveryOptionDTO();
        dto.transporteurId = t.Transporteur__c;
        dto.transporteurName = t.Transporteur__r.Name;
        dto.tarif = t.Tarif__c;
        dto.delai = (t.Delai__c == null) ? null : Integer.valueOf(t.Delai__c);
        dto.pays = t.Pays__c;
        return dto;
    }

    // UNE SEULE méthode AuraEnabled, transporteurId optionnel (nullable)
    @AuraEnabled
    public static Id launchDelivery(Id orderId, Id transporteurId) {

        if (orderId == null) {
            throw new AuraHandledException('OrderId manquant.');
        }

        Order o = [
            SELECT Id, Status, Transporteur__c,
                   Account.ShippingCountry, Account.Client_Type__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (o.Status != 'Activated') {
            throw new AuraHandledException('La commande doit être activée avant de lancer la livraison.');
        }

        if (o.Account == null || String.isBlank(o.Account.ShippingCountry)) {
            throw new AuraHandledException('Le pays de livraison est manquant (Shipping Country).');
        }
        if (String.isBlank(o.Account.Client_Type__c)) {
            throw new AuraHandledException('Le type de client est manquant sur le compte (Client_Type__c).');
        }

        // transporteur choisi par user sinon celui de la commande
        Id chosenTransporteurId = (transporteurId != null) ? transporteurId : o.Transporteur__c;

        if (chosenTransporteurId == null) {
            throw new AuraHandledException('Aucun transporteur défini ou sélectionné.');
        }

        // récupérer le tarif exact pour (transporteur+pays)
        List<Tarif_Livraison__c> tarifs = [
            SELECT Tarif__c, Delai__c, Transporteur__c
            FROM Tarif_Livraison__c
            WHERE Transporteur__c = :chosenTransporteurId
              AND Pays__c = :o.Account.ShippingCountry
            LIMIT 1
        ];

        if (tarifs.isEmpty()) {
            throw new AuraHandledException('Aucun tarif trouvé pour ce transporteur et ce pays.');
        }

        Tarif_Livraison__c tarif = tarifs[0];

        Livraison__c liv = new Livraison__c(
            Order__c = o.Id,
            Transporteur__c = chosenTransporteurId,
            Prix_Livraison__c = tarif.Tarif__c,
            Date_Livraison_Estimee__c = Date.today().addDays(Integer.valueOf(tarif.Delai__c)),
            Statut__c = 'En cours'
        );

        insert liv;
        return liv.Id;
    }
}
