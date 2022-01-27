package pro.controller;
import mangopay.Mangopay;
import pro.db.PVendorCompany;
import service.VendorService;
import sugoi.form.elements.FloatInput;
import sugoi.form.elements.StringInput;

class Company extends controller.Controller
{
	var company : pro.db.CagettePro;
	var vendor : db.Vendor;

	public function new() 
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.vendor = vendor = pro.db.CagettePro.getCurrentVendor();
		view.nav = ["company"];
		view.navbar = nav("company");
	}
	
	@tpl("plugin/pro/company/default.mtt")
	public function doDefault(){

		view.nav.push("default");

		if(company==null){
			var groups = Lambda.map(vendor.getActiveContracts(),function(c) return c.group);
			view.groups = tools.ObjectListTool.deduplicate(groups);
		}
	}
	
	@tpl('plugin/pro/form.mtt')
	function doEdit() {
		view.nav.push("default");

		var form = VendorService.getForm(vendor, !company.training );

		if(!company.training){ 
			app.session.addMessage("Attention, afin de mieux informer les consommateurs, vous devez maintenant renseigner votre <b>numéro SIRET</b> et confirmer le fait que votre activité est conforme à la <b><a href=\"https://www.cagette.net/charte-producteurs\" target=\"_blank\">Charte Producteurs Cagette.net</a></b>.");
		}
				
		if (form.isValid()) {
			vendor.lock();
			try{
				vendor = VendorService.update(vendor,form.getDatasAsObject(),!company.training);
			}catch(e:tink.core.Error){
				throw Error(sugoi.Web.getURI(),e.message);
			}			
			vendor.update();
			throw Ok('/p/pro/company','Votre compte producteur a été mis à jour');
		}
		
		view.form = form;
	}	
	
	@tpl('plugin/pro/company/users.mtt')
	public function doUsers(){
		view.nav.push("users");
		checkToken();
		view.users = pro.db.PUserCompany.getUsers(company);
	}
	
	@tpl('plugin/pro/form.mtt')
	public function doInsertUser(){
		view.nav.push("users");
		
		var f = new sugoi.form.Form("user");
		f.addElement( new sugoi.form.elements.StringInput("firstName","Prénom",null,true));
		f.addElement( new sugoi.form.elements.StringInput("lastName","Nom",null,true));
		f.addElement( new sugoi.form.elements.StringInput("email","Email",null,true));
		f.addElement( new sugoi.form.elements.Checkbox("legalRepresentative","Représentant légal",null,true));
		
		if (f.isValid()){
			var v = new pro.db.PUserCompany();
			var u = service.UserService.getOrCreate(f.getValueOf("firstName"),f.getValueOf("lastName"), f.getValueOf("email"));
			v.company = company;
			v.user = u;			
			v.legalRepresentative = f.getValueOf("legalRepresentative");

			if(v.legalRepresentative){
				if(pro.db.PUserCompany.manager.count($company==company && $legalRepresentative)>0) {
					throw Error("/p/pro/company/users", "Il y a déjà un représentant légal");
				}
			}

			v.insert();
			
			throw Ok("/p/pro/company/users", "Nouvel utilisateur ajouté");
		}
		view.title = "Ajouter un nouvel utilisateur à mon compte Cagette Pro";
		view.form = f;
	}

	@tpl('plugin/pro/form.mtt')
	public function doEditUser(user:db.User){
		view.nav.push("users");

		var uc = pro.db.PUserCompany.manager.select( $company==company && $user==user, true );
		
		var f = new sugoi.form.Form("user");
		f.addElement( new sugoi.form.elements.StringInput("firstName","Prénom",uc.user.firstName,true));
		f.addElement( new sugoi.form.elements.StringInput("lastName","Nom",uc.user.lastName,true));
		f.addElement( new sugoi.form.elements.StringInput("email","Email",uc.user.email,true));
		f.addElement( new sugoi.form.elements.Checkbox("legalRepresentative","Représentant légal",uc.legalRepresentative,true));
		
		if (f.isValid()){
			
			var u = service.UserService.getOrCreate(f.getValueOf("firstName"),f.getValueOf("lastName"), f.getValueOf("email"));
			
			uc.company = company;
			uc.user = u;			
			uc.legalRepresentative = f.getValueOf("legalRepresentative");

			if(uc.legalRepresentative){
				if(pro.db.PUserCompany.manager.count($company==company && $legalRepresentative && $user!=user)>0) {
					throw Error("/p/pro/company/users", "Il y a déjà un représentant légal");
				}
			}

			uc.update();
			
			throw Ok("/p/pro/company/users", "Utilisateur mis à jour");
		}
		view.title = "Gérer un utilisateur de mon compte Cagette Pro";
		view.form = f;
	}
	
	public function doDeleteUser(u:db.User){
		
		if (checkToken()){
			
			if (u.id == app.user.id && !app.user.isAdmin() ) {
				throw Error("/p/pro/company/users", "Vous ne pouvez pas vous retirer l'accès à vous même");
			}
			
			var uc = pro.db.PUserCompany.get(u, company);			
			if (uc != null){
				uc.lock();
				uc.delete();
			}
			
			throw Ok("/p/pro/company/users/", "Utilisateur effacé");
		}else{
			throw Redirect("/p/pro/company/users/");
		}
	}
	
	
	
	@tpl('plugin/pro/company/vendors.mtt')
	public function doVendors(){
		view.nav.push("vendors");
		checkToken();
		view.vendors = company.getVendors();
	}

	/**
		1- define the vendor
	**/
	/*@tpl("plugin/pro/form.mtt")
	function doDefineVendor(){

		if(company.getVendors().length >= PVendorCompany.MAX_VENDORS){
			//exception for GASAP.be
			if(company.vendor.id!=14908){
				throw Error("/p/pro/company/vendors","Vous ne pouvez pas ajouter plus de 4 producteurs invités");
			}
			
		}
				
		view.title = t._("Define a vendor");
		var f = new sugoi.form.Form("defVendor");
		f.addElement(new sugoi.form.elements.StringInput("name",t._("Vendor or farm name"),null,true));
		f.addElement(new sugoi.form.elements.StringInput("email",t._("Vendor email"),null,false));

		if(f.isValid()){
			//look for identical names
			var name : String = f.getValueOf('name');
			var email : String = f.getValueOf('email');
			
			var vendors = service.VendorService.findVendors( {name:name , email:email} );
			app.setTemplate('plugin/pro/company/defineVendor.mtt');
			view.vendors = vendors;
			view.email = email;
			view.name = name;

		}

		view.form = f;
	}*/

	/**
	  2- create vendor
	**/
	@tpl("plugin/pro/form.mtt")
	/*public function doInsertVendor(email:String,name:String) {
				
		var vendor = new db.Vendor();
		var form = VendorService.getForm(vendor);
				
		if (form.isValid()) {

			try{
				vendor = VendorService.create(form.getDatasAsObject());
				pro.db.PVendorCompany.make(vendor,company);
			}catch(e:tink.core.Error){
				throw Error(sugoi.Web.getURI(),e.message);
			}			
			
			throw Ok("/p/pro/company/vendors", "Nouveau producteur référencé");
			
			//service.VendorService.getOrCreateRelatedUser(vendor);			

		}else{
			form.getElement("email").value = email;
			form.getElement("name").value = name;
		}

		view.title = t._("Key-in a new vendor");
		//view.text = t._("We will send him/her an email to explain that your group is going to organize orders for him very soon");
		view.form = form;
	}*/


	/**
	3 - link vendor to this cagettePro
	**/	
/*	public function doLinkVendor(vendor:db.Vendor){
		view.nav.push("vendors");
		
		pro.db.PVendorCompany.make(vendor,company);

		throw Ok("/p/pro/company/vendors", "Nouveau producteur référencé");
		
	}*/
	
	public function doDeleteVendor(v:db.Vendor){
		
		if (checkToken()){
			var pv = pro.db.PVendorCompany.manager.search($company==this.company && $vendor==v,true).first();
			if(pv==null) throw Error("/p/pro/company/vendors/", "Impossible de retrouver ce producteur");
			pv.delete();
			throw Ok("/p/pro/company/vendors/", "Producteur effacé");
		}else{
			throw Redirect("/p/pro/company/vendors/");
		}
	}
	
	/**
		Edit a vendor
	**/
	@tpl('plugin/pro/form.mtt')
	public function doEditVendor(vendor:db.Vendor){
		view.nav.push("vendors");
		
		var form = VendorService.getForm(vendor);
		
		if (form.isValid()){
			vendor.lock();
			try{
				vendor = VendorService.update(vendor,form.getDatasAsObject());
			}catch(e:tink.core.Error){
				throw Error(sugoi.Web.getURI(),e.message);
			}			
			vendor.update();		
			throw Ok("/p/pro/company/vendors", "Producteur mis à jour");
		}
		
		view.form = form;
	}
	
	@tpl('plugin/pro/form.mtt')
	public function doVatRates() {
		view.nav.push("default");
		var f = new sugoi.form.Form("vat");
		
		if (company.vatRates == null) {
			company.lock();
			var x = new pro.db.CagettePro();
			company.vatRates = x.vatRates;
			company.update();
		}
		
		// Storing 4  values.
		//Get recorded values
		var i = 1;
		for (vatRate in company.getVatRates()) {
			f.addElement(new StringInput(i+"-k", "Nom "+i, vatRate.label));
			f.addElement(new FloatInput(i + "-v", "Taux "+i, vatRate.value ));
			i++;
		}
		//fill in to 4 values
		for (x in 0...5 - i) {
			f.addElement(new StringInput(i+"-k", "Nom "+i, null));
			f.addElement(new FloatInput(i + "-v", "Taux "+i, null));
			i++;
		}
		
		if (f.isValid()) {
			var d = f.getData();
			var vats = new Array<{value:Float,label:String}>();
			for (i in 1...5) {
				if (d.get(i + "-k") == null) continue;
				vats.push({label:d.get(i + "-k"), value: d.get(i + "-v")});
			}
			if (vats.length > 0) { // Prevent setting an empty array of vat rates
				company.lock();
				company.setVatRates(vats);
				company.update();
			}
			throw Ok("/p/pro/company/", "Taux mis à jour");
			
		}
		view.title = "Editer les taux de TVA";
		view.form = f;
		
	}
	
	@tpl('plugin/pro/company/publicPage.mtt')
	function doPublicPage(){

		view.link = sugoi.db.Permalink.getByEntity(company.vendor.id,"vendor");
		var vendor = company.vendor;
		var f = new sugoi.form.Form("publicPage");
		var catalogs = sugoi.form.ListData.fromSpod(company.getCatalogs());
		//for( c in company.getCatalogs()) catalogs.push({label:c.name,value:c.id});
		f.addElement(new sugoi.form.elements.IntSelect("catalog","Catalogue affiché sur votre page",catalogs,company.demoCatalog==null?null:company.demoCatalog.id));
		f.addElement(new sugoi.form.elements.Checkbox("directory","Référencer ma page sur les annuaires partenaires de Cagette.net",vendor.directory));
		f.getElement("directory").description = "Etre référencé sur <a href='https://www.118712.fr' target='_blank'>118712.fr</a> pour augmenter votre visibilité sur le web.";
		f.addElement(new sugoi.form.elements.TextArea("longDesc","Description longue de votre exploitation",vendor.longDesc));
		f.addElement(new sugoi.form.elements.TextArea("offCagette","En dehors de Cagette.net, où peut on trouver vos produits ?",vendor.offCagette));

		view.images = company.vendor.getImages();
		view.farmImagesNum = [0,1,2,3];

		if(f.isValid()){
			company.lock();
			company.demoCatalog = pro.db.PCatalog.manager.get(f.getValueOf("catalog"),false);
			company.update();

			vendor.lock();
			vendor.directory = f.getValueOf("directory");
			vendor.offCagette = f.getValueOf("offCagette");
			vendor.longDesc = f.getValueOf("longDesc");
			vendor.update();
			
			throw Ok("/p/pro/company/publicPage/","Votre page producteur à été mise à jour");
		}

		view.form = f;
	}

	@tpl('plugin/pro/company/link.mtt')
	function doCreateLink(){
		var vendor = company.vendor;
		view.proposals = sugoi.db.Permalink.propose(vendor.name,[vendor.zipCode.substr(0,2),vendor.city]);

		if(checkToken()){
			var link  = new sugoi.db.Permalink();
			link.entityType = "vendor";
			link.entityId = vendor.id;
			link.link = app.params.get('link');
			link.insert();
			throw Ok("/p/pro/company/publicPage","Félicitations, vous venez de créer votre page producteur.");
		}

	}
	
	

}