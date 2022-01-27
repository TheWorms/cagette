package hosted.controller;

import db.Operation.COrderInfos;
import tools.ObjectListTool;
import pro.db.PUserCompany;

class User extends sugoi.BaseController
{
    @admin @tpl("plugin/pro/hosted/user/default.mtt")
	public function doDefault(){

    }
	
	/**
	 *  search fo a user in the whole database
	 */
	@admin @tpl("plugin/pro/hosted/user/search.mtt")
	public function doSearch(args:{search:String}){
		
		var search = "%"+StringTools.trim(args.search)+"%";
		var users = db.User.manager.search( 
					($lastName.like(search) ||
					$lastName2.like(search) || 
					$email.like(search) ||
					$email2.like(search) ||
					$firstName.like(search) ||
					$firstName2.like(search)					
					), { orderBy:-id }, false);
		view.users = users;

	}

    /**
	 *  Display infos about a user
	 */
	@admin @tpl("plugin/pro/hosted/user/view.mtt")
	public function doView(u:db.User,?args:{?delete:Bool}){
		view.member = u;
		view.orders = db.UserOrder.manager.count($user==u || $user2==u);
		view.mangopayUserId = mangopay.db.MangopayUser.get(u);

		//vendors
		var vendors = [];
		for( uv in PUserCompany.manager.search($user ==u,false)){
			vendors.push(uv.company.vendor);
		}
		view.vendors = ObjectListTool.deduplicate(vendors);

		//delete ?		
		if(checkToken() && args!=null && args.delete){
			var msg  = "";
			var johnDoe = db.User.manager.select($email=="deleted@cagette.net",false);

			//replace orders.
			for( uo in db.UserOrder.manager.search($user==u)){
				uo.user=johnDoe;
				uo.update();
				msg += uo.toString()+"\n";
			}
			for( uo in db.UserOrder.manager.search($user2==u)){
				uo.user2=johnDoe;
				uo.update();
				msg += uo.toString()+"\n";
			}
			//replace contacts
			for( c in db.Catalog.manager.search($contact==u)){
				c.contact = johnDoe;
				c.update();
				msg += "Removed contact of contract "+c.name+"\n";
			}

			for( c in db.Group.manager.search($contact==u)){
				c.contact = johnDoe;
				c.update();
				msg += "Removed contact of group "+c.name+"\n";
			}

			for( b in db.Basket.manager.search($user==u,true)){
				b.user = johnDoe;
				b.update();
			}

			for(op in db.Operation.manager.search($user==u,true)){
				if(op.amount==0){
					op.delete();
				}else{
					op.user = johnDoe;
					op.update();
				}
				
			}

			var name = u.getName();
			u.delete();
			throw Ok("/p/hosted",name+" a été effacé.<br/>"+msg.split("\n").join("<br/>"));

		}
	}
	
    /**
		extract group admins and coordinators
	**/
	@admin @tpl("plugin/pro/hosted/people.mtt")
	function doPeople(?type:String,?includeContractManagers:Bool) {

		var users = [];
		for ( g in db.Group.manager.all()) {
		
			var h = hosted.db.GroupStats.getOrCreate(g.id);
			if(!h.active) continue;

			if(type=="AMAP"){
				if(g.hasShopMode()) continue;
			}

			if (g.contact != null) {
				users.push(g.contact);
			}
			
			if(includeContractManagers){
				for ( c in g.getActiveContracts()) {
					if(c.contact!=null) users.push( c.contact );
				}
			}
			
		}
		view.users = users;
		
		if (app.params.exists("csv")) {
			sugoi.tools.Csv.printCsvDataFromObjects(users, ["email", "firstName", "lastName",/* "CLIENT",*/"zipCode","city"], "Clients-cagette");
		}
	}
}