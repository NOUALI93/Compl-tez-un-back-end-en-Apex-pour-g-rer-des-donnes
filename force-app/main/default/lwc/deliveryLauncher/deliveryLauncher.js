import { LightningElement, wire, api } from 'lwc';
import canSendDelivery from '@salesforce/apex/DeliveryPermissionService.canSendDelivery';
import getDeliveryOptions from '@salesforce/apex/DeliveryService.getDeliveryOptions';
import launchDelivery from '@salesforce/apex/DeliveryService.launchDelivery';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DeliveryLauncher extends LightningElement {
  @api recordId;

  hasPermission = false;
  optionsResp;
  errorMsg;

  selectedMode = 'cheapest'; 
  selectedTransporteurId;

  @wire(canSendDelivery)
  wiredPerm({ data, error }) {
    if (data !== undefined) this.hasPermission = data === true;
    if (error) this.hasPermission = false;
  }

  @wire(getDeliveryOptions, { orderId: '$recordId' })
  wiredOptions({ data, error }) {
    if (data) {
      this.optionsResp = data;
      this.errorMsg = null;
    } else if (error) {
      this.optionsResp = null;
      this.errorMsg = error?.body?.message || 'Impossible de charger les options de livraison.';
    }
  }

  get hasOptions() {
    return this.optionsResp?.options?.length > 0;
  }

  get modeOptions() {
    return [
      { label: 'Moins chère', value: 'cheapest' },
      { label: 'Plus rapide', value: 'fastest' },
      { label: 'Choisir un transporteur', value: 'manual' }
    ];
  }

  get isManual() {
    return this.selectedMode === 'manual';
  }

  get transporteurPicklist() {
    if (!this.hasOptions) return [];
    return this.optionsResp.options.map(o => ({
      label: `${o.transporteurName} — ${o.tarif}€ — ${o.delai}j`,
      value: o.transporteurId
    }));
  }

  handleModeChange(event) {
    this.selectedMode = event.detail.value;
  }

  handleTransporteurChange(event) {
    this.selectedTransporteurId = event.detail.value;
  }

  async handleLaunch() {

    try {
      let chosenId;

      if (this.selectedMode === 'manual') {
        chosenId = this.selectedTransporteurId;
        if (!chosenId) throw new Error('Veuillez sélectionner un transporteur.');
      } else if (this.selectedMode === 'fastest') {
        chosenId = this.optionsResp.fastest.transporteurId;
      } else {
        chosenId = this.optionsResp.cheapest.transporteurId;
      }

      const livraisonId = await launchDelivery({
        orderId: this.recordId,
        transporteurId: chosenId
      });

      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Succès',
          message: `Livraison créée : ${livraisonId}`,
          variant: 'success'
        })
      );


    } catch (e) {
      const msg = e?.body?.message || e?.message || 'Erreur lors du lancement de la livraison.';
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Erreur',
          message: msg,
          variant: 'error'
        })
      );
    } 
  }
}
