@IsTest
public class DeliveryPermissionServiceTest {

    @IsTest
    static void testCanSendDelivery_ReturnsTrueWhenPermissionAssigned() {

        // 1) Récupérer la Custom Permission existante
        CustomPermission cp = [
            SELECT Id, DeveloperName
            FROM CustomPermission
            WHERE DeveloperName = 'Send_Order_Delivery'
            LIMIT 1
        ];

        // 2) Créer un user de test
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Alias = 'tuser',
            Email = 'tuser' + DateTime.now().getTime() + '@test.com',
            Username = 'tuser' + DateTime.now().getTime() + '@test.com',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'fr',
            ProfileId = p.Id
        );
        insert u;

        // 3) Créer un Permission Set
        PermissionSet ps = new PermissionSet(
            Name = 'PS_Test_OrderDelivery_' + String.valueOf(DateTime.now().getTime()),
            Label = 'PS Test Order Delivery'
        );
        insert ps;

        // 4) Lier PermissionSet <-> CustomPermission via SetupEntityAccess
        SetupEntityAccess sea = new SetupEntityAccess(
            ParentId = ps.Id,
            SetupEntityId = cp.Id
        );
        insert sea;

        // 5) Assigner le Permission Set au user
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = ps.Id
        );
        insert psa;

        // 6) Vérifier la méthode côté user
        System.runAs(u) {
            Test.startTest();
            Boolean ok = DeliveryPermissionService.canSendDelivery();
            Test.stopTest();

            System.assertEquals(true, ok, 'Le user doit avoir l’autorisation via Permission Set + Custom Permission.');
        }
    }

    @IsTest
    static void testCanSendDelivery_ReturnsFalseWhenNoPermission() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            FirstName = 'NoPerm',
            LastName = 'User',
            Alias = 'nperm',
            Email = 'nperm' + DateTime.now().getTime() + '@test.com',
            Username = 'nperm' + DateTime.now().getTime() + '@test.com',
            TimeZoneSidKey = 'Europe/Paris',
            LocaleSidKey = 'fr_FR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'fr',
            ProfileId = p.Id
        );
        insert u;

        System.runAs(u) {
            Test.startTest();
            Boolean ok = DeliveryPermissionService.canSendDelivery();
            Test.stopTest();

            System.assertEquals(false, ok, 'Sans Permission Set, le user ne doit pas avoir l’autorisation.');
        }
    }
}

