package pro.controller;
import Common;
import db.UserGroup;
import form.CagetteForm;
import pro.db.PNotif;
import sugoi.form.Form;
import sugoi.form.elements.IntSelect;

using Std;

class Catalog extends controller.Controller
{

	var company : pro.db.CagettePro;
	
	private function checkRights(catalog:pro.db.PCatalog){
		if (catalog.company.id != this.company.id){
			throw "Erreur, accès interdit à ce catalogue";
		}
	}
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.category = "catalog";
		view.nav = ["catalog"];
	}
	
	
	@logged @tpl("plugin/pro/catalog/default.mtt")
	public function doDefault() {
		
		view.nav.push("default");

		view.catalogs = company.getCatalogs();
		view.getLinkages = function(catalog:pro.db.PCatalog){
			return connector.db.RemoteCatalog.getFromCatalog(catalog);				
		}
		checkToken();
	}
	
	/**
	 * choose which offers to include in the catalog
	 * @param	c
	 */
	@tpl('plugin/pro/catalog/products.mtt')
	function doProducts(catalog:pro.db.PCatalog){
		checkRights(catalog);
		view.nav.push("products");
		var AllOffers = company.getOffers(); 
		var selectedOffers = [];		
		var catalogOffers = catalog.getOffers();
		
		for ( o in  AllOffers){			
			var checked : Bool  = Lambda.find(catalogOffers, function(cp) return cp.offer.id == o.id) != null;		
			selectedOffers.push({offer:o,checked:checked});
		}		
		
		view.catalog = catalog;
		view.products = selectedOffers;
		
		if (checkToken()){
			
			//sync width existing products			
			for ( k in app.params.keys()){
				if (k.substr(0,1) == "p"){
					var pid = k.substr(1).parseInt();					
					var cp = Lambda.find(catalogOffers, function(cp) return cp.offer.id == pid);
					
					//new products
					if (cp == null){
						cp = new pro.db.PCatalogOffer();
						cp.catalog = catalog;
						var x = pro.db.POffer.manager.get(pid, false);
						cp.offer = x;
						cp.price = x.price;
						cp.insert();
					}
				}
			}
			
			//remove products
			for ( cp in catalogOffers){
				var found = false;
				for ( k in app.params.keys()){
					if (k.substr(0, 1) == "p"){
						if (k.substr(1).parseInt() == cp.offer.id) {
							found = true;
							break;
						}
					}
				}
				if (!found){
					cp.lock();
					cp.delete();
				}
			}
			
			catalog.toSync();			
			throw Redirect("/p/pro/catalog/prices/" + catalog.id);
		}
	}
	
	/**
	 * update product prices in this catalog
	 */
	@tpl('plugin/pro/catalog/prices.mtt')
	function doPrices(catalog:pro.db.PCatalog){
		checkRights(catalog);
		view.nav.push("prices");
		view.catalogProducts = catalog.getOffers();
		view.catalog = catalog;

		if (checkToken()){
			
			for ( k in app.params.keys()){
				if (k.substr(0, 5) == "price"){
					var pid = k.substr(5).parseInt();
					var co = pro.db.PCatalogOffer.manager.select($catalog == catalog && $offerId == pid,true);
					var val = app.params.get(k);
					//trace("offre "+pid+" produit"+p.offer.product.name+" valeur :"+val+"<br/>");
					var ff = new sugoi.form.filters.FloatFilter();
					co.price = ff.filterString(val);
					co.update();
				}
			}
			
			catalog.toSync();
			
			throw Ok("/p/pro/catalog/view/"+catalog.id,"Prix mis à jour");
		}
	}
	
	@tpl('plugin/pro/catalog/view.mtt')
	function doView(catalog:pro.db.PCatalog){
		view.nav.push("view");		
		checkRights(catalog);
		view.catalog = catalog;
		view.company = catalog.company;

		if(checkToken()){
			var log = pro.service.PCatalogService.sync(catalog.id );
			throw Ok("/p/pro/catalog/view/"+catalog.id,"Mise à jour effectuée<br/>"+log.join("<br/>"));
		}
	}
	
	// @tpl('plugin/pro/catalog/conditions.mtt')
	// function doConditions(c:pro.db.PCatalog){
	// 	checkRights(c);
	// 	view.nav.push("conditions");
	// 	view.catalog = c;
		
	// 	view.data = c.deliveryAvailabilities;
		
	// 	if (app.params.exists("submit")){
	// 		//delivery availabilities
	// 		var data = new Array<{startHour:Int,startMinutes:Int,endHour:Int,endMinutes:Int}>();
	// 		for ( d in 0...7){
				
	// 			if (app.params.exists("day" + d)){
	// 				data[d] = {
	// 					startHour:app.params.get('startHour' + d).parseInt(),
	// 					startMinutes:app.params.get('startMinutes' + d).parseInt(),
	// 					endHour:app.params.get('endHour' + d).parseInt(),
	// 					endMinutes:app.params.get('endMinutes' + d).parseInt(),
					
	// 				};
					
	// 			}
	// 		}
			
	// 		c.lock();
	// 		if ( c.deliveryAvailabilities == null) c.deliveryAvailabilities = [];
	// 		c.deliveryAvailabilities = data;
			
	// 		//distance
	// 		if (app.params.exists("maxDistance")){
	// 			var d = Std.parseInt(app.params.get("maxDistance"));
	// 			c.maxDistance = d;
	// 		}else{
	// 			c.maxDistance = null;
	// 		}
			
	// 		c.update();
	// 		throw Ok("/p/pro/catalog/publish/" + c.id, "Conditions mises à jour");
	// 	}
	// }

	/**
	Create a catalog
	**/
	@tpl("plugin/pro/form.mtt")
	public function doInsert() {
		
		var catalog = new pro.db.PCatalog();
		catalog.startDate = Date.now();
		catalog.endDate = DateTools.delta(catalog.startDate, 1000.0 * 60 * 60 * 24 * 365 * 5);
		
		var f = CagetteForm.fromSpod(catalog);
		var e : sugoi.form.elements.IntSelect = cast f.getElement("vendorId");
		e.nullMessage = company.vendor.name;
		f.getElement("contractName").value = "Commande "+company.vendor.name;

		f.addElement(new sugoi.form.elements.StringSelect("visible","Visibilité",[{label:"Public",value:"public"},{label:"Privé",value:"private"}],(catalog.visible?"public":"private"),true ));

		
		if (f.isValid()) {
			f.toSpod(catalog);
			catalog.company = company;
			catalog.visible = f.getValueOf("visible") == "public";
			catalog.insert();
			throw Ok('/p/pro/catalog/products/'+catalog.id,'Le catalogue a été enregistré');
		}
		
		view.form = f;
		view.title = "Créer un nouveau catalogue";
		view.text = "Nommez votre catalogue de produits, par exemple \"Catalogue AMAP\" ou \"Tarifs Vente à la ferme\".";
	}
	
	/**
		Edit a catalog
	**/
	@tpl("plugin/pro/catalog/form.mtt")
	public function doEdit(catalog:pro.db.PCatalog) {
		checkRights(catalog);
		view.nav.push("edit");
		var f = CagetteForm.fromSpod(catalog);
		var e : sugoi.form.elements.IntSelect = cast f.getElement("vendorId");
		e.nullMessage = company.vendor.name;
		f.addElement(new sugoi.form.elements.StringSelect("visible","Visibilité",[{label:"Public",value:"public"},{label:"Privé",value:"private"}],(catalog.visible?"public":"private"),true ));

		if(catalog.contractName==null){
			f.getElement("contractName").value = "Commande "+company.vendor.name;
		}
		
		if (f.isValid()) {
			f.toSpod(catalog);
			catalog.visible = f.getValueOf("visible") == "public";
			catalog.update();

			throw Ok('/p/pro/catalog/view/'+catalog.id,'Le catalogue a été mis à jour');
		}
		
		view.form = f;
		view.title = 'Propriétés du catalogue';
		view.text = "Nommez votre catalogue de produits, par exemple \"Catalogue AMAP\" ou \"Tarifs Vente à la ferme\".";
		view.catalog = catalog;
	}
	
	function doDelete(catalog:pro.db.PCatalog){
		
		checkRights(catalog);
		
		if (checkToken()){
			
			if (connector.db.RemoteCatalog.manager.search($remoteCatalogId == catalog.id).length > 0){
				throw Error("/p/pro/catalog","Vous ne pouvez pas effacer ce catalogue car il est utilisé par vos clients.");
			}
			
			catalog.lock();
			catalog.delete();
			throw Ok("/p/pro/catalog","Catalogue supprimé");
		}
		
		
	}
	
	
	@tpl('plugin/pro/catalog/publish.mtt')
	function doPublish(catalog:pro.db.PCatalog){
		checkRights(catalog);
		view.catalog = catalog;
		view.nav.push("publish");
	}
	
	/**
	   Publish catalog in a group 
	**/
	@tpl('plugin/pro/catalog/publishGroup.mtt')
	function doPublishGroup(catalog:pro.db.PCatalog){
		checkRights(catalog);
		view.catalog = catalog;
		view.nav.push("publish");
		
		//group list
		var data = [];
		for ( a in app.user.getGroups() ){
			var ug = db.UserGroup.get(app.user, a);
			if ( ug.hasRight(Right.GroupAdmin)) data.push({label:a.name,value:a.id});
		}
		data.sort(function(a,b){
			return a.label.toUpperCase() > b.label.toUpperCase() ? 1 : -1;
		});
		
		var form = new sugoi.form.Form("publicGroup");
		form.addElement(new sugoi.form.elements.IntSelect("group","Groupe",data,null,true));
		form.addElement(new sugoi.form.elements.RadioGroup("type","Mode commande",[{label:"Commande variable",value:"1"},{label:"Contrat AMAP",value:"0"}],"1",true));

		if(form.isValid()){
			var gid : Int = form.getValueOf("group");
			var group = db.Group.manager.get(gid,false);
			var type = form.getValueOf("type")=="1" ? 1 : 0;
			try{
				pro.service.PCatalogService.linkCatalogToGroup(catalog,group,app.user.id, type);
			}catch(e:tink.core.Error){
				throw Error("/p/pro/catalog/publishGroup/"+catalog.id,e.message);
			}
			
			throw Ok("/p/pro/","Votre catalogue a bien été importé dans le groupe <b>"+group.name+"<b/>");

		}

		view.form = form;

	}
	
	
	/**
	 * Approve a catalog import
	 * @param	notif
	 */
	function doApproveImport(notif:pro.db.PNotif){
		
		notif.lock();
		if (notif.type != pro.db.PNotif.NotifType.NTCatalogImportRequest){
			throw "error";
		}
		var content : CatalogImportContent = haxe.Json.parse(notif.content);		
		var catalog = pro.db.PCatalog.manager.get( content.catalogId );		
		try{
			pro.service.PCatalogService.linkCatalogToGroup(catalog, notif.group , content.userId, content.catalogType );
		}catch(e:tink.core.Error){
			throw Error('/p/pro/',e.message);
		}
		
		
		notif.delete();
		
		throw Ok("/p/pro", "Félicitations, le catalogue a bien été relié dans à "+notif.group.name );
	}
	
	/**
	 * Accept a delivery request from a group
	 * @param	notif
	 */
	@tpl("plugin/pro/form.mtt")
	function doAcceptDelivery(notif:pro.db.PNotif){
		notif.lock();
		if (notif.type != pro.db.PNotif.NotifType.NTDeliveryRequest){
			throw "error";
		}
		
		var content : pro.db.PNotif.DeliveryRequestContent = haxe.Json.parse(notif.content);
		var catalog = pro.db.PCatalog.manager.get(content.pcatalogId,false);
		var distrib = db.MultiDistrib.manager.get(content.distribId,false);
		var rcs = connector.db.RemoteCatalog.getFromCatalog(catalog);
		var rc = Lambda.find(rcs,function(rc) return rc.getContract().group.id==notif.group.id );
		if(rc==null){
			throw Error("/p/pro","Vous n'êtes plus reliés à ce catalogue, vous pouvez supprimer cette demande.");
		}

		var contract = rc.getContract();

		if(distrib==null){
			notif.delete();
			throw Ok("/p/pro", "La distribution a été supprimée par l'administrateur du groupe, il n'est donc plus possible d'y participer");
		}

		try{
			service.DistributionService.participate(distrib,contract);
		}catch(e:tink.core.Error){
			throw Error('/p/pro/',e.message);
		}

		//email notif to sender
		if( notif.sender!=null){
			var title = "Votre invitation à la distribution du " + app.view.hDate(distrib.getDate()) + " a été acceptée par " + company.vendor.name;
			App.quickMail(notif.sender.email, title, title);
		}
		
		
		//delete notif
		notif.delete();
		
		throw Ok("/p/pro", "Vous avez accepté l'invitation à participer à la distribution du "+distrib.getDate());
		
	}
	
	/**
	 * delivery update from a group
	 * @param	notif
	 */
	@tpl("plugin/pro/form.mtt")
	function doAcceptDeliveryUpdate(notif:pro.db.PNotif){
		
		if (notif.type != pro.db.PNotif.NotifType.NTDeliveryUpdate){
			throw "error";
		}
		
		/*var content : pro.db.PNotif.DeliveryUpdate = notif.content;
		
		//creation de la livraison
		var d = db.Distribution.manager.get(content.did,true);
		d.contract = db.Catalog.manager.get(content.newDistribution.remoteContractId,false);
	

		d = service.DistributionService.edit(d,content.newDistribution.date,content.newDistribution.end,content.newDistribution.remotePlaceId,
	 	content.newDistribution.orderStartDate,content.newDistribution.orderEndDate, false);
		
		//email notif
		var title = "Votre modification de distribution du " + app.view.hDate(d.date) + " a été acceptée par " + company.vendor.name;
		App.quickMail(d.contract.contact.email, title, title);
		
		//delete notif
		notif.lock();
		notif.delete();
		
		throw Ok("/p/pro", "Vous avez bien validé la distribution");*/
		
	}

	/**
		break linkage
	**/
	function doBreakLinkage(rc:connector.db.RemoteCatalog){
		
		if (checkToken()){
			
			var c = rc.getContract(true);
			c.endDate = Date.now();
			c.update();
			
			rc.lock();
			rc.delete();
			
			throw Ok("/p/pro/catalog/","Le catalogue \""+c.name+"\" a été fermé. Il reste consultable dans les anciens contrats du groupe.");
			
		}
		
	}

	function doExport(catalog:pro.db.PCatalog){

		var datas = new Array<Array<String>>();

		for( catOff in catalog.getOffers() ){
			datas.push([catOff.offer.ref, catOff.offer.getName(), Formatting.formatNum(catOff.price)+" €" ]);
		}

		sugoi.tools.Csv.printCsvDataFromStringArray(datas,["ref","name","price"],catalog.name);
	}

}