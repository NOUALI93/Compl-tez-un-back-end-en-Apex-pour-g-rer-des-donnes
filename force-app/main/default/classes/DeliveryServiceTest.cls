@IsTest
public class DeliveryServiceTest {

    /* =========================
       SETUP DATA
       ========================= */

    private static Account createAccount(String clientType, String country) {
        Account acc = new Account(
            Name = 'Acc ' + clientType,
            Client_Type__c = clientType,
            ShippingCountry = country
        );
        insert acc;
        return acc;
    }

    private static Account createAccountNoType(String country) {
        Account acc = new Account(
            Name = 'Acc NoType',
            ShippingCountry = country
        );
        insert acc;
        return acc;
    }

    private static Product2 createProduct(String name) {
        Product2 p = new Product2(Name = name, IsActive = true);
        insert p;
        return p;
    }

    private static PricebookEntry createPbe(Id productId, Decimal price) {
        Id pbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId,
            Product2Id = productId,
            UnitPrice = price,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;
        return pbe;
    }

    private static Order createOrder(Id accountId, String status, String shipCountry) {
        Id pbId = Test.getStandardPricebookId();

        Order o = new Order(
            AccountId = accountId,
            Status = status,
            EffectiveDate = Date.today(),
            Pricebook2Id = pbId,
            ShippingCountry = shipCountry
        );
        insert o;
        return o;
    }

    private static void addOrderItem(Id orderId, Id pbeId, Integer qty, Decimal unitPrice) {
        OrderItem oi = new OrderItem(
            OrderId = orderId,
            Quantity = qty,
            UnitPrice = unitPrice,
            PricebookEntryId = pbeId
        );
        insert oi;
    }

    private static Transporteur__c createTransporteur(String name, String typeClient) {
        Transporteur__c t = new Transporteur__c(
            Name = name,
            Type_Client__c = typeClient
        );
        insert t;
        return t;
    }

    private static Tarif_Livraison__c createTarif(Id transporteurId, String pays, Decimal tarif, Integer delai) {
        Tarif_Livraison__c tl = new Tarif_Livraison__c(
            Transporteur__c = transporteurId,
            Pays__c = pays,
            Tarif__c = tarif,
            Delai__c = delai
        );
        insert tl;
        return tl;
    }

    /* =========================
       TEST: getDeliveryOptions (cheapest/fastest + options list)
       ========================= */
    @IsTest
    static void testGetDeliveryOptions_ReturnsCheapestAndFastest() {
        // Transporteurs compatibles Particulier
        Transporteur__c tCheap = createTransporteur('CheapShip', 'Particulier');
        Transporteur__c tFast  = createTransporteur('FastShip',  'Particulier');

        // Tarifs France : cheap (tarif 10, delai 5), fast (tarif 25, delai 1)
        createTarif(tCheap.Id, 'France', 10, 5);
        createTarif(tFast.Id,  'France', 25, 1);

        Account acc = createAccount('Particulier', 'France');
        Order o = createOrder(acc.Id, 'Draft', 'France');

        Test.startTest();
        DeliveryService.DeliveryOptionsResponse resp = DeliveryService.getDeliveryOptions(o.Id);
        Test.stopTest();

        System.assertNotEquals(null, resp, 'Response doit exister');
        System.assertEquals('France', resp.pays);
        System.assertEquals('Particulier', resp.clientType);

        System.assertEquals(tCheap.Id, resp.cheapest.transporteurId, 'Cheapest doit être CheapShip');
        System.assertEquals(tFast.Id, resp.fastest.transporteurId, 'Fastest doit être FastShip');

        System.assert(resp.options.size() >= 2, 'Options doit contenir au moins 2 transporteurs');
    }

    /* =========================
       TEST: getDeliveryOptions (aucun tarif)
       ========================= */
   @IsTest
    static void testGetDeliveryOptions_FailsWhenNoTarif() {
        Account acc = createAccount('Particulier', 'France');
        Order o = createOrder(acc.Id, 'Draft', 'France');

        Boolean thrown = false;

        Test.startTest();
        try {
            DeliveryService.getDeliveryOptions(o.Id);
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Une exception doit être levée si aucun tarif compatible.');
    }



    /* =========================
       TEST: getDeliveryOptions (type client manquant)
       ========================= */
    @IsTest
    static void testGetDeliveryOptions_FailsWhenClientTypeMissing() {
        Account acc = createAccountNoType('France');
        Order o = createOrder(acc.Id, 'Draft', 'France');

        Boolean thrown = false;

        Test.startTest();
        try {
            DeliveryService.getDeliveryOptions(o.Id);
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Une exception doit être levée si le type client est manquant.');
    }


    /* =========================
       TEST: launchDelivery SUCCESS (manual transporteur choisi)
       ========================= */
    @IsTest
    static void testLaunchDeliverySuccess_ManualTransporteur() {
        // Transporteurs compatibles Particulier
        Transporteur__c tCheap = createTransporteur('CheapShip', 'Particulier');
        Transporteur__c tFast  = createTransporteur('FastShip',  'Particulier');

        createTarif(tCheap.Id, 'France', 10, 5);
        createTarif(tFast.Id,  'France', 25, 1);

        Account acc = createAccount('Particulier', 'France');

        // Order Draft
        Order o = createOrder(acc.Id, 'Draft', 'France');

        // Ajouter produits (total qty >= 3) puis activer
        Product2 p = createProduct('P1');
        PricebookEntry pbe = createPbe(p.Id, 10);
        addOrderItem(o.Id, pbe.Id, 3, 10);

        // Important : activer
        o.Status = 'Activated';
        update o;

        Test.startTest();
        Id livraisonId = DeliveryService.launchDelivery(o.Id, tFast.Id); // choix manuel = FastShip
        Test.stopTest();

        System.assertNotEquals(null, livraisonId, 'LivraisonId doit être retourné');

        Livraison__c liv = [
            SELECT Id, Order__c, Transporteur__c, Prix_Livraison__c, Statut__c
            FROM Livraison__c
            WHERE Id = :livraisonId
            LIMIT 1
        ];

        System.assertEquals(o.Id, liv.Order__c);
        System.assertEquals(tFast.Id, liv.Transporteur__c, 'Le transporteur doit être celui choisi manuellement');
        System.assertEquals(25, liv.Prix_Livraison__c);
        System.assertEquals('En cours', liv.Statut__c);
    }

    /* =========================
       TEST: launchDelivery FAIL (order not Activated)
       ========================= */
    @IsTest
    static void testLaunchDeliveryFailsWhenNotActivated() {
        Transporteur__c t = createTransporteur('Ship', 'Particulier');
        createTarif(t.Id, 'France', 10, 2);

        Account acc = createAccount('Particulier', 'France');
        Order o = createOrder(acc.Id, 'Draft', 'France');

        Boolean thrown = false;

        Test.startTest();
        try {
            DeliveryService.launchDelivery(o.Id, t.Id);
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Une exception doit être levée si la commande n’est pas activée.');
    }


    /* =========================
       TEST: launchDelivery FAIL (transporteur non compatible)
       ========================= */
    @IsTest
    static void testLaunchDeliveryFailsWhenTransporteurNotCompatible() {
        Transporteur__c tPro = createTransporteur('ProOnly', 'Professionnel');
        createTarif(tPro.Id, 'France', 30, 2);

        Account acc = createAccount('Particulier', 'France');
        Order o = createOrder(acc.Id, 'Draft', 'France');

        Product2 p = createProduct('P1');
        PricebookEntry pbe = createPbe(p.Id, 10);
        addOrderItem(o.Id, pbe.Id, 3, 10);

        o.Status = 'Activated';
        update o;

        Boolean thrown = false;

        Test.startTest();
        try {
            DeliveryService.launchDelivery(o.Id, tPro.Id);
        } catch (Exception e) {
            thrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, thrown, 'Une exception doit être levée si le transporteur n’est pas compatible.');
    }

}
