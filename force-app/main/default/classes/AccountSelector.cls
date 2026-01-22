//Exemple de selector
public with sharing class AccountSelector {
    public static Account getAccountById(Id accountId) {
        return [
                SELECT Id, Name, Client_Type__c, ShippingCountry
                FROM Account
                WHERE Id = :accountId
        ];
    }
}