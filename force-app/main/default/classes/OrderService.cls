public with sharing class OrderService {

     // Validation du nombre minimum de produits
    public static void validateOrder(Order orderToValidate) {

        Account acc = AccountSelector.getAccountById(orderToValidate.AccountId);

        // type client obligatoire
        if (String.isBlank(acc.Client_Type__c)) {
            orderToValidate.addError(
                'Le type de client est manquant sur le compte (Client_Type__c).'
            );
            return;
        }

        Integer totalQty = 0;

        for (OrderItem oi : [
            SELECT Quantity
            FROM OrderItem
            WHERE OrderId = :orderToValidate.Id
        ]) {
            totalQty += Integer.valueOf(oi.Quantity);
        }

        if (acc.Client_Type__c == 'Particulier' && totalQty < 3) {
            orderToValidate.addError(
                'Un client particulier doit commander au moins 3 produits.'
            );
        } else if (acc.Client_Type__c == 'Professionnel' && totalQty < 5) {
            orderToValidate.addError(
                'Un client professionnel doit commander au moins 5 produits.'
            );
        }
    }
}
