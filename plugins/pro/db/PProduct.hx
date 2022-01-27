package pro.db;
import sys.db.Object;
import sys.db.Types;
import Common;

enum ProductStockStrategy{
	ByOffer;
	ByProduct;	
}

/**
 * Cagette-Pro Product
 */
class PProduct extends Object
{
	public var id : SId;
	public var name : SString<128>;			//product name
	public var ref : SString<32>;	//product ref or short code
	//@hideInForms @:relation(taxoId) 	public var taxo : SNull<db.TxpProduct>;
	@hideInForms @:relation(companyId) 	public var company : pro.db.CagettePro;
	public var desc : SNull<SText>;
	@hideInForms @:relation(imageId) public var image : SNull<sugoi.db.File>; //custom image
	
	public var active : SBool; 	//if false, product disabled, not visible on front office	
	public var unitType : SNull<SEnum<Unit>>; // Kg / L / g / units	
	public var organic : SBool;
	public var variablePrice : Bool; 	//price can vary depending on weighting of the product
	public var multiWeight : Bool;		//product cannot be cumulated in one db.UserOrder
	
	//https://docs.google.com/document/d/1IqHN8THT6zbKrLdHDClKZLWgKWeL0xw6cYOiFofw04I/edit
	@hideInForms public var wholesale : Bool;  //this product is a wholesale product (crate,bag,pallet)
    @hideInForms public var retail : Bool;     //this products is a fraction of a wholesale product
	public var bulk : Bool;       //(vrac) warn the customer this product is not packaged

	@:relation(txpProductId) public var txpProduct : SNull<db.TxpProduct>; //taxonomy

	//public var stockStrategy : SEnum<ProductStockStrategy>;
	@hideInForms public var stock : SNull<SFloat>; // Current stock of this product (available for sale + undelivered orders)
	
	public function new() 
	{
		super();
		active = true;
		unitType = Unit.Piece;
		variablePrice = false;
		multiWeight = false;
		organic = false;
		//stockStrategy = ByOffer;
	}
	
	/**
	 * Returns the URL of the product image
	 */
	public function getImage() {
		if (imageId == null) {
			if (txpProduct != null){				
				return "/img/taxo/grey/" + txpProduct.subCategory.category.image + ".png";
			}else{
				return "/img/taxo/grey/fruits-legumes.png";
			}			
		}else {
			return App.current.view.file(imageId);
		}
	}

	public function getImageId(){
		return this.imageId;
	}
	
	override function toString() {
		if (name != null) {
			return name;
		}else {
			return "produit";
		}		
	}
	
	public function getOffers(?lock=false){
		return pro.db.POffer.manager.search($product == this,{orderBy:-quantity}, lock);
	}
	
	/**
	 * Search a product by reference
	 * @param	ref
	 */
	public static function searchByRef(ref:String,company:pro.db.CagettePro,?lock=false){
		return manager.search($ref == ref && $company==company, lock);
	}
	
	public static function getByRef(ref:String,company:pro.db.CagettePro,?lock=false){
		return manager.select($ref == ref && $company==company, lock);
	}
	
	/**
	 * Check if this ref is not used by another product
	 * @param	ref
	 * @param	excludeProduct
	 * @return
	 */
	public static function refExists(company:pro.db.CagettePro, ref:String,?excludeProduct:pro.db.PProduct):Bool{
		
		var prods = pro.db.PProduct.manager.search($ref == ref && $company == company, false);
		if (excludeProduct != null){
			for (p in Lambda.array(prods)){
				if ( p.id ==  excludeProduct.id ) prods.remove(p);
			}
		}
		return prods.length > 0;
	}

	/**
	 * counts ordered but undelivered units of this product
	 */
	@:skip public var products : Array<db.Product>;
	
	public function countCurrentUndeliveredOrders(){
		products = [];
		var i = 0.0;
		for( offer in getOffers()){
			for ( co in offer.getCatalogOffers()){
			
				var rcs = connector.db.RemoteCatalog.getFromCatalog(co.catalog);
				for (rc in rcs){
					var contract = rc.getContract();				
					var product = db.Product.manager.select($ref == offer.ref && $catalog == contract, false);
					var distribs = db.Distribution.manager.search($catalog == contract && $orderStartDate < Date.now() && $date > Date.now() );
					
					//count how many groups with open order 
					for ( d in distribs){
						if ( d.orderEndDate.getTime() > Date.now().getTime()){
							products.push(product);
							break;
						}
					}
					
					for ( d in distribs){
						for ( o in db.UserOrder.manager.search($product == product && $distribution == d)){
							i += o.quantity * product.qt;
						}
					}
				}
			
			}

		}
		
		return i ;
	}
	
	public static function getLabels(){
		var t = sugoi.i18n.Locale.texts;
		return [
			"name" 				=> t._("Product name"),
			"ref" 				=> t._("Product ID"),
			"desc" 				=> t._("Description"),
			"unitType" 			=> t._("Base unit"),
			"active" 			=> /*t._("Active")*/"Actif",			
			"organic" 			=> t._("Organic agriculture"),			
			"variablePrice" 	=> "Prix variable selon pesée"/*t._("Variable price based on weight")*/,			
			"multiWeight" 		=> "Multi-pesée",	
			"stockStrategy"		=> "Gestion des stocks",
			"bulk"				=> "Vrac"
		];
	}
}

