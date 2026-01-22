@IsTest
public class OrderServiceTest {

    /* =========================
       UTILS
       ========================= */

    private static Account createAccount(String typeClient) {
        Account acc = new Account(
            Name = 'Test Account ' + typeClient,
            Client_Type__c = typeClient,
            ShippingCountry = 'France'
        );
        insert acc;
        return acc;
    }

    private static Order createOrder(Id accountId) {
        Id standardPricebookId = Test.getStandardPricebookId();

        Order o = new Order(
            AccountId = accountId,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = standardPricebookId,
            ShippingCountry = 'France' // nécessaire pour selectBestTransporter
        );
        insert o;
        return o;
    }

    private static Product2 createProduct(String name) {
        Product2 p = new Product2(Name = name, IsActive = true);
        insert p;
        return p;
    }

    private static PricebookEntry createPricebookEntry(Id productId) {
        Id pbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pbId,
            Product2Id = productId,
            UnitPrice = 10,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;
        return pbe;
    }

    private static void addOrderItem(Id orderId, Id pbeId, Integer qty) {
        insert new OrderItem(
            OrderId = orderId,
            Quantity = qty,
            UnitPrice = 10,
            PricebookEntryId = pbeId
        );
    }

    private static Transporteur__c createTransporteur(String name, String typeClient) {
        Transporteur__c t = new Transporteur__c(
            Name = name,
            Type_Client__c = typeClient
        );
        insert t;
        return t;
    }

    private static void createTarif(Id transporteurId, Decimal tarif) {
        insert new Tarif_Livraison__c(
            Transporteur__c = transporteurId,
            Pays__c = 'France',
            Tarif__c = tarif,
            Delai__c = 2
        );
    }

    /* =========================
       TESTS
       ========================= */

   @IsTest
    static void testParticulierBelowMinimum_BlockedOnActivate() {
        Account acc = createAccount('Particulier');
        Order o = createOrder(acc.Id);

        Product2 p = createProduct('P1');
        PricebookEntry pbe = createPricebookEntry(p.Id);

        addOrderItem(o.Id, pbe.Id, 1); // < 3

        Boolean exceptionThrown = false;

        // ✅ déclenche la validation : changement Draft -> Activated
        o.Status = 'Activated';

        Test.startTest();
        try {
            update o;
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('au moins 3 produits'),
                'Message attendu Particulier. Reçu: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Doit bloquer un Particulier < 3 produits lors de l’activation');
    }



    @IsTest
    static void testProfessionnelBelowMinimum_BlockedOnActivate() {
        Account acc = createAccount('Professionnel');
        Order o = createOrder(acc.Id);

        Product2 p = createProduct('P1');
        PricebookEntry pbe = createPricebookEntry(p.Id);

        addOrderItem(o.Id, pbe.Id, 4); // < 5

        Boolean exceptionThrown = false;

        // ✅ déclenche la validation : Draft -> Activated
        o.Status = 'Activated';

        Test.startTest();
        try {
            update o;
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().contains('au moins 5 produits'),
                'Message attendu Professionnel. Reçu: ' + e.getMessage()
            );
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'Doit bloquer un Professionnel < 5 produits lors de l’activation');
    }



    @IsTest
    static void testValidOrderAssignCheapestTransporteur() {
        // 2 transporteurs Particulier
        Transporteur__c t1 = createTransporteur('T1', 'Particulier');
        Transporteur__c t2 = createTransporteur('T2', 'Particulier');

        // t2 moins cher
        createTarif(t1.Id, 30);
        createTarif(t2.Id, 10);

        Account acc = createAccount('Particulier');
        Order o = createOrder(acc.Id);

        Product2 p = createProduct('P1');
        PricebookEntry pbe = createPricebookEntry(p.Id);

        addOrderItem(o.Id, pbe.Id, 3); // >= 3

        Test.startTest();
        update o; // déclenche selectBestTransporter
        Test.stopTest();

        Order result = [
            SELECT Transporteur__c
            FROM Order
            WHERE Id = :o.Id
        ];

        System.assertEquals(t2.Id, result.Transporteur__c, 'Doit choisir le transporteur le moins cher');
    }

    @IsTest
    static void testNoTarif_NoTransporteurAssigned() {
        Account acc = createAccount('Particulier');
        Order o = createOrder(acc.Id);

        Product2 p = createProduct('P1');
        PricebookEntry pbe = createPricebookEntry(p.Id);

        addOrderItem(o.Id, pbe.Id, 3); // commande valide

        Test.startTest();
        update o; // tarifs.isEmpty() => return
        Test.stopTest();

        Order result = [
            SELECT Transporteur__c
            FROM Order
            WHERE Id = :o.Id
        ];

        System.assertEquals(null, result.Transporteur__c, 'Sans tarif, pas de transporteur assigné');
    }
}
