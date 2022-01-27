package pro.controller;


class Notif extends controller.Controller
{

	var company : pro.db.CagettePro;
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.category = "notif";		
	}
	
	public function doDelete(n:pro.db.PNotif) {
		
		if (checkToken()){
			n.lock();
			n.delete();
			throw Ok("/p/pro", "Notification effacée");
			
			//TODO : faire un mail à l'emetteur
		}
		
	}
	
	@logged @tpl("plugin/pro/notif.mtt")
	public function doView(n:pro.db.PNotif){
		view.category = "home";
		view.notif = n;
		view.notifContent = n.getContent();
		view.getCatalog = function(cid){
			return pro.db.PCatalog.manager.get(cid, false);
		}
				
		view.getOffer = function(ref:String){			
			var pids = Lambda.map(n.company.getProducts(),function(x) return x.id);
			return pro.db.POffer.manager.select($ref == ref && $productId in pids, false);
		}

		view.getDistrib = function(did:Int){
			return db.MultiDistrib.manager.get(did,false);
		}
		checkToken();
	}
	
	
	
}