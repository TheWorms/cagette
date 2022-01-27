package pro.controller;
import pro.service.PStockService;
import sugoi.form.Form;
import Common;
using Std;

class Stock extends controller.Controller
{

	var company : pro.db.CagettePro;
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.category = "stock";		
	}
	
    /**
	 * stock mgmt page
	 */
	@tpl("plugin/pro/offer/stock.mtt")
	public function doDefault(){
		
		var products = company.getProducts();
		view.products = products;
		view.getStocks = PStockService.getStocks;
		var stockService = new pro.service.PStockService(company);
		
		if (checkToken()){
			
			for ( k in app.params.keys()){
				//stocks on offers
				if (k.substr(0, 3) == "off"){
					
					var v = if(app.params.get(k)=="") null else app.params.get(k).parseFloat();					
					var id = k.substr(3).parseInt();
					var o = pro.db.POffer.manager.get(id, true);
					o.stock = v;
					o.update();

					stockService.updateStockInGroups(o);
				}

				//stocks on products
				/*if (k.substr(0, 4) == "prod"){
					
					var v = if(app.params.get(k)=="") null else Std.parseFloat(app.params.get(k));					
					var id = Std.parseInt(k.substr(4));
					var p = pro.db.PProduct.manager.get(id, true);
					p.stock = v;
					p.update();

					pro.service.PStockService.updateStockInGroupsByProduct(p);
				}*/
				
			}
			throw Ok("/p/pro/stock", "Stocks mis à jour");
		}
	}
	
}