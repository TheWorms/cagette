package pro.controller;
import form.CagetteForm;
import sugoi.form.elements.*;
using tools.DateTool;
using tools.ObjectListTool;
import datetime.DateTime;
import service.DistributionService;

class Sales extends controller.Controller
{

	var company : pro.db.CagettePro;
    var baseUrl : String;
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.nav = ["delivery"];
        baseUrl = "/p/pro/sales";
	}
	
	@tpl('plugin/pro/sales/default.mtt')
	public function doDefault(){

        if(company.captiveGroups) throw Redirect("/p/pro/delivery");
		
		var now = Date.now();
		var today = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
		var sixMonth = DateTool.deltaDays(Date.now(), Math.round(30.5 * 6));

        //get multidistribs 
        var distribs = [];
        for( group in company.getClients()){
            for( md in db.MultiDistrib.getFromTimeRange(group, today,sixMonth) ){
                distribs.push(md);
            }
        }
        //sort by date
        distribs.sort(function(a,b){
            return Math.round(a.distribStartDate.getTime()/1000) - Math.round(b.distribStartDate.getTime()/1000);
		});
		
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

        view.distribs = distribs;
        view.getFromGroup = connector.db.RemoteCatalog.getFromGroup;

		checkToken();

	}

    function doParticipate(md:db.MultiDistrib,contract:db.Catalog){
		try{
			service.DistributionService.participate(md,contract);
		}catch(e:tink.core.Error){
			throw Error(baseUrl,e.message);
		}		
		throw Ok(baseUrl,"Vous participez maintenant à la distribution du "+view.hDate(md.getDate()));
	}

    /**
		Delete a distribution
	**/
	function doDelete(d:db.Distribution) {
		
		try {
			service.DistributionService.cancelParticipation(d,false);
		} catch(e:tink.core.Error){
			throw Error(baseUrl, e.message);
		}		
		throw Ok(baseUrl, "Vous ne participez plus à la distribution du "+view.hDate(d.date) );
	}

    /**
		Edit order opening and closing dates
	 */
	@tpl('plugin/pro/sales/dates.mtt')
	function doEdit(d:db.Distribution) {
		
		var contract = d.catalog;
		
		if(d.catalog.isConstantOrders()) throw Error('/', "Impossible de changer les dates d'ouverture de commande pour un contrat AMAP" );	
		
		var form = CagetteForm.fromSpod(d);
		form.removeElementByName("placeId");
		form.removeElementByName("date");
		form.removeElementByName("end");
		form.removeElement(form.getElement("contractId"));		
		form.removeElement(form.getElement("distributionCycleId"));
		form.addElement(new form.CagetteDateTimePicker("orderStartDate", t._("Orders opening date"), d.orderStartDate));	
		form.addElement(new form.CagetteDateTimePicker("orderEndDate", t._("Orders closing date"), d.orderEndDate));
		
		if (form.isValid()) {

			var orderStartDate = null;
			var orderEndDate = null;
			try{

				orderStartDate = form.getValueOf("orderStartDate");
				orderEndDate = form.getValueOf("orderEndDate");

				//do not launch event, avoid notifs for now
				d = DistributionService.editAttendance(
					d,
					d.multiDistrib,
					orderStartDate,
					orderEndDate,
					false
				);							

			} catch(e:tink.core.Error){
				throw Error('/p/pro/sales' , e.message);
			}
			
			throw Ok('/p/pro/sales', "Votre participation à cette distribution a été mise à jour" );
			
		} else {
			app.event(PreEditDistrib(d));
		}
		
		view.form = form;
        view.distribution = d;
        var ua = db.UserGroup.get(app.user,d.catalog.group);
        view.groupAdmin = ua!=null && (ua.isGroupManager() || ua.canManageAllContracts());
		view.title = t._("Attendance of ::farmer:: to the ::date:: distribution",{farmer:d.catalog.vendor.name,date:view.dDate(d.date)});
	}
	
}