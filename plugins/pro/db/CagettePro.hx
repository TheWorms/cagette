package pro.db;
import Common;
import sys.db.Types;

/**
 * Cagette Pro account linked to a Vendor Account
 * @author fbarbut
 */
class CagettePro extends sys.db.Object
{
	public var id : SId;
	@hideInForms @:relation(vendorId) public var vendor : db.Vendor;
	@hideInForms @:relation(demoCatalogId) public var demoCatalog : SNull<pro.db.PCatalog>;//catalog used for public page
	@hideInForms public var vatRates : SNull<SSmallText>;
	@hideInForms public var training:SBool;	//training account
	@hideInForms public var network:SBool;	//enable network management features
	@hideInForms public var captiveGroups:SBool;	//the groups are a captive network
	@hideInForms public var discovery:SBool;	//Offre Découverte
	@hideInForms public var networkGroupIds:SNull<SString<512>>; //network groups, ints separated by comas
	@hideInForms public var cdate:SNull<SDateTime>; //date when vendor became Cagette Pro
	
	public function new(){
		super();
		setVatRates([{label:"TVA alimentaire 5,5%",value:5.5},{label:"TVA 20%",value:20},{label:"Non assujeti à TVA", value:0}]);
		training = false;
		network = false;		
		cdate = Date.now();
	}

	public static function getCurrentVendor():db.Vendor{

		if (App.current.session.data == null || App.current.session.data.vendorId == null) {
			return null;
		}else{			
			var v = db.Vendor.manager.get(App.current.session.data.vendorId, false);	
			//if (v == null) throw "no vendor selected" else return v;
			return v;
		}
	}

	public static function getFromVendor(vendor:db.Vendor){
		return manager.select($vendor==vendor,false);
	}

	/**
	 * get current connected company 
	 */
	public static function getCurrentCagettePro():CagettePro{
		
		var v = getCurrentVendor();
		if(v==null) return null;

		var cpro = manager.select($vendor==v,false);
		if(cpro==null) return null else return cpro;

	}
	
	public function getProducts(){
		return pro.db.PProduct.manager.search($company == this,{orderBy:name},false);
	}
	
	public function getCatalogs(){
		return pro.db.PCatalog.manager.search($company == this, {orderBy:name}, false);
	}


	public function getActiveCatalogs(){
		var now = Date.now();
		return pro.db.PCatalog.manager.search($company == this && $startDate < now && $endDate > now, {orderBy:name}, false);
	}

	public function getActiveVisibleCatalogs(){
		var now = Date.now();
		return pro.db.PCatalog.manager.search($company == this && $visible==true && $startDate < now && $endDate > now, {orderBy:name}, false);
	}
	
	public function getOffers(){
		var out = [];
		for ( p in getProducts()){
			for ( o in p.getOffers()){
				out.push(o)	;
			}
			
		}
		return out;
	}

	public function setVatRates(rates:Array<{value:Float,label:String}>){
		vatRates = haxe.Json.stringify(rates);
	}

	public function getVatRates():Array<{value:Float,label:String}>{
		try{
			return haxe.Json.parse(vatRates);
		}catch(e:Dynamic){
			var rates = [{label:"TVA alimentaire 5,5%",value:5.5},{label:"TVA 20%",value:20},{label:"Non assujeti à TVA", value:0}];
			this.lock();
			setVatRates(rates);
			this.update();
			return rates;
		}
	}
	
	/**
	 *  Get users who have access to this company (cpro account)
	 */
	public function getUsers(){
		return Lambda.map(pro.db.PUserCompany.getUsers(this),function(x) return x.user);
	}

	public function getUserCompany(){
		return pro.db.PUserCompany.getUsers(this);
	}

	/**
	 * Check if a new reference is not already taken in this company's products
	 * @param	ref
	 * @deprecated
	 */
	public function refExists(ref:String,?excludeProduct:pro.db.PProduct,?excludeOffer:pro.db.POffer):Bool{
		
		var prods = pro.db.PProduct.manager.search($ref == ref && $company == this, false);
		var pids = Lambda.map(getProducts(), function(x) return x.id);
		var offers = pro.db.POffer.manager.search($ref == ref && $productId in pids, false);
		
		//exclusions
		if (excludeProduct != null){
			for (p in Lambda.array(prods)){
				if ( p.id ==  excludeProduct.id ) prods.remove(p);
			}
		}
		
		if (excludeOffer != null){
			for (o in Lambda.array(offers)){
				if ( o.id ==  excludeOffer.id ) offers.remove(o);
			}
		}
		
		if ( prods.length > 0 || offers.length > 0){
			return true;
		}else{
			return false;
		}
		
	}
	
	/**
		get vendors linked to this company (product reselling/distribution)
	**/
	public function getVendors():Array<db.Vendor>{
		return Lambda.map(pro.db.PVendorCompany.manager.search($company == this, false), x -> x.vendor).array();
	}


	public function getClients():Array<db.Group>{

		var remoteCatalogs = connector.db.RemoteCatalog.manager.search($remoteCatalogId in Lambda.map(this.getCatalogs(), function(x) return x.id), false); 
		var clients = [];
		for ( rc in Lambda.array(remoteCatalogs)){
			var contract = rc.getContract();
			if (contract != null) {
				clients.push(contract.group);
			}
		}
		//sort by group name
		var clients = Lambda.array(clients);
		clients = tools.ObjectListTool.deduplicate(clients);

		clients.sort(function(b, a) {
			return (a.name.toUpperCase() < b.name.toUpperCase())?1:-1;
		});

		return clients;
	}

	/**
		can this user acces this vendor/cpro account ?
	**/
	public static function canLogIn(user:db.User,vendor:db.Vendor){
		if(user.isAdmin()) return true;

		var cpro = vendor.getCpro();
		if(cpro!=null){
			var cpros = pro.db.PUserCompany.getCompanies(user);
			return Lambda.exists(cpros, function(a) return a.id == cpro.id);
		}else{
			return false;
		}
	}
	
	public function getGroups(){
		var remoteCatalogs = connector.db.RemoteCatalog.manager.search($remoteCatalogId in Lambda.map(this.getCatalogs(), function(x) return x.id), false); 
		var groups = [];
		for ( rc in Lambda.array(remoteCatalogs)){
			var contract = rc.getContract();
			if(contract==null || contract.group==null) continue;
			groups.push(contract.group);			
		}
		return tools.ObjectListTool.deduplicate(groups);
	}

	public function setNetworkGroupIds(_groupIds:Array<Int>){
		this.lock();
		this.networkGroupIds = _groupIds.join(",");
		this.update();
	}

	public function getNetworkGroupIds():Array<Int>{
		if(this.networkGroupIds==null) return [];
		return this.networkGroupIds.split(",").map(Std.parseInt);
	}

	public function getNetworkGroups():Array<db.Group>{
		return getNetworkGroupIds().map(function(id) return db.Group.manager.get(id)).filter( function(g) return g!=null );
	}

	public function infos(): CagetteProInfo {
		return vendor.getInfos();
	}

	
	public static function getLabels(){
		var t = sugoi.i18n.Locale.texts;
		return [
			"name" 		=> /*t._("Company name")*/"Nom de votre structure",
			"email" 	=> t._("Email"),
			"phone"		=> t._("Phone"),
			"address1" 	=> t._("Address 1"),			
			"address2"	=> t._("Address 2"),			
			"zipCode" 	=> t._("Zip code"),			
			"city" 		=> t._("City"),			
			"desc" 		=> t._("Description"),			
			"linkText" 	=> /*t._("Website Label")*/"Nom du site Web",			
			"linkUrl" 	=> /*t._("Website URL")*/"URL du site web",			
			"freeCpro" 	=> "Accès gratuit à Cagette Pro (stagiaire formation)",		
		];
	}
}