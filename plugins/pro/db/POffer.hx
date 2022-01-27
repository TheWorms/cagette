package pro.db;
import sys.db.Object;
import sys.db.Types;
import Common;

/**
 * Cagette-pro Offer
 */
class POffer extends Object
{
	public var id : SId;
	public var name : SNull<SString<128>>;	//product name
	public var ref : SString<32>;	//product ref or short code
	@hideInForms @:relation(productId) public var product : pro.db.PProduct;
	@hideInForms @:relation(imageId) public var image : SNull<sugoi.db.File>; //custom image
	public var quantity : SNull<SFloat>; //quantity of units (kg,L,g,units)
	//@hideInForms public var htPrice : SFloat; //price excluding VAT @deprecated
	public var price : SFloat; //price including VAT
	public var vat : SFloat;
	public var smallQt : SNull<SFloat>; //if bulk is true, a smallQt should be defined
	public var active : SBool; 	//if false, product disabled, not visible on front office
	
	@hideInForms public var stock : SNull<SFloat>; // Current stock of this offer (available for sale + undelivered orders)
	
	public function new() 
	{
		super();
		active = true;
		vat = 5.5;
		price = 0;
		//htPrice = 0;
		quantity = 1;
	}
	
	override public function toString(){
		return "#"+id+"-"+getName();		
	}
	
	public function getCatalogOffers(?lock=false){		
		return pro.db.PCatalogOffer.manager.search($offer == this,lock);		
	}
	
	/**
	 * Counts ordered but undelivered units of this offer
	 */
	@:skip public var products : Array<db.Product>;
	
	public function countCurrentUndeliveredOrders(){
		products = [];
		var i = 0.0;
		//Attention : ne pas ommettre les distribs ou ce produit était présent, même si il n'est plus dans le catalogue actuellement.
		//donc on check tous les catalogues
		for ( catalog in this.product.company.getCatalogs() ){			
			var rcs = connector.db.RemoteCatalog.getFromCatalog(catalog);
			for (rc in rcs){
				var contract = rc.getContract();				
				var product = db.Product.manager.select($ref == this.ref && $catalog == contract, false);
				var distribs = db.Distribution.manager.search($catalog == contract && $orderStartDate < Date.now() && $date > Date.now() , false );
				
				//count how many groups with open order 
				for ( d in distribs){
					if ( d.orderEndDate.getTime() > Date.now().getTime()){
						products.push(product);
						break;
					}
				}
				
				for ( d in distribs){
					for ( o in db.UserOrder.manager.search($product == product && $distribution == d)){
						i += o.quantity;
					}
				}
			}
			
		}
		return i ;
	}
	
	/**
	 * Check ref is not null when inserting
	 */
	override public function insert(){		
		if (ref == null) throw 'An offer ref cant be null (${this.product.name}-${this.name})';
		if (ref == "") throw 'An offer ref cant be empty (${this.product.name}-${this.name})';
		if(quantity==0.0) quantity = null;
		super.insert();		
	}

	override public function update(){
		if(quantity==0.0) quantity = null;
		price = Formatting.roundTo(price,2);
		super.update();
	}
	
	public function getName(){
		var n = product.name;
		
		if (name != null)
			n += " " + name;
		
		if (quantity != null && product.unitType!=null)
			n += " " + this.quantity + " " + Formatting.unit(product.unitType,quantity);
			
		return n;
	}
	
	/**
	 * get infos like if its a product
	 * @return
	 */
	public function getInfos():ProductInfo{
		var img = getImage();
		if (img == "") img = product.getImage();
		
		return {
			id : null,
			name : this.getName(),
			ref : ref,
			image : img,
			catalogId : null,
			price : this.price,
			vat : this.vat,
			vatValue : null,			//montant de la TVA incluse dans le prix
			catalogTax : null, 	
			catalogTaxName : null,	
			desc : product.desc,
			categories : [],	//used in old shop
			subcategories : [],  //used in new shop
			orderable : false,			//can be currently ordered
			stock: null,			//available stock
			qt:this.quantity,
			unitType:this.product.unitType,
			organic:this.product.organic,
			variablePrice: this.product.variablePrice,
			wholesale :this.product.wholesale,
			bulk: this.product.bulk,
			active : this.active
		}
	}
	
	
	public static function getByRef(ref:String, product:pro.db.PProduct, ?lock = false){		
		return manager.select(ref == $ref && $product == product , lock);				
	}
	
	/**
	 * check if a ref is not used by another offer
	 * @param	company
	 * @param	ref
	 * @param	excludeOffer
	 * @return
	 */
	public static function refExists(company:pro.db.CagettePro, ref:String,?excludeOffer:pro.db.POffer):Bool{
		
		var pids = Lambda.map(company.getProducts(), function(x) return x.id);
		var offers = pro.db.POffer.manager.search($ref == ref && $productId in pids, false);
		if (excludeOffer != null){
			for (o in Lambda.array(offers)){
				if ( o.id ==  excludeOffer.id ) offers.remove(o);
			}
		}
		return offers.length > 0;
	}

	/**
		get duplicate refs in offers
	**/
	public static function getRefDuplicates(cagettePro:pro.db.CagettePro):Array<String>{
		//global check on refs unicity
		var refs = new Map<String,Int>();
		for ( p in cagettePro.getProducts() ){
			for ( o in p.getOffers(false)){
				var i = refs.get(o.ref);
				if (i == null){
					refs.set(o.ref, 1);
				}else{
					refs.set(o.ref, i + 1);
				}				
			}
		}
		var duplicates = [];
		for ( k in refs.keys()){
			if(refs.get(k)>1) {
				duplicates.push(k);
			}
		}
		return duplicates;
	}
		
	public static function getLabels(){
		//var t = sugoi.i18n.Locale.texts;
		return [
			"name" 			=> "Conditionnement (optionnel)",
			"ref" 			=> "Référence",
			"htPrice"		=> "Prix HT",
			"price"			=> "Prix TTC",
			"active" 		=> "Actif",			
			"quantity"		=> "Quantité",			
			"vat" 			=> "Taux de TVA",			
		];
	}
	
	public function getImage() {
		if (imageId == null) {
			if(this.product.getImageId() != null){
				return this.product.getImage();
			}else{				
				if (this.product.txpProduct != null){				
					return "/img/taxo/grey/" + this.product.txpProduct.subCategory.category.image + ".png";
				}else{
					return "/img/taxo/grey/legumes.png";
				}	
			}
			
		}else {
			return App.current.view.file(imageId);
		}
	}
}

