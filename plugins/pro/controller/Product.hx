package pro.controller;
import Common.Unit;
import pro.service.PProductService;
import form.CagetteForm;
import sugoi.form.Form;

class Product extends controller.Controller
{

	var company : pro.db.CagettePro;
	var baseUrl : String;
	
	public function new()
	{
		super();
		company = pro.db.CagettePro.getCurrentCagettePro();
		view.company = company;
		//subnav
		view.nav = ["catalog"];
		baseUrl = "/p/pro/product/";
		
	}

	/**
		Products database
	**/
	@logged @tpl("plugin/pro/product/default.mtt")
	public function doDefault() {
		
		view.nav.push("default");
		var products = company.getProducts();
		view.products = products;
		
		
		var duplicateRefs = pro.db.POffer.getRefDuplicates(company);
		if(duplicateRefs.length>0){
			App.current.session.addMessage("Attention, plusieurs offres ont la même référence : <b>"+duplicateRefs.join(" ")+"</b>. Modifiez vos produits pour que chaque référence soit unique.",true);
		}
		
		view.unlinkedCatalogs = service.VendorService.getUnlinkedCatalogs(company);
		
		checkToken();
	}
	
	/**
	 * Edit a product
	 */
	@tpl('plugin/pro/form.mtt')
	public function doEdit(d:pro.db.PProduct) {

		var oldActive = d.active;
		var ref = d.ref;
		var f = PProductService.getForm(d);
		
		if (f.isValid()) {
			f.toSpod(d);
			
			//ref change
			if (ref != d.ref){
				var cats = company.getCatalogs();
				var rcs = connector.db.RemoteCatalog.manager.search($remoteCatalogId in Lambda.map(cats, function(x) return x.id ));
				for (rc in rcs){
					var offs = rc.getCatalog().getOffers();
					for ( o in offs){
						if ( o.offer.product.id == d.id) throw Error(baseUrl, "Vous ne pouvez pas changer la référence de ce produit car il est déjà visible dans la boutique de vos clients.");
					}
				}
			}
			
			//update related offers
			if (d.active!=oldActive){
				for ( o in d.getOffers(true)) {
					o.active = d.active;
					o.update();
				}
			}
			
			//ref uniqueness
			if (pro.db.PProduct.refExists(company, d.ref, d)){
				throw Error(baseUrl, "Cette référence est déjà utilisée dans votre catalogue");
			}
			
			//if offers are in catalogs, update the lastUpdate field of the catalog (for synch purpose)
			var offersId = Lambda.map(d.getOffers(false), function(o) return o.id);
			var coffers = pro.db.PCatalogOffer.manager.search($offerId in offersId, false);
			var catalogs = pro.db.PCatalog.manager.search( $id in Lambda.map(coffers, function(x) return x.catalog.id) , true);
			for ( c in catalogs) c.toSync();
			
			d.update();
			throw Ok('/p/pro/product#product' + d.id, 'Le produit a été mis à jour');			
		}
		
		view.form = f;
		view.title = 'Modifier produit "${d.name}"';
	}
	
	/**
	 * Create a new product
	 */
	@tpl("plugin/pro/form.mtt")
	public function doInsert() {
		
		var p = new pro.db.PProduct();
		var f = PProductService.getForm(p,this.company);
		
		if (f.isValid()) {
			f.toSpod(p); //update model
			p.company = company;

			if(p.unitType==null) p.unitType = Unit.Piece;
	
			if (pro.db.PProduct.refExists(company, p.ref)){
				throw Error(baseUrl, "cette référence est déjà utilisée dans un autre produit");
			}
			
			p.insert();
			throw Ok(baseUrl,'Le produit a été enregistrée');
		}
		
		view.form = f;
		view.title = "Enregistrer un nouveau produit";
	}
	
	/**
	 * delete a product and its offers if not present in a catalog
	 * @param	p
	 */
	public function doDelete(p:pro.db.PProduct) {
		
		if (checkToken()){
			
			var errors = [];
			
			for ( o in p.getOffers(true)){
				var catalogOffers = o.getCatalogOffers();
				if (catalogOffers.length > 0){
					errors.push( o.getName() + " est référencée dans le catalogue " + Lambda.map(catalogOffers, function(co) return "\"" + co.catalog.name+"\"" ).join(", ") + ". <br/>Plutôt que d'effacer définitivement cette offre, il est recommandé de simplement la retirer du catalogue.");				
				}else{
					o.delete();
				}
			}
			
			if (errors.length == 0){
				p.lock();
				p.delete();	
				throw Ok(baseUrl,"Produit supprimé");	
			}else{
				for ( e in errors ) App.current.session.addMessage(e, true);
				throw Redirect(baseUrl);	
			}
		}
	}
	
	/**
	 * import products and offers
	 */
	@tpl('plugin/pro/product/import.mtt')
	function doImport(?args: { confirm:Bool,disableMissingProducts:Bool,ttcPrices:Bool,doNotUpdateBaseProducts:Bool } ) {
			
		var step = 1;
		var request = sugoi.tools.Utils.getMultipart(1024 * 1024 * 4);
		var s = new pro.service.PProductService(company);
		
		// preview mode
		if (request.exists("file")) {
			step = 2;
			try{
				view.preview = s.importFromCsv(request.get("file"), true, false,false);
			}catch(e:tink.core.Error){
				throw Error("/p/pro/product/import",e.message);
			}
			
			view.catalogs = company.getCatalogs();
		}
		
		//confirm import
		else if (args != null && args.confirm) {

			if(args.disableMissingProducts==null) args.disableMissingProducts=false;
			if(args.ttcPrices==null) args.ttcPrices=false;
			if(args.doNotUpdateBaseProducts==null) args.doNotUpdateBaseProducts=false;
			
			//catalogs
			var catalogs = [];
			for ( k in app.params.keys()){
				if ( k.substr(0, 3) == "cat" ){
					catalogs.push(  Std.parseInt( k.substr(3) ) );					
				}
			}
			var out;
			try{
				out = s.importFromCsv(null,false,args.disableMissingProducts,args.ttcPrices,catalogs,args.doNotUpdateBaseProducts);						
			}catch(e:tink.core.Error){
				throw Error("/p/pro/product/import",e.message);
			}

			//output
			var numImported = 0;
			var numUpdated = 0;
			if(out!=null){
				for( p in out){
					if(Reflect.field(p.product,"newProduct")==1) numImported++ else numUpdated++;
				}
			}

			view.numImported = numImported;			
			view.numUpdated = numUpdated;
			
			step = 3;
		}
		
		view.step = step;
	}
	
}