package pro.controller;

class Signup extends controller.Controller
{
	public function doDefault(){
		throw Redirect("/p/pro/signup/discovery");
	}

	@tpl('plugin/pro/signup/discovery.mtt')
	public function doDiscovery(?group:db.Group, ?invitationSender:db.User){
		if (group!=null) {
			view.groupName = group.name;
			view.groupId = group.id;
		}
		
		if(app.user==null) {
			view.userName = "";
			view.sid = App.current.session.sid;
			return;
		}
		
		//checks
		//has access to a cpro
		var uc = pro.db.PUserCompany.manager.search($user ==app.user);
		if( uc.length>0){
			if (uc.find( c -> c.company.vendor.isTest==true) == null) {
				throw Error("/","Vous avez déjà accès à un compte Producteur : "+uc.map(c -> return c.company.vendor.name).join(', ')+"</b>. Contactez le support sur <a href='mailto:support@cagette.net'>support@cagette.net</a> pour clarifier votre situation.");
			}
		}

		//has same mail than a vendor
		var vendor : db.Vendor = db.Vendor.manager.select($email != null && ($email == app.user.email || $email == app.user.email2),true);
		if( vendor!=null ){
			//is this vendor cpro (but not cpro test)
			if(vendor.getCpro()!=null && vendor.isTest==false){
				throw Error("/","Vous avez déjà accès à un compte Producteur");
			}
			view.vendorId = vendor.id;
		}
		
		view.userName = app.user.getName();
		
		if (invitationSender!=null) {
			view.invitationSenderId = invitationSender.id;
		}
	}
	
}