package pro.controller;
import Common;
import form.CagetteForm;
import sugoi.form.Form;
import sugoi.form.ListData.FormData;
import sugoi.form.elements.FloatInput;
import sugoi.form.elements.FloatSelect;
import sugoi.form.elements.IntSelect;

using Std;

class Offer extends controller.Controller
{

	var company : pro.db.CagettePro;
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.category = "product";
		
	}
	
	/**
	 * Edit an offer
	 */
	@tpl('plugin/pro/offerform.mtt')
	function doEdit(o:pro.db.POffer) {
		
		var f = CagetteForm.fromSpod(o);
		
		//units
		f.removeElementByName('quantity');
		var uname = o.product.unitType==null ? "Quantité" : switch(o.product.unitType){
			case Kilogram,Gram: "Poids";
			case Litre: "Volume";
			default : "Quantité";
		}
		f.addElement( new form.UnitQuantity("quantity", uname, o.quantity, true, o.product.unitType) );

		f.removeElementByName('smallQt');
		if(o.product.bulk){
			f.addElement( new form.UnitQuantity("smallQt", uname+" (petite quantité pour le vrac)", o.smallQt==null ? 0.1 : o.smallQt, true, o.product.unitType) );
		}
		
		//for the VATBox component
		view.rates = Lambda.map(company.getVatRates(),function(v) return v.value).join("|");
		view.price = o.price;
		view.vat = o.vat;
		
		//add catalogs to update
		f.addElement(new sugoi.form.elements.Html("html","<hr/>"));
		var coffers = pro.db.PCatalogOffer.manager.search($offerId == o.id, true);
		var data = [for (co in coffers) {label:co.catalog.name, value:Std.string(co.catalog.id)}];
		var checked = [];
		for (co in coffers){
			//checked if price is identical
			if ( co.price == o.price ) checked.push(Std.string(co.catalog.id)); 
		}
		var el = new sugoi.form.elements.CheckboxGroup("catalogs", "Mettre à jour le prix dans les catalogues", data, checked);
		f.addElement(el);		

		if (f.isValid()) {			
			
			f.toSpod(o); 

			if(o.product.bulk){
				if(o.smallQt==null) throw Error(sugoi.Web.getURI(),"Vous devez définir le champs 'petite quantité' si l'option 'vrac' est activée");
				if(o.product.unitType==null) throw Error(sugoi.Web.getURI(),"Vous devez définir l'unité de votre produit si l'option 'vrac' est activée");
				if(o.quantity==null) throw Error(sugoi.Web.getURI(),"Vous devez définir une quantité/poids/volume si l'option 'vrac' est activée");
				if(o.smallQt>=1 || o.smallQt<=0) throw Error(sugoi.Web.getURI(),"La petite quantité doit être supérieure à zéro et inférieure à 1");
			}			
			
			//ref uniqueness
			if ( pro.db.POffer.refExists(company, o.ref, o) ){
				throw Error("/p/pro/product", "Cette référence existe dejà dans votre catalogue");
			}
			
			var catalogsToUpdate : Array<Int> = f.getValueOf("catalogs");

			//if offers are in catalogs, update the lastUpdate field of the catalog (for synch purpose)			
			for( coffer in coffers){
				
				//update price directly in catalog
				if( Lambda.exists(catalogsToUpdate,function(x) {return Std.string(x)==Std.string(coffer.catalog.id);}  ) ){					
					coffer.price = o.price;
					coffer.update();
				}

				//need sync
				coffer.catalog.toSync();
			}

			o.update();
			throw Ok('/p/pro/product#product'+o.product.id,'L\'offre a été mise à jour');
		}
		
		view.form = f;
		view.title = 'Modifier l\'offre "${o.product.name}"';
	}
		
	/**
	 * Create a new offer
	 */
	@tpl("plugin/pro/offerform.mtt")
	public function doInsert(p:pro.db.PProduct) {
		
		var o = new pro.db.POffer();
		o.product = p;
		o.ref = p.ref + "-" + (pro.db.POffer.manager.count($product==p)+1);
		var f = CagetteForm.fromSpod(o);		
		
		//units
		f.removeElementByName('quantity');
		var uname = switch(p.unitType){
			case Kilogram,Gram: "Poids";
			case Litre: "Volume";
			default : "Quantité";
		}
		f.addElement( new form.UnitQuantity("quantity", uname, 1, true, p.unitType) );	
		
		
		f.removeElementByName('smallQt');
		if(o.product.bulk){
			f.addElement( new form.UnitQuantity("smallQt", uname+" (petite quantité pour le vrac)", o.smallQt==null ? 0.1 : o.smallQt, true, o.product.unitType) );
		}
		
		//for the VATBox component
		view.rates = Lambda.map(company.getVatRates(),function(v) return v.value).join("|");
		view.price = 0;
		view.vat = company.getVatRates()[0].value;

		if (f.isValid()) {
			f.toSpod(o);
			o.product = p;		

			if(o.product.bulk){
				if(o.smallQt==null) throw Error(sugoi.Web.getURI(),"Vous devez définir le champs 'petite quantité' si l'option 'vrac' est activée");
				if(o.product.unitType==null) throw Error(sugoi.Web.getURI(),"Vous devez définir l'unité de votre produit si l'option 'vrac' est activée");
				if(o.quantity==null) throw Error(sugoi.Web.getURI(),"Vous devez définir une quantité/poids/volume si l'option 'vrac' est activée");
				if(o.smallQt>=1 || o.smallQt<=0) throw Error(sugoi.Web.getURI(),"La petite quantité doit être supérieure à zéro et inférieure à 1");
			}
			
			if ( pro.db.POffer.refExists(company, o.ref) ){
				throw Error("/p/pro/product", "Cette référence existe dejà dans votre catalogue");
			}
			
			o.insert();
			throw Ok('/p/pro/product#product'+p.id,'L\'offre a été enregistrée');
		}
		
		view.form = f;
		view.title = "Enregistrer une nouvelle offre";
	}
	
	/**
	 * Delete an offer
	 * @param	o
	 */
	public function doDelete(o:pro.db.POffer) {
		
		var catalogOffers = o.getCatalogOffers();
		
		if (catalogOffers.length > 0){
			throw Error("/p/pro/product", "Cette offre est référencée dans le catalogue "+Lambda.map(catalogOffers,function(co) return "\""+co.catalog.name+"\"").join(", ")+". <br/>Plutôt que d'effacer complètement et définitivement le produit, il est recommandé de simplement retirer ce produit du catalogue.");
		}else{
			o.lock();
			o.delete();
			throw Ok("/p/pro/product","Offre supprimée");
		}
	}
	
	@tpl('shop/productInfo.mtt')
	public function doPreview(o:pro.db.POffer) {
		view.p = o.getInfos();
		view.vendor = company.vendor;
	}
	
	
}