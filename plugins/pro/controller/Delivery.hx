package pro.controller;
import form.CagetteForm;
import sugoi.form.elements.*;
import sugoi.form.elements.NativeDatePicker.NativeDatePickerType;
using Std;
using tools.DateTool;
import datetime.DateTime;
using tools.ObjectListTool;

class Delivery extends controller.Controller
{

	var company : pro.db.CagettePro;
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.nav = ["delivery"];
	}
	
	@tpl('plugin/pro/delivery/default.mtt')
	public function doDefault(){

		if(!company.captiveGroups) throw Redirect("/p/pro/sales");
		
		var remoteCatalogs = connector.db.RemoteCatalog.manager.search($remoteCatalogId in Lambda.map(company.getCatalogs(), function(x) return x.id),false); 
		
		var cids = Lambda.map(remoteCatalogs, function(r) return r.id);
		var now = Date.now();
		var today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
		var sixMonth = DateTool.deltaDays(Date.now(), Math.round(30.5 * 6));
		var distribs = db.Distribution.manager.search( ($catalogId in cids) && ($date >= today) && ($date <= sixMonth) , {orderBy:date}, false);
		view.distribs = distribs.groupDistributionsByGroupAndDay();
		
		view.getCatalog = function(d:db.Distribution){			
			var rc = connector.db.RemoteCatalog.getFromContract(d.catalog);
			return rc.getCatalog();			
		};

		if(company.captiveGroups){
			var groupIds = company.getClients().getIds();
			view.cycles = db.DistributionCycle.manager.search( ($groupId in groupIds) && $endDate > Date.now(), false);
		}

		//export form		
		var form = new sugoi.form.Form("exportCpro");
		var data = [
			{label:"Par produits", value :"products"},
			{label:"Par membres", value :"members"},
			{label:"Par Groupe-produits (CSV)", value :"groups"},
		];
		form.addElement(new sugoi.form.elements.RadioGroup("type","Type",data,data[0].value));
		var now = DateTime.now();	
		// last month timeframe
		var from = now.snap(Week(Down,Monday));
		var to = now.snap(Week(Up,Sunday));
		form.addElement( new form.CagetteDatePicker("startDate","Du", from.getDate() ) );
		form.addElement( new form.CagetteDatePicker("endDate","au", to.getDate() ) );
		if(form.isValid()){

			var startDate:Date = form.getValueOf("startDate");
			var endDate:Date = form.getValueOf("endDate");
			endDate = new Date(endDate.getFullYear(),endDate.getMonth(),endDate.getDate(),23,59,0);
			switch(form.getValueOf("type")){
				case "products":
					throw Redirect('/p/pro/delivery/exportByProducts/?startDate=${startDate}&endDate=${endDate}');
				case "members" : 
					throw Redirect('/p/pro/delivery/exportByMembers/?startDate=${startDate}&endDate=${endDate}');
				case "groups" : 
					throw Redirect('/p/pro/delivery/exportByGroups/?startDate=${startDate}&endDate=${endDate}');
				default :
					throw Error('/p/pro/delivery', "type d'export inconnu");
				
			}
		}
		
		view.form = form;

		checkToken();

	}

	/**
	 *  Delete a distribution cycle
	 */
	public function doDeleteCycle(cycle:db.DistributionCycle){
		
		if(checkToken()){			
			var messages = service.DistributionService.deleteDistribCycle(cycle);
			if (messages.length > 0){			
				App.current.session.addMessage( messages.join("<br/>"),true);	
			}			
			throw Ok("/p/pro/delivery", t._("Recurrent deliveries deleted"));
		}
	}
	
	/**
	 * general entry point to various order exports
	 */
	/*public function doExport(args:{startDate:Date, endDate:Date, type:String }){
		
		switch(args.type){
			case "products":
				throw Redirect('/p/pro/delivery/exportByProducts/?startDate=${args.startDate}&endDate=${args.endDate}');
			case "members" : 
				throw Redirect('/p/pro/delivery/exportByMembers/?startDate=${args.startDate}&endDate=${args.endDate}');
			case "groups" : 
				throw Redirect('/p/pro/delivery/exportByGroups/?startDate=${args.startDate}&endDate=${args.endDate}');
			default :
				throw Error('/p/pro/delivery', "type d'export inconnu");
			
		}
	}*/
	
	/**
	 * export by products
	 */
	@tpl('plugin/pro/delivery/exportByProducts.mtt')
	public function doExportByProducts(args:{startDate:Date, endDate:Date}){		
				
		try{
			var orders = pro.service.ProReportService.getOrdersByProduct({allCatalogs:company, startDate:args.startDate, endDate:args.endDate}, app.params.exists("csv"));
			if (!app.params.exists("csv")){
				view.orders = orders.orders;
				view.distributions = orders.distribs;
				view.options = args;	
			}
		}catch (e:tink.core.Error){
			throw Error('/p/pro/delivery', e.message);
		}
	}
	
	/**
	 * Export by members + group name, in a timeframe
	 */
	@tpl('plugin/pro/delivery/exportByMembers.mtt')
	public function doExportByMembers(args:{startDate:Date, endDate:Date}){		
		
		try{
			var orders = pro.service.ProReportService.getOrdersDetails({allCatalogs:company, startDate:args.startDate, endDate:args.endDate}, app.params.exists("csv"));
			if (!app.params.exists("csv")){
				view.orders = orders.orders;
				view.distributions = orders.distribs;
				view.options = args;	
			}
		}catch (e:tink.core.Error){
			throw Error('/p/pro/delivery', e.message);
		}
	}

	/**
	 * special corto
	 * totaux par produits par groupe.
	 */
	public function doExportByGroups(args:{startDate:Date, endDate:Date}){		
		
		var exportName = "Totaux par produits du " + args.startDate.toString().substr(0, 10)+" au " + args.endDate.toString().substr(0, 10);
		
		//get rcs
		var catalogs = company.getCatalogs();			
		var remoteContracts = [];
		for ( c in catalogs){
			for ( rc in connector.db.RemoteCatalog.getFromCatalog(c) ){
				remoteContracts.push( rc.getContract() );
			}	
		}
		
		var distribs = db.Distribution.manager.search($date >= args.startDate && $date <= args.endDate && ($catalogId in remoteContracts.getIds()), false);
		if (distribs.length == 0) throw "Aucune distribution sur cette periode";
		
		//DEBUG
		//throw distribs.getIds(); 
		
		var orders = [];
		for ( d in distribs) orders.push({d:d,products:service.ReportService.getOrdersByProduct(d, false)});
		
		//CSV
		var datas = [];
		for ( o in orders){
			//datas.push(["-----"]);
			//datas.push([o.d.contract.amap.name]);
			//datas.push(["Distribution du ",o.d.date.toString()]);
			for ( x in o.products ){				
				datas.push([o.d.catalog.group.name,view.formatNum(x.quantity),x.ref,x.pname,view.formatNum(x.totalTTC)]);
			}
		}
		
		sugoi.tools.Csv.printCsvDataFromStringArray(datas, ["groupe","qt","ref","produit","total"], exportName );
	}


	/**
	 * special corto/givrés
	 * totaux par produits par zone.
	 */
	public function doExportByZone(args:{startDate:Date, endDate:Date}){		
		
		var exportName = "Totaux par zone du " + args.startDate.toString().substr(0, 10)+" au " + args.endDate.toString().substr(0, 10);
		
		//get rcs
		var catalogs = company.getCatalogs();			
		var remoteContracts = [];
		for ( c in catalogs){
			for ( rc in connector.db.RemoteCatalog.getFromCatalog(c) ){
				remoteContracts.push( rc.getContract() );
			}	
		}
		
		var distribs = db.Distribution.manager.search($date >= args.startDate && $date <= args.endDate && ($catalogId in remoteContracts.getIds()), false);
		if (distribs.length == 0) throw "Aucune distribution sur cette periode";
		
		var orders = [];
		for ( d in distribs) {
			orders.push({
				d : d,
				products : service.ReportService.getOrdersByProduct(d, false)
			});
		}
		
		//aggregation
		var datas = new Map<String,Map<String,Common.OrderByProduct>>();  //<zoneId,<productRef,OrderByProduct>
		for ( o in orders){
			var zone = o.d.catalog.group.name.split("-")[0].toUpperCase();//SUD, LIL...etc
			var zoneOrders = datas.get(zone);
			if(zoneOrders==null) zoneOrders = new Map<String,Common.OrderByProduct>();

			for ( x in o.products ){	

				var orderByProduct 	= zoneOrders.get(x.ref);
				if(orderByProduct==null) {
					orderByProduct = {
						quantity:x.quantity,
						smartQt:null,
						pid:null,
						pname:x.pname,
						ref:x.ref,
						priceHT:x.priceHT,
						priceTTC:x.priceTTC,
						vat:x.vat,
						totalTTC:x.totalTTC,
						totalHT:x.totalHT,
						weightOrVolume:null,
					};
				}else{
					orderByProduct.quantity+=x.quantity;
					orderByProduct.totalTTC+=x.totalTTC;
					orderByProduct.totalHT+=x.totalHT;
				}
				zoneOrders.set(x.ref,orderByProduct);
			}
			datas.set(zone,zoneOrders);
		}

		var csvDatas = [];
		for( zone in datas.keys()){
			for( order in datas.get(zone)){
				csvDatas.push([zone,view.formatNum(order.quantity),order.ref,order.pname,view.formatNum(order.totalTTC)]);
			}
		}
		
		sugoi.tools.Csv.printCsvDataFromStringArray(csvDatas, ["zone","qt","ref","produit","totalTTC"], exportName );
	}

	function doExportCorto(){
		doExportAdherents();
	}

	/**
	 * Fonction cachée corto : Exporte tout les membres de chaque groupe.
	 */
	function doExportMembers(){
		doExportAdherents();
	}

	function doExportAdherents(){

		var authorizedCompanies = [3,4,323]; //agapes + corto + givrés
		var company = pro.db.CagettePro.getCurrentCagettePro();
		if( !app.user.isAdmin() && !Lambda.has(authorizedCompanies,company.id)) throw "Accès interdit";
		var headers =  ["groupId","group","firstName", "lastName", "email", "phone", "firstName2", "lastName2", "email2", "phone2", "address1", "address2", "zipCode", "city","ldate"];
		var data = [];
		for ( g in company.getClients() ){
					
			//data.push({firstName:"GROUPE : ",lastName:g.name} );
			// if(g.contact!=null) data.push({firstName:"COORDINATEUR : ",lastName:g.contact.getName()});
			
			for ( member in g.getMembers()){
				var m :Dynamic = {};
				//anonymous object
				for ( h in headers){
					var v = Reflect.getProperty(member,h);
					Reflect.setField(m,h,v);
				}

				Reflect.setField(m, "group", g.name);
				Reflect.setField(m, "groupId", g.id);
				data.push(m);
			}
		}
				
		sugoi.tools.Csv.printCsvDataFromObjects(data, headers, "adherents");
	}
	
	@tpl('plugin/pro/delivery/view.mtt')
	public function doView(d:db.Distribution){
		
		checkToken();
		
		//var orders = pro.service.ProReportService.getOrdersByProduct({distribution:d}, app.params.exists("csv"));
		var orders = service.ReportService.getOrdersByProduct(d, app.params.exists("csv"));
		
		if (!app.params.exists("csv")){
			view.nav.push("view");
			view.distribution = d;
			var contract = d.catalog;
			view.c = contract;
			view.orders = orders;	
		}
	}

	/**
	 * Edit a distribution
	 */
	@tpl("plugin/pro/form.mtt")
	function doEdit(d:db.Distribution) {
		var contract = d.catalog;
		
		var form = CagetteForm.fromSpod(d);
		form.removeElement(form.getElement("contractId"));
		form.removeElement(form.getElement("end"));
		form.removeElement(form.getElement("distributionCycleId"));
		var x = new form.CagetteDatePicker("end", t._("End time"), d.end, NativeDatePickerType.time, true);
		form.addElement(x, 3);
		
		if (d.catalog.type == db.Catalog.TYPE_VARORDER ) {
			form.addElement(new form.CagetteDatePicker("orderStartDate", t._("Orders opening date"), d.orderStartDate));	
			form.addElement(new form.CagetteDatePicker("orderEndDate", t._("Orders closing date"), d.orderEndDate));
		}		
		
		if (form.isValid()) {

			var orderStartDate = null;
			var orderEndDate = null;

			try{

				if (d.catalog.type == db.Catalog.TYPE_VARORDER ) {
					orderStartDate = form.getValueOf("orderStartDate");
					orderEndDate = form.getValueOf("orderEndDate");
				}

				d = service.DistributionService.edit(
					d,
					form.getValueOf("date"),
					form.getValueOf("end"),
					form.getValueOf("placeId"),
					orderStartDate,
					orderEndDate,
					false
				);

			}
			catch(e:tink.core.Error){
				throw Error("/p/pro/delivery/view/" + d.id, e.message);
			}
			
			throw Ok('/p/pro/delivery/view/'+ d.id, t._("The distribution has been recorded") );
			
		}
		
		view.form = form;
		view.title = t._("Edit a distribution");
	}
	
	/**
	 * create multiple deliveries at once
	 */
	@tpl("plugin/pro/delivery/insert.mtt")
	function doInsert(){
		
		var form = new sugoi.form.Form("deliv");

		//distribution date
		var el = new form.CagetteDatePicker("date", "Date de distribution",DateTool.now().deltaDays(21).setHourMinute(19, 0));
		form.addElement(el);

		//start hour
		var x = new form.CagetteTimePicker("startHour", "Heure de début", DateTool.now().setHourMinute( 19, 0) , true);
		form.addElement(x);
		
		//end hour
		var x = new form.CagetteTimePicker("endHour", "Heure de fin", DateTool.now().setHourMinute(20, 0), true);
		form.addElement(x);

		form.addElement(new form.CagetteDateTimePicker("orderStartDate", "Ouverture des commandes",DateTool.now().deltaDays(10).setHourMinute(8, 0)));	
		form.addElement(new form.CagetteDateTimePicker("orderEndDate", "Fermeture des commandes"  ,DateTool.now().deltaDays(20).setHourMinute(23, 59)));
		
		//submit button needed, because form.render() is not called
		form.submitButton = new sugoi.form.elements.Submit('submit', 'Créer la distribution');
		form.submitButton.parentForm = form;
		
		var contracts = [];
		for ( c in company.getCatalogs()){
			for ( r in connector.db.RemoteCatalog.getFromCatalog(c)){
				contracts.push({contract:r.getContract(),catalog:c});
			}
		}
		
		//sort by catalog + group name
		contracts.sort(function(b, a) {
			return (a.catalog.name+a.contract.group.name.toUpperCase() < b.catalog.name+b.contract.group.name.toUpperCase())?1:-1;
		});
		
		if (form.isValid()){
			if (sugoi.Web.getParamValues("client") == null){
				throw Error("/p/pro/delivery/insert", "Vous devez sélectionner un catalogue");
			}
			
			var cids : Array<Int> = sugoi.Web.getParamValues("client").map(Std.parseInt);

			var distribDate:Date = form.getValueOf("date");
			var startHour:Date = form.getValueOf("startHour");
			var endHour:Date = form.getValueOf("endHour");
			distribDate = distribDate.setHourMinute(startHour.getHours(), startHour.getMinutes());
			var endDate = distribDate.setHourMinute(endHour.getHours(),endHour.getMinutes());

			try{
				for ( id in cids ){
					var contract = db.Catalog.manager.get(id, false);
					if(contract.group.getMainPlace()==null) throw new tink.core.Error(500,'Il n\'y a aucun lieu de livraison défini pour le groupe "${contract.group.name}"');

					service.DistributionService.create(
						contract,
						distribDate,endDate,
						contract.group.getMainPlace().id,
						form.getValueOf("orderStartDate"),form.getValueOf("orderEndDate"),false
					);
				}
			}
			catch(e:tink.core.Error){
				throw Error("/p/pro/delivery/insert", e.message);
			}

			throw Ok("/p/pro/delivery", "Vous venez de créer " + cids.length + " distributions");
		}
		
		view.form = form;
		view.contracts = contracts;
		view.title = "Créer une distribution ponctuelle";
	}
	
	/**
	 * create multiple deliveries at once
	 */
	@tpl("plugin/pro/delivery/insertCycle.mtt")
	function doInsertCycle(){
		
		var dc = new db.DistributionCycle();
		var form = CagetteForm.fromSpod(dc);
		form.removeElementByName("contractId");

		form.addElement(new sugoi.form.elements.Html("msg","Cette date définit le jour de la semaine pour toutes les distributions."));
		
		form.getElement("startDate").value = DateTool.now();
		form.getElement("endDate").value  = DateTool.now().deltaDays(30);
		
		//start hour
		form.removeElementByName("startHour");
		var x = new form.CagetteTimePicker("startHour", "Heure de début", DateTool.now().setHourMinute( 19, 0) , true);
		form.addElement(x, 5);
		
		//end hour
		form.removeElementByName("endHour");
		var x = new form.CagetteTimePicker("endHour", "Heure de fin", DateTool.now().setHourMinute(20, 0), true);
		form.addElement(x, 6);
		
		form.getElement("daysBeforeOrderStart").value = 10;
		form.getElement("daysBeforeOrderStart").required = true;
		form.removeElementByName("openingHour");
		var x = new form.CagetteTimePicker("openingHour", "Heure d'ouverture", DateTool.now().setHourMinute(8, 0) , true);
		form.addElement(x, 8);
		
		form.getElement("daysBeforeOrderEnd").value = 2;
		form.getElement("daysBeforeOrderEnd").required = true;
		form.removeElementByName("closingHour");
		var x = new form.CagetteTimePicker("closingHour", "Heure de fermeture", DateTool.now().setHourMinute(23, 55) , true);
		form.addElement(x, 10);
		
		form.removeElementByName("placeId");
		
		//submit button needed, because form.render() is not called
		form.submitButton = new sugoi.form.elements.Submit('submit', 'Créer les distributions');
		form.submitButton.parentForm = form;
		
		var contracts = [];
		for ( c in company.getCatalogs()){
			for ( r in connector.db.RemoteCatalog.getFromCatalog(c)){
				contracts.push({contract:r.getContract(),catalog:c});
			}
		}

		contracts.sort(function(b, a) {
			return (a.catalog.name+a.contract.group.name.toUpperCase() < b.catalog.name+b.contract.group.name.toUpperCase())?1:-1;
		});
		
		if (form.isValid()){
			if (sugoi.Web.getParamValues("client") == null){
				throw Error("/p/pro/delivery/insertCycle", "Vous devez sélectionner un catalogue");
			}
			var cids : Array<Int> = sugoi.Web.getParamValues("client").map(Std.parseInt);

			try {
				for ( cid in cids ){
					var contract = db.Catalog.manager.get(cid,false);
					if(contract.group.getMainPlace()==null) throw new tink.core.Error(500,'Il n\'y a aucun lieu de livraison défini pour le groupe "${contract.group.name}"');
					service.DistributionService.createCycle(
						contract.group,
						form.getElement("cycleType").getValue(),
						form.getValueOf("startDate"),	
						form.getValueOf("endDate"),	
						form.getValueOf("startHour"),
						form.getValueOf("endHour"),											
						form.getValueOf("daysBeforeOrderStart"),											
						form.getValueOf("daysBeforeOrderEnd"),											
						form.getValueOf("openingHour"),	
						form.getValueOf("closingHour"),																	
						contract.group.getMainPlace().id,
						[cid]
					);
				}
			}
			catch(e:tink.core.Error){
				throw Error("/p/pro/delivery/insertCycle", e.message);
			}
			
			throw Ok("/p/pro/delivery", "Distributions crées");
		}
		
		view.form = form;
		view.contracts = contracts;
		view.title = "Créer des distributions récurrentes chez plusieurs groupes";
		
	}

	
	
	/**
	 * delete a delivery
	 * @param	d
	 */
	function doDelete(d:db.Distribution) {
		
		//check
		var remoteCatalogs = connector.db.RemoteCatalog.manager.search($remoteCatalogId in Lambda.map(company.getCatalogs(), function(x) return x.id),false); 
		var cids = Lambda.map(remoteCatalogs, function(r) return r.id);
		if (!Lambda.has( db.Distribution.manager.search($catalogId in cids,false) , d)) throw "accès interdit";
		
		var distribId = d.id;
		try {
			if (checkToken()){
				service.DistributionService.cancelParticipation(d, false);
			}
		}
		catch(e:tink.core.Error){
			throw Error("/p/pro/delivery/view/" + distribId, e.message);
		}

		throw Ok("/p/pro/delivery/", "la distribution a bien été effacée");
	}
	
	@tpl("plugin/pro/delivery/orders.mtt")
	function doOrders(d:db.Distribution) {
		
		view.nav.push("detail");
		view.distribution = d;
		var contract = d.catalog;
		view.c = contract;
		view.orders = service.OrderService.getOrders(contract, d, app.params.exists("csv"));
	}
	

	@tpl('distribution/list.mtt')
	function doList(d:db.Distribution) {
		view.distrib = d;
		var contract = d.catalog;
		view.contract = d.catalog;
		view.orders = service.OrderService.getOrders(contract, d);
		view.volunteers = Lambda.filter(d.multiDistrib.getVolunteers(),function(v) return v.volunteerRole.catalog!=null && v.volunteerRole.catalog.id==d.catalog.id);		
	}
	
	/**
	 * "bon de commande"
	 */
	@tpl("contractadmin/ordersByProductList.mtt")
	function doOrdersByProductList(d:db.Distribution) {
		
		view.c = d.catalog;
		view.group = d.catalog.group;
		view.distribution = d;
		view.orders = service.ReportService.getOrdersByProduct(d,false);
	}
	
}