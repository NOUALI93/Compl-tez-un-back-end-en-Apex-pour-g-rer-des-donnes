@IsTest
public class TransporterSelectorTest {

    @TestSetup
    static void setupData() {
        // Transporteur Particulier
        Transporteur__c tPart = new Transporteur__c(
            Name = 'Chronopost',
            Type_Client__c = 'Particulier'
        );
        insert tPart;

        // Transporteur Professionnel
        Transporteur__c tPro = new Transporteur__c(
            Name = 'DHL',
            Type_Client__c = 'Professionnel'
        );
        insert tPro;

        // Tarif Particulier France
        insert new Tarif_Livraison__c(
            Transporteur__c = tPart.Id,
            Pays__c = 'France',
            Tarif__c = 20,
            Delai__c = 2
        );

        // Tarif Pro France
        insert new Tarif_Livraison__c(
            Transporteur__c = tPro.Id,
            Pays__c = 'France',
            Tarif__c = 30,
            Delai__c = 1
        );
    }

    @IsTest
    static void testGetTarifsByPaysAndType_Particulier_France() {
        Test.startTest();
        List<Tarif_Livraison__c> res =
            TransporterSelector.getTarifsByPaysAndType('France', 'Particulier');
        Test.stopTest();

        System.assertEquals(1, res.size(), 'On attend 1 tarif Particulier pour France');
        System.assertEquals('France', res[0].Pays__c);
        System.assertNotEquals(null, res[0].Transporteur__c);
    }

    @IsTest
    static void testGetTarifsByPaysAndType_NoResult() {
        Test.startTest();
        List<Tarif_Livraison__c> res =
            TransporterSelector.getTarifsByPaysAndType('Suisse', 'Particulier');
        Test.stopTest();

        System.assertEquals(0, res.size(), 'Aucun tarif attendu');
    }
}
