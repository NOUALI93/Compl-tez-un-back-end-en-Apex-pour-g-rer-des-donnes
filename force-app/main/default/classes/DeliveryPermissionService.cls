public with sharing class DeliveryPermissionService {

    @AuraEnabled(cacheable=true)
    public static Boolean canSendDelivery() {
        return FeatureManagement.checkPermission('Send_Order_Delivery');
    }
}
