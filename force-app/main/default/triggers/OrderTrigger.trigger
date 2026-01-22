trigger OrderTrigger on Order (before update)
 {

    for (Order o : Trigger.new) {

        // Validation métier
        if (Trigger.oldMap.get(o.Id).Status != 'Activated' && o.Status == 'Activated') {
            OrderService.validateOrder(o);
        }
    }
}
