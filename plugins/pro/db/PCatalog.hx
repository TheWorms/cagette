package pro.db;
import sys.db.Object;
import sys.db.Types;
import Common;

/**
 * Catalog
 */
class PCatalog extends Object
{
	public var id : SId;
	public var name : SString<128>;					//catalog name
	public var contractName : SNull<SString<128>>;	//catalog name in groups
	
	public var startDate : SDateTime;			
	public var endDate : SDateTime;			
	//achat-revente uniquement
	@:relation(vendorId) @formPopulate("populateVendor") public var vendor : SNull<db.Vendor>;

	@hideInForms public var visible : SBool;
	
	@hideInForms public var maxDistance : SNull<SInt>; //max distance in km
	
	@hideInForms @:relation(companyId) 	public var company : pro.db.CagettePro;
	@hideInForms public var lastUpdate : SDateTime;
	
	public function new(){
		super();
		lastUpdate = Date.now();
		visible = true;
	}

	public function isActive(){
		var now = Date.now().getTime();
		return now >= startDate.getTime() && now <= endDate.getTime();
	}
	
	public function getOffers():Array<pro.db.PCatalogOffer>{
		//order by product name
		var sql = "select pc.* from PCatalogOffer pc,POffer off,PProduct p where pc.catalogId="+this.id+" and pc.offerId=off.id and off.productId=p.id order by p.name";		
		return Lambda.array( pro.db.PCatalogOffer.manager.unsafeObjects(sql,false) );
		//return Lambda.array(pro.db.PCatalogOffer.manager.search($catalog == this,{orderBy:$offer.name},false));
	}
	
	public function getProducts(){
		var out = new Map<Int,{product:pro.db.PProduct,offers:Array<pro.db.PCatalogOffer>}>();
		
		for (co in getOffers()){
			var off = co.offer;
			var pi = out.get(off.product.id);
			if (pi == null) pi = {product:off.product, offers:[]};
			pi.offers.push(co);
			out.set(off.product.id, pi);
		}
		
		//alphabetical
		var arr = Lambda.array(out);
		arr.sort(function(a, b){
			return (a.product.name > b.product.name) ? 1 : -1;
		});
		
		return arr;
	}
	
	/**
	 * get a vendor list as form data
	 * @return
	 */
	public function populateVendor():sugoi.form.ListData.FormData<Int>{
		var vendors = pro.db.CagettePro.getCurrentCagettePro().getVendors();
		var out = [];
		for (v in vendors) {
			out.push({label:v.name, value:v.id });
		}
		return out;
	}
	
	/**
	 * set toSync flag to true with all related contracts
	 */
	public function toSync(){
		
		this.lock();
		this.lastUpdate = Date.now();
		this.update();
		
		for ( rc in connector.db.RemoteCatalog.getFromCatalog(this,true)){
			
			rc.needSync = true;
			rc.update();
		}
	}
	
	public static function getLabels(){
		var t = sugoi.i18n.Locale.texts;
		return [
			"name" 		=> /*t._("Catalog name")*/"Nom du catalogue",
			"startDate"	=> t._("Start date"),
			"endDate"	=> t._("End date"),
			"vendor" 	=> t._("Farmer"),						
			"contractName"	=> "Nom à afficher dans les groupes",
		];
	}
	
}

