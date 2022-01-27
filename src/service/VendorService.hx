package service;

class VendorService{

	public function new(){}

	/**
		Get or create+link user account related to this vendor.
	**/
	public static function getOrCreateRelatedUser(vendor:db.Vendor){
		if(vendor.user!=null){
			return vendor.user;
		}else{
			var u = service.UserService.getOrCreate(vendor.name,null,vendor.email);
			vendor.lock();
			vendor.user = u;
			vendor.update();
			return u;
		}
	}

	/**
		Get vendors linked to a user account
	**/
	public static function getVendorsFromUser(user:db.User):Array<db.Vendor>{
		//get vendors linked to this account
		//var vendors = Lambda.array( db.Vendor.manager.search($user==user,false) );
		var vendors = [];
		return vendors;
	}

	/**
		Send an email to the vendor
	**/
	public static function sendEmailOnAccountCreation(vendor:db.Vendor,source:db.User,group:db.Group){

		return;
		
		// the vendor and the user is the same person
		if(vendor.email==source.email) return;
		if(vendor.user==null) throw "Vendor should have a user";
		if(group==null) throw "a group should be provided";
	}

	/**
		Search vendor by name or email
	**/
	public static function findVendors(name:String,?email:String){
		var vendors = [];
		for( n in name.split(" ")){
			n = n.toLowerCase();
			if(Lambda.has(["le","la","les","du","de","l'","a","à","au","en","sur","qui","ferme","GAEC","EARL","SCEA","jardin","jardins"],n)) continue;
			//search for each term
			//var search = Lambda.array(db.Vendor.manager.unsafeObjects('SELECT * FROM Vendor WHERE name LIKE "%$n%" LIMIT 20',false));
			var search = Lambda.array(db.Vendor.manager.search( $name.like('%$n%'),{limit:20},false));
			vendors = vendors.concat(search);
		}

		//search by mail
		if(email!=null){
			vendors = vendors.concat(Lambda.array(db.Vendor.manager.search($email==email,false)));
		}
		
		vendors = tools.ObjectListTool.deduplicate(vendors);

		return vendors;
	}


}