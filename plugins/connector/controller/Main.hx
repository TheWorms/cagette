package connector.controller;
import Common;
/**
 * ...
 * @author fbarbut
 */
class Main extends controller.Controller
{

	public function new() 
	{
		super();
	}
	
	@tpl("plugin/pro/contract.mtt")
	public function doContract(c:db.Catalog){
		
		new controller.ContractAdmin().sendNav(c);
		view.c = c;
		view.nav = ["contractadmin", "cpro"];
		
		
		var rc = connector.db.RemoteCatalog.manager.get(c.id);
		view.linkage = rc;
		view.catalog = rc.getCatalog();

		if(checkToken()){
			c.lock();
			c.endDate = Date.now();
			c.update();
			
			rc.lock();
			rc.delete();
			
			throw Ok("/contractAdmin/view/"+c.id,"Le contrat \""+c.name+"\" a été archivé.");
			
		}

		
	}
}