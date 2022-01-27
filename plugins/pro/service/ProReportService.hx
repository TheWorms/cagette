package pro.service;
import Common;
import tink.core.Error;
import service.OrderService;
import service.ProductService;
using tools.ObjectListTool;

typedef OrdersExportOptions = {
	?distribution:db.Distribution,
	?startDate:Date,
	?endDate:Date,
	?allCatalogs:pro.db.CagettePro,
	?groups:Array<db.Group>,
}

class ProReportService{

	/**
		Network report : Get turnover by vendors **in all company groups**.
	**/
	public static function getTurnoverByVendors( options:OrdersExportOptions, ?csv = false) 
	{
		var exportName = "";
		// vendorEmail -> turnover
		var out = new Map<String,{vendorName:String,turnoverHT:Float,turnoverTTC:Float}>();
		
		//options
		if (options.distribution != null){
			
			throw "not available";
			
		}else if(options.startDate!=null && options.endDate!=null && options.groups!=null){
			
			exportName = "CA Producteurs du " + options.startDate.toString().substr(0, 10)+" au " + options.endDate.toString().substr(0, 10);

			//active contracts
			var contracts = [];
			for( g in options.groups){
				for( c in db.Catalog.getActiveContracts(g,true)){
					contracts.push(c);
				}
			}

			//distribs
			var distribs = db.Distribution.manager.search($date >= options.startDate && $date <= options.endDate && ($catalogId in contracts.getIds()), false);
			if (distribs.length == 0) throw new Error("Aucune distribution sur cette periode");
			//for( d in distribs) scopedDistributions.add(d);
			//where += ' and up.distributionId IN ('+distribs.getIds().join(',')+')';*/
			
			for (d in distribs){
				
				var vid = d.catalog.vendor.name;
				var o = out.get(vid);
				
				var orders = service.ReportService.getOrdersByProduct( d );
				var totals = service.ReportService.getTurnoverFromOrdersByProducts(orders);

				if (o == null){
					out.set( vid, {
						vendorName : d.catalog.vendor.name,
						turnoverHT : totals.turnoverHT,
						turnoverTTC: totals.turnoverTTC
					});	
				}else{
					
					//add orders with existing ones
					o.turnoverHT += totals.turnoverHT;
					o.turnoverTTC += totals.turnoverTTC;

					out.set(vid, o);
				}
			}
			
		}

		if (csv) {
			var view = App.current.view;
			var data = new Array<Dynamic>();			
			for (o in out) {
				data.push({
					"vendorName" : o.vendorName,
					"turnoverHT" : view.formatNum(o.turnoverHT),
					"turnoverTTC": view.formatNum(o.turnoverTTC),					
				});				
			}
			sugoi.tools.Csv.printCsvDataFromObjects(data, ["vendorName", "turnoverHT","turnoverTTC"], exportName);
			return null;
		}else{
			return out;		
		}
	}

	/**
	 * Get orders grouped by products.
	 *  - from a time range
	 *  - from a specific distribution
	 */
	public static function getOrdersByProduct( options:OrdersExportOptions, ?csv = false) : {orders:Array<OrderByProduct>,distribs:Array<db.Distribution>}
	{
		var view = App.current.view;
		
		var where = "";
		var exportName = "";
		var scopedDistributions = [];

		//Check params integrity
		if(options.distribution==null && options.startDate==null) throw "wrong params";
		
		//options
		if (options.distribution != null){

			//use the regular function
			var out = {orders:[],distribs:[]};
			out.orders = service.ReportService.getOrdersByProduct(options.distribution);
			out.distribs = [options.distribution];
			return out;
			
		}else if(options.startDate!=null && options.endDate!=null && options.allCatalogs!=null){
			
			exportName = "Commandes du " + options.startDate.toString().substr(0, 10)+" au " + options.endDate.toString().substr(0, 10);
			
			//by dates
			//get catalogs
			var catalogs = options.allCatalogs.getCatalogs();			
			var remoteContracts = [];
			for ( c in catalogs){
				for ( rc in connector.db.RemoteCatalog.getFromCatalog(c) ){
					remoteContracts.push( rc.getContract() );
				}	
			}
			
			var distribs = db.Distribution.manager.search($date >= options.startDate && $date <= options.endDate && ($catalogId in remoteContracts.getIds()), false);
			if (distribs.length == 0) throw new Error("Aucune distribution sur cette periode");
			for( d in distribs) scopedDistributions.push(d);
			where += ' and uo.distributionId IN ('+distribs.getIds().join(',')+')';
		}
	

		//Product price will be an average if price changed
		var	sql = 'select 
			SUM(quantity) as quantity,	
			MAX(p.id) as pid,
			p.name as pname,
			AVG(uo.productPrice) as price,
			AVG(p.vat) as vat,
			p.ref as ref,
			SUM(quantity*uo.productPrice) as totalTTC
			from UserOrder uo, Product p 
			where uo.productId = p.id 
			$where
			group by ref,pname,price 
			order by pname asc; ';

		var res = sys.db.Manager.cnx.request(sql).results();			
		var orders = [];
		
		//populate with full product names
		for ( r in res){
					
			var o : OrderByProduct = {
				quantity	: 1.0 * r.quantity,
				smartQt		: "",
				pid			: r.pid,
				pname		: r.pname,
				ref			: r.ref,
				priceHT		: ProductService.getHTPrice(r.price,r.vat),
				priceTTC	: r.price,
				vat			: r.vat,
				totalTTC 	: r.totalTTC,
				totalHT  	: ProductService.getHTPrice( r.totalTTC ,r.vat),
				weightOrVolume:"",
			};
			
			//smartQt
			var p = db.Product.manager.get(r.pid, false);	
			if( OrderService.canHaveFloatQt(p) ){
				o.smartQt = view.smartQt(o.quantity, p.qt, p.unitType);
			}else{
				o.smartQt = Std.string(o.quantity);
			}
			o.weightOrVolume = view.smartQt(o.quantity, p.qt, p.unitType);
			
			if ( /*p.hasFloatQt || p.variablePrice ||*/p.qt==0 || p.qt==null || p.unitType==null){
				o.pname = p.name;	
			}else{
				o.pname = p.name + " " + view.formatNum(p.qt) +" " + view.unit(p.unitType, o.quantity > 1);					
			}
			
			//special case : if product is multiweight, we should count the records number ( and not SUM quantities )
			if (p.multiWeight){
				sql = 'select 
				COUNT(uo.id) as quantity 
				from UserOrder uo, Product p 
				where uo.productId = p.id and uo.quantity > 0 and p.id=${p.id}
				$where';
				var count = sys.db.Manager.cnx.request(sql).getIntResult(0);					
				o.smartQt = ""+count;
			}			
			
			orders.push(o);
		}
		
		if (csv) {
			var data = new Array<Dynamic>();			
			for (o in orders) {
				data.push({
					quantity	: view.formatNum(o.quantity),
					pname		: o.pname,
					ref			: o.ref,
					priceHT		: view.formatNum(o.priceHT),
					priceTTC	: view.formatNum(o.priceTTC),
					VATRate		: view.formatNum(o.vat),
					VATAmount	: view.formatNum(o.priceTTC - o.priceHT),
					totalHT		: view.formatNum(o.totalHT),					
					totalTTC	: view.formatNum(o.totalTTC),
				});				
			}

			sugoi.tools.Csv.printCsvDataFromObjects(
				data,
				["quantity", "pname","ref", "priceHT","priceTTC","VATAmount","VATRate","totalHT","totalTTC"],
				"Export-"+exportName+"-par produits"
			);
			return null;
		}else{
			return {orders:orders,distribs:scopedDistributions};		
		}
	}
	
	
	/**
	 * Export by members + group name, in a timeframe
	 */
	public static function getOrdersDetails( options:OrdersExportOptions, ?csv = false):{orders:Array<UserOrder>,distribs:List<db.Distribution>}{
		var view = App.current.view;
		var exportName = "";
		var scopedDistributions = Lambda.list([]);
		
		//options
		if (options.distribution != null){
			
			//by distrib
			//var d = options.distribution;
			//scopedDistributions = Lambda.list([d]);
			//exportName = d.contract.amap.name+" - Distribution "+d.contract.name+" du " + d.date.toString().substr(0, 10);
			//where += ' and p.contractId = ${d.contract.id}';
			//if (d.contract.type == db.Catalog.TYPE_VARORDER ) {
				//where += ' and up.distributionId = ${d.id}';
			//}
			throw "not implemented";
			
		}else if(options.startDate!=null && options.endDate!=null && options.allCatalogs!=null){
			
			exportName = "Commandes du " + options.startDate.toString().substr(0, 10)+" au " + options.endDate.toString().substr(0, 10);
			
			//by dates
			//get catalogs
			var catalogs = options.allCatalogs.getCatalogs();			
			var remoteContracts = [];
			for ( c in catalogs){
				for ( rc in connector.db.RemoteCatalog.getFromCatalog(c) ){
					remoteContracts.push( rc.getContract() );
				}	
			}
			
			scopedDistributions = db.Distribution.manager.search($date >= options.startDate && $date <= options.endDate && ($catalogId in remoteContracts.getIds()), false);
			if (scopedDistributions.length == 0) throw new Error("Aucune distribution sur cette periode");

		}
		
		var orders = [];
		var csvData = [];
		
		for ( d in scopedDistributions){
			var or = Lambda.array(service.OrderService.getOrders(d.catalog, d));
			
			if(csv){
				for ( o in or ){
					
					var u = db.User.manager.get(o.userId, false);
					var p = o.product;
					
					csvData.push({
						orderId		: o.id,
						user		: o.userName,
						userId	 	: o.userId,
						userEmail	: o.userEmail,
						contractName: o.catalogName,
						quantity	: view.formatNum(o.quantity),
						ref			: o.productRef,
						pname 		: o.productName,
						priceTTC	: view.formatNum(o.productPrice),
						priceHT		: view.formatNum(ProductService.getHTPrice(o.productPrice,p.vat)),
						VATRate		: view.formatNum(p.vat),
						VATAmount	: view.formatNum(o.productPrice - ProductService.getHTPrice(o.productPrice,p.vat)),
						
						fees 		: view.formatNum(o.fees),
						total		: view.formatNum(o.total),
						paid		: o.paid,
						
						//user infos
						address 	: u.address1 + (u.address2 != null?u.address2:""),
						zipCode 	: u.zipCode,
						city 		: u.city,
						
						//group and delivery
						deliveryDate : d.date.toString().substr(0, 10),
						place		 : d.place.name,
						group		 : d.catalog.group.name,
						groupId		 : d.catalog.group.id,
					});		
				}
			}else{				
				orders = orders.concat( or );
			}
		}
		
		if (csv) {			
			sugoi.tools.Csv.printCsvDataFromObjects(
				csvData ,
				["orderId","user","userId","userEmail","contractName","quantity", "ref","pname","priceHT","priceTTC","VATAmount","VATRate","fees", "paid","total","address","zipCode","city","deliveryDate","place","group","groupId"], exportName+" - Détail par adhérents"
			);
			return null;
		}else{
			orders = service.OrderService.sort(tools.ObjectListTool.deduplicateOrders(orders));
			return {orders:orders,distribs:scopedDistributions};		
		}
	}
	


}