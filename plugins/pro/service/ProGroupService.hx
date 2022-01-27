package pro.service;
import Common;
import db.UserGroup;

/**
 * Service for managing groups
 * @author fbarbut
 */
class ProGroupService
{
	var company : pro.db.CagettePro;

	public function new(?company:pro.db.CagettePro) 
	{
		if(company!=null) this.company = company;
	}	
	
	/**
	 * copy groups.
	 * @param	g
	 */
	public function duplicateGroup(g:db.Group,?fullCopy=false,name:String,place:String){
		
		var d = new db.Group();
		d.name = name;
		d.contact = g.contact;
		d.txtIntro = g.txtIntro;
		d.txtHome = g.txtHome;
		d.txtDistrib = g.txtDistrib;
		d.extUrl = g.extUrl;
		d.membershipRenewalDate = g.membershipRenewalDate;
		d.membershipFee = g.membershipFee;
		d.setVatRates(g.getVatRates());
		d.flags = g.flags;
		d.groupType = g.groupType;
		d.image = g.image;
		d.regOption = g.regOption;
		d.currency = g.currency;
		d.currencyCode =  g.currencyCode;
		d.setAllowedPaymentTypes(g.getAllowedPaymentTypes());
		d.checkOrder = g.checkOrder;
		d.IBAN = g.IBAN;		
		d.insert();

		var p = new db.Place();
		p.name = place;
		p.group = d;
		p.city = "";
		p.zipCode = "";
		p.insert();
		
		//put my team in the group
		if (company != null){
			for ( u in company.getUsers()){
				var x = db.UserGroup.getOrCreate(u, d);
				x.giveRight(Right.GroupAdmin);
				x.giveRight(Right.ContractAdmin());
				x.giveRight(Right.Membership);
				x.giveRight(Right.Messages);
				x.update();
			}	
		}
		
		// var mapping = duplicateCategories(g,d);
		
		//copy contracts
		if (App.current.user.isAdmin() && fullCopy){
			//copy EVERY cpro contract
			
			for ( c in g.getActiveContracts() ){
				var rc = connector.db.RemoteCatalog.getFromContract(c);
				if (rc == null) continue;
				//copy contract
				var rc = pro.service.PCatalogService.linkCatalogToGroup(rc.getCatalog(), d, App.current.user.id);
				var ct = rc.getContract();
									
				//need to sync categories
				// syncCatgories(c, ct, mapping);
				
				//add cpro members to group
				if (this.company == null){
					for (u in rc.getCatalog().company.getUsers()) u.makeMemberOf(d);
				}
			}
			
		}else{
			//copy my cpro contracts
			var rcs = new Array<connector.db.RemoteCatalog>();
			for ( c in company.getCatalogs() ){
				for (rc in connector.db.RemoteCatalog.getFromCatalog(c)){
					rcs.push(rc);
				}
			}
			for ( rc in rcs){
				var c = rc.getContract();
				if ( c.group.id == g.id) {
					//copy contract
					var rc = pro.service.PCatalogService.linkCatalogToGroup(rc.getCatalog(), d, App.current.user.id);
					var ct = rc.getContract();
					
					//need to sync categories
					// syncCatgories(c, ct, mapping);					
				}
			}
		}
		
		return d;
	}
	
	/**
	 *  Sync categories from a contract to another
	 *  @param from - 
	 *  @param to - 
	 *  @param mapping - 
	 */
	/*function syncCatgories(from:db.Catalog, to:db.Catalog, mapping:Map<Int,Int>){
		if (mapping == null) return;
		for ( p in from.getProducts(false)){
			for ( x in to.getProducts(false)){
				if ( x.ref + x.name == p.ref + p.name ){
					//need to tag x with p tags with mapping
					for ( cat in p.getCategories()){
						db.ProductCategory.getOrCreate(x, db.Category.manager.get(mapping[cat.id], false));						
					}
				}
			}
		}
	}*/
	
	
	/**
	 * Duplicate custom categories and returns ID mapping
	 * @param	from
	 * @param	to
	 */
	/*function duplicateCategories(from:db.Group, to:db.Group){
		
		var mapping = new Map<Int,Int>(); //old categ id -> new categ id
		
		//useless if taxo is on
		if ( !from.flags.has(db.Group.GroupFlags.CustomizedCategories) ) return null;
		
		for ( catgroup in db.CategoryGroup.get(from) ){
			
			var dcatgroup = new db.CategoryGroup();
			dcatgroup.name = catgroup.name;
			dcatgroup.color = catgroup.color;
			dcatgroup.pinned = catgroup.pinned;
			dcatgroup.amap = to;
			dcatgroup.insert();
			
			for ( cat in catgroup.getCategories()){
				
				var dcat = new db.Category();
				dcat.name = cat.name;
				dcat.categoryGroup = dcatgroup;
				dcat.insert();
				
				mapping[cat.id] = dcat.id;
			}
		}
		
		return mapping;
	}*/
	

	
}