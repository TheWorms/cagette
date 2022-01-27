package pro;
import sugoi.ControllerAction;
import pro.db.VendorStats;
import sugoi.tools.TransactionWrappedTask;
import pro.service.PStockService;
import Common;
import sugoi.plugin.*;
using tools.DateTool;

class ProPlugIn extends PlugIn implements IPlugIn{

	public function new() {
		super();
		name = "pro";
		file = sugoi.tools.Macros.getFilePath();
		//suscribe to events
		App.current.eventDispatcher.add(onEvent);		
	}
	
	public function onEvent(e:Event) {
		
		switch(e) {
			case Nav(nav, name, id):
				
				if(name=="admin"){
					nav.push({id:"cpro",name:"Producteurs", link:"/admin/vendor",icon:"farmer"});
					nav.push({id:"cprodedup",name:"Déduplication Producteurs", link:"/p/pro/admin/deduplicate",icon:"farmer"});		
					nav.push({id:"siret",name:"Producteurs Siret", link:"/p/pro/admin/siret",icon:"farmer"});		
					nav.push({id:"certification",name:"Certification Producteurs", link:"/p/pro/admin/certification",icon:"farmer-pro"});		
				}

			case Permalink(p):
				if(p.entityType=="vendor"){

					var vendor = db.Vendor.manager.get(p.entityId,false);
					if(vendor==null) throw new tink.core.Error("Ce permalien n'est plus valide");
					if(vendor.isDisabled()) throw ControllerAction.ErrorAction("/","Ce producteur est désactivé. Raison : "+vendor.getDisabledReason());

					pro.controller.Public.vendorPage(vendor);
				}	

			case HourlyCron(now):
				//can send fake now date
				
				var task = new TransactionWrappedTask("Send orders by products to cpro accounts");
				task.setTask(function(){
					//Email product report when orders close				
					var range = tools.DateTool.getLastHourRange( now );
					task.log('Find all distributions that have closed in the last hour from >=${range.from} to <${range.to} \n');
					var distribs = db.Distribution.manager.search($orderEndDate >= range.from && $orderEndDate < range.to, false);

					for ( d in distribs){

						//We ignore all non cagette pro distribs
						var rc = connector.db.RemoteCatalog.getFromContract(d.catalog);					
						if(rc==null) {
							task.log(" -- not cpro : "+d.toString());
							continue;
						}
						
						var pcatalog = rc.getCatalog();						
						var distribService = new pro.service.PDistributionService(pcatalog.company);					
						distribService.sendOrdersByProductReport(d,rc);
						task.log(" -- Sent orders by product for : "+d.toString());
					}
				});
				task.execute(!App.config.DEBUG);

				//update vendor stats every hour
				var task = new TransactionWrappedTask("Refresh vendor stats");
				task.setTask(function (){	
					var count = VendorStats.manager.count(true);					
					//full sync take 3 days					
					var num = Math.ceil(count/(24*3));
					task.log('will update $num vendors on a total of $count');
					for ( vs in pro.db.VendorStats.manager.search(true,{limit:num,orderBy:ldate},true)){
						if(vs.vendor==null){
							vs.delete();
							continue;
						}
						task.log(" - "+vs.vendor.name);
						VendorStats.updateStats(vs.vendor);
					}
				});
				task.execute();

				

			case MinutelyCron(now):
				
				//Decrease stocks in cpro when distrib has been done	
				var task = new TransactionWrappedTask("Decrease stocks in cpro when distrib has been done");
				task.setTask(function (){
								
					var range = if(App.config.DEBUG) tools.DateTool.getLastHourRange() else tools.DateTool.getLastMinuteRange();
					task.log("Time is "+Date.now()+"<br/>");
					task.log('Find all distributions that took place in the last minute from ${range.from} to ${range.to} \n<br/>');
					
					for ( d in db.Distribution.manager.search($end >= range.from && $end < range.to, false)){
						if(d.catalog==null) continue;
						//We ignore all non cagette pro distribs
						var contract = d.catalog;
						var rc = connector.db.RemoteCatalog.getFromContract(contract);					
						if(rc==null) continue;
						
						PStockService.decreaseStocksOnDistribEnd(d,rc);
						
					}

				});
				task.execute();

				//Catalogs synchro
				if (Date.now().getMinutes() % 10 == 0 || (App.current.user!=null && App.current.user.isAdmin()) ){	
									
					var task = new TransactionWrappedTask("Cpro Catalogs sync");
					task.setTask(function (){
						var log = pro.service.PCatalogService.sync();
						for( l in log) task.log(l);
					});
					task.execute();
				}

				
			case DailyCron(now):

				

			case StockMove(e):
				//an order has been made or modified
				//get related offer in cpro
				var rc = connector.db.RemoteCatalog.getFromContract(e.product.catalog);
				if ( rc != null){
					var catalog = rc.getCatalog();
					if(catalog==null) return ;
					var offer = null;
					for ( off in catalog.getOffers() ){
						if (off.offer.ref == e.product.ref){
							offer = off.offer;
							break;
						}
					}
			
					if (offer != null){
						var stockService = new pro.service.PStockService(catalog.company);
						//update stock depending on stock strategy
						//if(offer.product.stockStrategy==pro.db.PProduct.ProductStockStrategy.ByOffer){
							stockService.updateStockInGroups(offer);	
						/*}else{
							pro.service.PStockService.updateStockInGroupsByProduct(offer.product);	
						}*/
						

					} 
				}

	

			default :
		}
	}
	

	
	
	/**
	 * synchronize stocks to Cagette Groups to avoid oders over available qt
	 * 
	 * @deprecated
	 
	public static function __syncStocks(){
		
		Sys.println("<h2>Synchro des stocks</h2>");
		
		for ( c in pro.db.Company.manager.all()){
			
			for ( o in c.getOffers()){
				if (!o.active || o.stock==null) continue;
				
				//total stock available to buy
				var availableStock = o.stock;
				
				//on déduit ce qui est commandé dans chaque groupe
				availableStock -= o.countCurrentUndeliveredOrders();
				
				if (o.products.length > 0){
					
					Sys.println('${o.getName()} a ${o.products.length} commandes en cours<br>');
					var stockToDispatch = tools.StockTool.dispatch(Math.floor(availableStock), o.products.length);
					Sys.println('stock dispo $availableStock réparti  sur $stockToDispatch<br><br>');
					
					for ( i in 0...o.products.length){
						var p = o.products[i];
						p.lock();
						p.stock = stockToDispatch[i];
						p.update();
						
						if (!p.contract.flags.has(db.Contract.ContractFlags.StockManagement)){
							p.contract.lock();
							p.contract.flags.set(db.Contract.ContractFlags.StockManagement);
							p.contract.update();
						}
					}
				
				}
			
				
				//quand une distrib est finie, il faudrait mettre à jour le stock cagette pro en déduisant la livraison
			}
			
		}
		
		
	}*/
	
	
	
	
}