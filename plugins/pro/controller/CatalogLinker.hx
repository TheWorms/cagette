package pro.controller;
import pro.db.PCatalog;
import pro.service.PCatalogService;
import pro.db.POffer;
import connector.db.RemoteCatalog;
import service.VendorService;
import Common;
using tools.ObjectListTool;

class CatalogLinker extends controller.Controller
{
	var company : pro.db.CagettePro;
	var vendor : db.Vendor;
	
	public function new() 
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.vendor = vendor = pro.db.CagettePro.getCurrentVendor();
	}
		
	/**
		choose which invited catalog to link
	**/
	@logged @tpl("plugin/pro/catalogLinker/default.mtt")
	public function doDefault(){
				
		view.unlinkedCatalogs = VendorService.getUnlinkedCatalogs(company);
		view.vendorId = vendor.id;
	}

	@logged @tpl("plugin/pro/catalogLinker/selectPCatalog.mtt")
	public function doSelectPcatalog(c:db.Catalog){
				
		view.pcatalogs = company.getCatalogs();
		view.catalog = c;
		
	}

	/**
		linking tool
	**/
    @logged @tpl("plugin/pro/catalogLinker/link.mtt")
	public function doLink(catalog:db.Catalog, pcatalog:pro.db.PCatalog){
				
		view.pcatalog = pcatalog;
        view.catalog = catalog;
		checkToken();
	}

	@logged @tpl("plugin/pro/catalogLinker/importFirstCatalog.mtt")
	public function doImportFirstCatalog(?catalog:db.Catalog){

		if(catalog!=null){
			if(company.getProducts().length>0) throw Error("/p/pro","Action interdite, vous avez déjà des produits dans votre compte producteur");

			pro.service.PCatalogService.linkFirstCatalog(catalog,company);
			throw Ok('/p/pro/product',"Bravo, vous avez récupéré votre premier catalogue ! Vérifiez que les fiches produits sont correctes.");

		}else{
			view.unlinkedCatalogs = VendorService.getUnlinkedCatalogs(company);
		}
	}

	public function doSubmitLinkage(catalog:db.Catalog,pcatalog:pro.db.PCatalog){

		if(checkToken()){
			var linkage = [];
			for( k in app.params.keys()){
				if(k.substr(0,1)=="p"){
					linkage.push({
						productId:k.substr(1).parseInt(),
						offerId:app.params.get(k).parseInt()
					});
				}
			}

			//product linkage is made thru refs
			for(l in linkage){

				var offer = POffer.manager.get(l.offerId,true);
				var product = db.Product.manager.get(l.productId,true);

				//besoin d'une ref : en générer une si null ou si doublons dans cette base de produits
				if(offer.ref==null || offer.ref=="" || pro.db.POffer.getRefDuplicates(company).length>0){
					offer.ref = pro.service.PProductService.generateRef(company);
					offer.update();
				}

				product.ref = offer.ref;
				product.update();

			}

			//create link to remote catalog
			PCatalogService.link(pcatalog,catalog);

			//make a sync 
			PCatalogService.sync(pcatalog.id);

			throw Ok("/p/pro/catalog" , "Le catalogue a été correctement relié");
		}

	}


	/**
		rest service
	**/
	function doCreateNewOffer(product:db.Product,pcatalog:pro.db.PCatalog){

		if(product==null || pcatalog==null){
			json({
				error : "mauvais produit ou mauvais catalogue"
			});
			return;
		}

		if( company.getActiveCatalogs().find( cat -> return cat.id==pcatalog.id )==null ){
			json({
				error : "Ce catalogue ne vous appartient pas"
			});
			return;
		}

		//create product+offer
		var pp = new pro.db.PProduct();
		var p = product;
		pp.name = p.name;
		// créé une ref si existe pas...
		// if (p.ref == null || p.ref == "") {
			p.lock();
			p.ref = pro.service.PProductService.generateRef(company);
			p.update();
		// }
		pp.ref = p.ref;
		pp.image = p.image;
		pp.desc = p.desc;
		pp.company = this.company;
		pp.unitType = p.unitType;
		pp.active = p.active;
		pp.organic = p.organic;
		pp.txpProduct = p.txpProduct;
		pp.bulk = p.bulk;
		pp.multiWeight = p.multiWeight;
		pp.variablePrice = p.variablePrice;
		pp.insert();

		// create one offer
		var off = new pro.db.POffer();
		off.price = p.price;
		off.vat = p.vat;
		off.ref = pp.ref + "-1";
		off.product = pp;
		off.quantity = p.qt;
		off.active = p.active;
		off.smallQt = p.smallQt;
		off.insert();
	
		pro.db.PCatalogOffer.make(off,pcatalog,p.price);

		json({
			success:true,
			offer : {
				name: off.getName(),
				id: off.id,
				price: off.price
			}
		});


	}

}