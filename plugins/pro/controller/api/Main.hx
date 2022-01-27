package pro.controller.api;

/**
 * Cagette pro API
 * 
 * @author fbarbut
 * @doc https://app.swaggerhub.com/apis/Cagette.net/Cagette-Pro/0.9.2
 */
class Main extends sugoi.BaseController
{

	public function new() 
	{
		super();
	}
	
	public function doDefault(){
	}
	
	/**
	 * update products and catalogs
	 */
	public function doUpdateCatalog(company:pro.db.CagettePro){
		
		checkKey(company);
		
		var csv = app.params.get("csvData");
		if (csv == null) throw new tink.core.Error(500, "Empty csv datas");
		
		var catalogs = [];
		if (app.params.exists("catalogIds")){
			catalogs = app.params.get("catalogIds").split("|").map(Std.parseInt);
		}
		
		var s = new pro.service.PProductService(company);
		var out = s.importFromCsv(csv,false,true,catalogs);
		
		Sys.print('{"ok":1,"message":"${out.length} products updated"}');
		
	}
	
	
	public function checkKey(?c:pro.db.CagettePro){
		
		var k = sugoi.Web.getClientHeader("X-API-Key");
		if (k == null) throw new tink.core.Error(403, "You should provide a valid API key");
		
		var user = db.User.manager.select($apiKey == k, false);
		if ( user == null ) throw new tink.core.Error(403, "No user linked to this key");
		
		var found = false;
		if (c != null){
			for ( u in c.getUsers()){
				if (u.id == user.id) {
					found = true;
					break;
				};
			}
		}
		
		if(!found) throw new tink.core.Error(403, "Access forbidden to this company");
		
	}
	
	/**
		Catalog infos via API
	**/
	public function doCatalog(c:pro.db.PCatalog){
		var out = {products:[]};
		for( co in c.getOffers()){
			var i = co.offer.getInfos();
			i.price = co.price;
			out.products.push(i);
		}
		Sys.print(haxe.Json.stringify(out));
	}


	public function doDfc(version:String,d:haxe.web.Dispatch){
		d.dispatch(new pro.controller.api.DFC());
	}

}