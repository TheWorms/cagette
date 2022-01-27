package pro.controller;
import sugoi.form.ListData;
import sugoi.form.validators.EmailValidator;
import sugoi.form.elements.*;
import sugoi.form.Form;
import db.UserGroup;

class Messages extends controller.Controller
{

	var company : pro.db.CagettePro;
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.category = "messages";
		view.nav = ["messages"];
	}
	
	@tpl("plugin/pro/messages/default.mtt")
	function doDefault() {
		
		var form = new Form("msg");		
		
		var senderName = company.vendor.name;
		var senderMail = "";
		
		if (App.current.session.data.whichUser == 1 && app.user.email2 != null) {
			senderMail = app.user.email2;						
		}else {				
			senderMail = app.user.email;			
		}
		
		var lists = getLists();
		form.addElement( new StringInput("senderName", "Nom expéditeur",senderName,true));
		form.addElement( new StringInput("senderMail", "Email expéditeur",senderMail,true));
		form.addElement( new StringSelect("list", "Destinataires",lists,null,false,null,"style='width:500px;'"));
		form.addElement( new StringInput("subject", "Sujet :","",false,null,"style='width:500px;'") );
		form.addElement( new TextArea("text", "Message :", "", false, null, "style='width:500px;height:350px;'") );
		
		if (form.checkToken()) {
			
			var listId = form.getElement("list").value;
			var dest : Array<db.User> = tools.ObjectListTool.deduplicate(getSelection(listId));
			
			
			var mails = [];
			for ( d in dest) {
				if (d.email != null) mails.push(d.email);
				if (d.email2 != null) mails.push(d.email2);
			}
			
			//send mail confirmation link
			var e = new sugoi.mail.Mail();		
			e.setSubject(form.getValueOf("subject"));
			for ( m in mails ) e.addRecipient(m);
			
			e.setSender(App.config.get("default_email"),form.getValueOf("senderName"));		
			e.setReplyTo(form.getValueOf("senderMail"), form.getValueOf("senderName"));
			
			var text :String = form.getValueOf("text");
			var html = app.processTemplate("plugin/pro/mail/message.mtt", { text:text,list:getListName(listId) });		
			e.setHtmlBody(html);
			
			App.sendMail(e);				
			
			var m = new pro.db.PMessage();
			m.sender = app.user;
			m.title = e.getSubject();
			m.body = e.getHtmlBody();
			m.date = Date.now();
			m.company = this.company;
			m.recipientListId = listId;
			m.insert();
			
			throw Ok("/p/pro/messages", "Le message a bien été envoyé");
		}
		
		view.form = form;
		
		view.sentMessages = pro.db.PMessage.manager.search( $company == this.company, {orderBy:-date,limit:20}, false);	

		
	}
	
	@tpl("plugin/pro/messages/message.mtt")
	public function doMessage(msg:pro.db.PMessage) {
		
		view.list = getListName(msg.recipientListId);
		view.msg = msg;
		
	}
	
	function getLists() :FormData<String>{
		var out = [
			{value:'1', label:'Tous mes clients (coordinateurs de contrat)' },
			//{value:'2', label:'Le bureau : les responsables + contrats + adhésions' },			
		];
		
		//out.push( { value:'3', label:'TEST : moi uniquement' } );
		//out.push( { value:'4', label:'Adhérents sans contrat/commande' } );
		//if(app.user.amap.hasMembership) out.push( { value:'5', label:'Adhésions à renouveler' } );
		
		
		//var contracts = db.Catalog.getActiveContracts(app.user.amap,true);
		//for ( c in contracts) {
			//out.push({value:'c'+c.id,label:'Souscripteurs '+c.toString()});
		//}
		return out ;
		
	}
	
	/**
	 * get list name from id
	 * @param	listId
	 */
	function getListName(listId:String) {
		
		for (ll in getLists()) {
			if (ll.value == listId) return ll.label;
		}
		
		return null;
		
	}
	
	function getSelection(listId:String):Array<db.User> {
		//if (listId.substr(0, 1) == "c") {
			////contrats
			//var contract = Std.parseInt(listId.substr(1));
			//
			//var pids = db.Product.manager.search($contractId == contract, false);
			//var pids = Lambda.map(pids, function(x) return x.id);
			//var up = db.UserOrder.manager.search($productId in pids, false);
			//
			//
			//var users = [];
			//for ( order in up) {
				//if (!Lambda.has(users, order.user)) {
					//users.push(order.user);	
					//
					//if (order.user2 != null) {
						//users.push(order.user2);
					//}
				//}
			//}
			//return users;
			
		//}else {
			var out = [];
			switch(listId) {
			case "1": 		
				//tout les clients (coordinateurs)
				for ( c in company.getCatalogs()){
					var rcs = connector.db.RemoteCatalog.getFromCatalog(c);
					for ( rc in rcs){
						var contract = rc.getContract();

						for( u in service.GroupService.getGroupMembersWithRights(contract.group,[Right.ContractAdmin(),Right.ContractAdmin(contract.id)]) ){
							out.push(u);
						}	
					}
				}
				
					
			/*case "2":
				
				var users = [];
				users.push(app.user.amap.contact);
				for ( c in db.Catalog.manager.search($amap == app.user.amap)) {
					if (!Lambda.has(users, c.contact)) {
						users.push(c.contact);
					}
				}
				
				//ajouter les autres personnes ayant les droits Admin ou Gestion Adhérents ou Gestion Contrats
 				for (ua in Lambda.array(db.UserAmap.manager.search($rights != null && $amap == app.user.amap, false))) {
 					if (ua.hasRight(AmapAdmin) || ua.hasRight(Membership) || ua.hasRight(ContractAdmin())) {
 						if (!Lambda.has(users, ua.user)) users.push(ua.user);
 					}
 				}
				
				out = users;
			
			case "3":
				//moi
				return [app.user];
			case "4":
				return Lambda.array(db.User.getUsers_NoContracts());
			case "5":
				return Lambda.array(db.User.getUsers_NoMembership());*/
			}
			
			return tools.ObjectListTool.deduplicate(out);
			
		//}
	}
	
	

	
	
}