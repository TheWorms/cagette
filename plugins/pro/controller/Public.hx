package pro.controller;
import Common;
import haxe.Json;
import sugoi.Web;
import sugoi.db.Variable;

class Public extends controller.Controller
{

	@tpl("plugin/pro/public/default.mtt")
	public function doDefault(catalog:pro.db.PCatalog,?args:{?bgcolor:String,?container:String}){
		view.catalog = catalog;
		
		if (args != null && args.bgcolor != null){				
			view.bgcolor = "#"+args.bgcolor;
		}else{
			view.bgcolor = "#FFF";
		}
		
		if (args != null && args.container != null){				
			view.container = args.container; 
		}else{
			view.container = "container"; //boostrap 3 fluid layout
		}	
		
	}
	
	@tpl("plugin/pro/catalog/askImport.mtt")
	public function doAskImport(catalog:pro.db.PCatalog){
		
		if(app.user==null) throw Error("/user/login?__redirect=/p/pro/public/askImport/"+catalog.id,"Vous devez être connecté à Cagette.net pour faire cette action");

		var isVendor = isCproVendor(catalog.company);
		view.title = isVendor ? 'Relier un catalogue' : 'Demande de liaison de catalogue';

		var f = new sugoi.form.Form("import");		
		f.addElement( new sugoi.form.elements.Html("html2",catalog.company.vendor.name+" : "+catalog.name, "Catalogue") );
		var datas = [];
		for( ua in app.user.getUserGroups()){
			if(ua.isGroupManager() || ua.canManageAllContracts()){
				datas.push({label:ua.group.name,value:ua.group.id});
			}
		}
		var id = app.user.getGroup()==null ? null : app.user.getGroup().id;
		f.addElement( new sugoi.form.elements.IntSelect("group","Groupe Cagette qui accueillera le catalogue", datas, id , true) );
		f.addElement( new sugoi.form.elements.Checkbox("csa","Ce catalogue sera un contrat AMAP classique",false));
		if(!isVendor){
			f.addElement( new sugoi.form.elements.TextArea("message","Message au producteur","Bonjour, \nJe souhaiterais proposer vos produits aux membres de mon groupe Cagette...",false,null,"rows='10'") );
		}
		
		view.form = f;
		
		
		if ( f.isValid() ){
			

			//checks
			var group = db.Group.manager.get(f.getValueOf("group"),false);

			/*if (group.getPlaces().length == 0) {
				throw Error("/p/pro/public/" + catalog.id, "Votre groupe n'a aucun lieu de livraison ! Vous devez en créer au moins un avant d'importer un catalogue.");
			}
			if (!app.user.isContractManager() && !app.user.isAmapManager()){
				throw Error("/p/pro/public/askImport/" + catalog.id, "Vous devez être coordinateur pour pouvoir importer un catalogue.");
			}*/
			var contracts = connector.db.RemoteCatalog.getContracts( catalog, group );
			if ( contracts.length>0 ){
				throw Error("/contractAdmin/view/" + contracts.first().id, "Ce catalogue existe déjà dans ce groupe. Il n'est pas nécéssaire d'importer plusieurs fois le même catalogue dans un groupe.");
			}

			if(isVendor){
				
				//direct linkage
				pro.service.PCatalogService.linkCatalogToGroup(catalog, group , app.user.id, f.getValueOf("csa")==true ? db.Catalog.TYPE_CONSTORDERS : db.Catalog.TYPE_VARORDER );
				throw Ok("/contractAdmin", "Félicitations, le catalogue a bien été relié à "+group.name );

			}else{
				
				//send notif to ask for linkage
				var params : pro.db.PNotif.CatalogImportContent = {
					message		: f.getValueOf("message"),
					catalogId 	: catalog.id,
					//placeId 	: f.getValueOf("placeId"),
					userId 		: app.user.id,
					catalogType : f.getValueOf("csa")==true ? db.Catalog.TYPE_CONSTORDERS : db.Catalog.TYPE_VARORDER
				}

				//var place = db.Place.manager.get(f.getValueOf("placeId"));
				
				//store notif
				var n = new pro.db.PNotif();
				n.company = catalog.company;
				n.type = pro.db.PNotif.NotifType.NTCatalogImportRequest;
				n.title = "Demande de liaison du catalogue \"" + catalog.name+"\" pour \"" + group.name + "\"";
				n.content = haxe.Json.stringify(params);
				n.group = group;
				n.insert();
				
				//store token
				var token = "catalog-token" + haxe.crypto.Md5.encode(Std.string(Std.random(99999)));
				sugoi.db.Cache.set(token, n.id , 60 * 60 * 24 * 14);
				
				//send email
				var e = new sugoi.mail.Mail();		
				e.setSubject(n.title);
				e.setRecipient(catalog.company.vendor.email);			
				e.setSender(App.config.get("default_email"),"Cagette Pro");		
				var html = app.processTemplate("plugin/pro/mail/catalogImport.mtt", {catalog:catalog,group:group,user:app.user,message:f.getValueOf("message")});		
				e.setHtmlBody(html);
				App.sendMail(e);	
				
				throw Ok("/contractAdmin", "Votre demande a été envoyée au producteur. Vous serez prévenu par email de sa décision.");
			}
			

			

		}
	}

	function isCproVendor(company:pro.db.CagettePro):Bool{

		for( u in company.getUsers()){
			if(u.id == app.user.id) return true;
		}
		
		return false;
		

	}

	@tpl('plugin/pro/public/vendor.mtt')
	public function doVendor(vendor:db.Vendor){

		//Anti scraping
		var bl = Variable.get('IPBlacklist');
		if(bl!=null){
			var bl : Array<String> = Json.parse(bl);
			if( bl.has(Web.getClientIP())){
				App.current.setTemplate(null);
				return;
			}
		}
		if(Web.getClientHeader('user-agent').toLowerCase().indexOf("python")>-1){
			App.current.setTemplate(null);
			return;
		}

		vendorPage(vendor);

	}

	public static function vendorPage(vendor:db.Vendor){
		App.current.setTemplate("plugin/pro/public/vendor.mtt");
		App.current.view.vendor = vendor.getInfos();
		App.current.view.pageTitle = vendor.name +" - Cagette.net";
		var cpro = pro.db.CagettePro.getFromVendor(vendor);
		if(cpro!=null && cpro.demoCatalog!=null){

			App.current.view.catalog = cpro.demoCatalog;

			//Twitter Card Meta Tags
			if(cpro.demoCatalog.getOffers()[0]!=null){
				var firstProduct = cpro.demoCatalog.getOffers()[0].offer.getInfos();
				var socialShareData: SocialShareData = {
					facebookType: "website",
					url: "https://" + App.config.HOST + "/" + sugoi.Web.getURI(),
					title: vendor.name,
					description: vendor.desc,
					imageUrl: "https://" + App.config.HOST + firstProduct.image,
					imageAlt: firstProduct.name,
					twitterType: "summary_large_image",
					twitterUsername: "@Cagettenet"
				};

				App.current.view.socialShareData = socialShareData;
			}
			

		}else{

			//Twitter Card Meta Tags
			var vendor = vendor.getInfos();
			var socialShareData: SocialShareData = {
				facebookType: "website",
				url: "https://" + App.config.HOST + "/" + sugoi.Web.getURI(),
				title: vendor.name,
				description: vendor.desc,
				imageUrl: "https://" + App.config.HOST + vendor.image,
				imageAlt: vendor.name,
				twitterType: "summary_large_image",
				twitterUsername: "@Cagettenet"
			};

			App.current.view.socialShareData = socialShareData;

		}
	}

}