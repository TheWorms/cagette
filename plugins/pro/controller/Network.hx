package pro.controller;
import sugoi.form.elements.RadioGroup;
import sugoi.form.elements.CheckboxGroup;
import mangopay.db.MangopayGroupPayOut;
import datetime.DateTime;
using tools.ObjectListTool;
using tools.DateTool;


class Network extends controller.Controller
{

	var company : pro.db.CagettePro;
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.nav = ["network"];		
	}
	
	@tpl('plugin/pro/network/default.mtt')
	function doDefault() {

		var form = new sugoi.form.Form("stats");
		// <input type="radio" class="" name="type" value="turnoverByVendors" checked="checked" /> C.A par producteurs<br/>
					// <input type="radio" class="" name="type" value="mpTurnoverByDistribution" /> C.A Mangopay par distribution<br/>		
		var data = [
			{label:"Statistiques globales", value :"stats"},
			{label:"C.A par producteurs", value :"turnoverByVendors"},
			{label:"C.A Mangopay par distribution", value :"mpTurnoverByDistribution"},
		];

		form.addElement(new sugoi.form.elements.RadioGroup("type","Type",data,data[0].value));

		var now = DateTime.now();	
		// last month timeframe
		var to = now.snap(Month(Down)).add(Day(-1));
		var from = to.snap(Month(Down));
		form.addElement( new form.CagetteDatePicker("startDate","Date de début", from.getDate() ) );
		form.addElement( new form.CagetteDatePicker("endDate","Date de fin", to.getDate() ) );
		
		if(form.isValid()){

			var startDate : Date = form.getValueOf("startDate");
			var endDate : Date = form.getValueOf("endDate");
			endDate = endDate.setHourMinute(23,59);

			switch(form.getValueOf("type")){
				case "turnoverByVendors":
					throw Redirect('/p/pro/network/turnoverByVendors/?startDate=${startDate}&endDate=${endDate}');
				case "mpTurnoverByDistribution" : 
					throw Redirect('/p/pro/network/mpTurnoverByDistribution/?startDate=${startDate}&endDate=${endDate}');
				case "stats" :
					throw Redirect('/p/pro/network/stats/?from=${startDate}&to=${endDate}');
				/*case "groups" : 
					throw Redirect('/p/pro/delivery/exportByGroups/?startDate=${args.startDate}&endDate=${args.endDate}');*/
				default :
					throw Error('/p/pro/delivery', "type d'export inconnu");
				
			}
		}

		view.form = form;
	}

	@tpl('plugin/pro/network/stats.mtt')
	function doStats(args:{from:Date,to:Date}){

		var startDate = args.from;
		var endDate   = args.to;
		
		var s = new pro.service.NetworkStatsService(pro.db.CagettePro.getCurrentCagettePro(),startDate,endDate);
		view.from = startDate;
		view.to = endDate;
		view.baskets = s.getBasketNumber();
		view.sales = s.getSalesAmount();
		view.memberships = s.getMembershipNumber();
		view.membershipsAmount = s.getMembershipAmount();
		view.productNumber = s.getProductNumber();
		view.memberNumber = s.getMembersNumber();
		view.activeMembershipWithOrderNumber = s.getActiveMembershipWithOrderNumber();
		view.activeMembershipMembers = s.getActiveMembershipMembers().length;		
		view.membersWithOrderNumber = s.getMembersWithOrderNumber();
		view.groups = s.getGroups();
	}

	

	@tpl('plugin/pro/form.mtt')
	function doAddGroup() {

		var form = new sugoi.form.Form("addGroup");
		var networkGroups = company.getNetworkGroups();
		var groups = app.user.getGroups();
		for( g in groups.copy()){
			if( networkGroups.find(ng -> return ng.id==g.id) != null ){
				groups.remove(g);
			}
		}
		var data = groups.map(g -> return {label:g.name,value:g.id});
		form.addElement( new sugoi.form.elements.IntSelect("group","Groupe",data) );

		if(form.isValid()){

			var networkGroupIds = company.getNetworkGroupIds();
			networkGroupIds.push(form.getValueOf("group"));
			company.setNetworkGroupIds( networkGroupIds );
			throw Ok("/p/pro/network","Groupe ajouté");
		}

		view.form = form;
	}

	function doRemoveGroup(group:db.Group) {

		var networkGroupIds = company.getNetworkGroupIds();
		networkGroupIds.remove(group.id);
		company.setNetworkGroupIds( networkGroupIds );
		throw Ok("/p/pro/network","Groupe retiré");
	}
	
	/**
	 * export turnover by vendors in all groups
	 */
	@tpl('plugin/pro/network/turnover.mtt') 
	public function doTurnoverByVendors(args:{startDate:Date, endDate:Date}){		
				
		try{

			if(company.getNetworkGroups().length==0){
				//get group list
				var groups = [];
				for ( c in company.getCatalogs() ){
					for ( rc in connector.db.RemoteCatalog.getFromCatalog(c) ){
						groups.push( rc.getContract().group );
					}	
				}
				groups = groups.deduplicate();
				company.setNetworkGroupIds(groups.getIds());
			}

			var turnover = pro.service.ProReportService.getTurnoverByVendors({	groups:company.getNetworkGroups(),
																				startDate:args.startDate,
																				endDate:args.endDate
																			}, app.params.exists("csv"));

			if (!app.params.exists("csv")){
				view.turnover = turnover;
				view.startDate = args.startDate;
				view.endDate = args.endDate;
			}


		}catch (e:tink.core.Error){
			throw Error('/p/pro/network', e.message);
		}
	}

	@tpl('plugin/pro/network/mpTurnoverByDistribution.mtt') 
	public function doMpTurnoverByDistribution(args:{startDate:Date, endDate:Date}){		
				
		try{
			var mds = [];
			for( group in company.getNetworkGroups()){
				for(md in  db.MultiDistrib.getFromTimeRange(group,args.startDate,args.endDate)){
					mds.push(md);
				}
			}
			
			mds.sort(function(a,b){
				return Math.round( a.getDate().getTime()/1000 ) - Math.round( b.getDate().getTime()/1000 );
			});

			view.multidistribs = mds;
			view.getMangopayGroupPayout = function(md:db.MultiDistrib){
				//return mangopay.db.MangopayGroupPayOut.get(md);
				return MangopayGroupPayOut.manager.search($multiDistrib == md);
			}

			view.getMangopayECTotal = mangopay.MangopayPlugin.getMultidistribNetTurnover; 
			view.startDate = args.startDate;
			view.endDate = args.endDate;
			


		}catch (e:tink.core.Error){
			throw Error('/p/pro/network', e.message);
		}
	}
	
	
	
}