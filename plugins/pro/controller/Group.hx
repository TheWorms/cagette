package pro.controller;
import haxe.macro.Expr.Catch;
import sugoi.form.Form;
using Std;

class Group extends controller.Controller
{

	var company : pro.db.CagettePro;
	
	public function new()
	{
		super();
		view.company = company = pro.db.CagettePro.getCurrentCagettePro();
		view.nav = ["home"];		
	}
	
	@tpl('plugin/pro/group/view.mtt')
	function doDefault(g:db.Group) {
		
		view.group = g;
		var linkages = [];
		
		for ( cat in company.getCatalogs()){
			for ( rc in connector.db.RemoteCatalog.getFromCatalog(cat)){
				if (rc.getContract().group.id == g.id) linkages.push(rc);
			}
		}		
		
		view.linkages = linkages;
		checkToken();
	}
	
	/**
		Delete linkage
	**/
	function doDelete(rc:connector.db.RemoteCatalog){
		
		if (checkToken()){
			
			var c = rc.getContract(true);
			c.endDate = Date.now();
			c.update();
			
			rc.lock();
			rc.delete();
			
			throw Ok("/p/pro/group/"+c.group.id,"Le catalogue \""+c.name+"\" a été fermé. Il reste consultable dans les anciens contrats du groupe.");
			
		}
		
	}

	/**
		Remove a group and all its linkages
	**/
	@tpl('plugin/pro/form.mtt')
	function doRemoveGroup(){

		var form = new sugoi.form.Form("removeGroup");

		var data = [];
		for ( g in company.getClients()){			
			data.push( {id:g.id , label:g.name , value:g.id} );
		}
		
		form.addElement( new sugoi.form.elements.IntSelect("group", "Groupe à retirer", cast data, true) );
		form.addElement( new sugoi.form.elements.Checkbox("stayMember","Rester membre ce groupe",false) );
		form.addElement( new sugoi.form.elements.Checkbox("deleteDistribs","Supprimer les distributions futures",true) );

		if(form.isValid()){

			var group = db.Group.manager.get(form.getValueOf("group"),false);

			if(form.getValueOf("stayMember")==false){
				var ua = db.UserGroup.get(app.user,group,true);
				ua.delete();
			}


			for( rc in connector.db.RemoteCatalog.getFromGroup(company, group)){
				var c = rc.getContract(true);
				c.endDate = Date.now();
				c.update();
				
				rc.lock();
				rc.delete();

				if( form.getValueOf("deleteDistribs") == true ){

					for( distrib in c.getDistribs(true) ){
						try{
							service.DistributionService.cancelParticipation(distrib,false);
						}catch(e:tink.core.Error){
							throw Error(sugoi.Web.getURI(),e.message);
						}
						 
					}

				}
			}

			throw Ok("/p/pro","Le groupe a été retiré");

		}

		view.form = form;
		view.title = "Retirer un groupe";

	}
	
	@tpl('plugin/pro/form.mtt')
	function doDuplicate(){
		
		var f = new sugoi.form.Form("g");
		
		//get client list
		var data = [];
		var remoteCatalogs = connector.db.RemoteCatalog.manager.search($remoteCatalogId in Lambda.map(company.getCatalogs(), function(x) return x.id), false); 		
		for ( rc in Lambda.array(remoteCatalogs)){
			var contract = rc.getContract();
			data.push( {id:contract.group.id,label:contract.group.name,value:contract.group.id} );
		}
		var data = tools.ObjectListTool.deduplicate(data);

		
		f.addElement( new sugoi.form.elements.IntSelect("group", "Choisissez un groupe à dupliquer", cast data, true) );
		f.addElement( new sugoi.form.elements.StringInput("name", "Nom du nouveau groupe", null, true) );
		f.addElement( new sugoi.form.elements.StringInput("place", "Nom du nouveau lieu de livraison", null, true) );
		
		if (f.isValid()){
			try{
				var s = new pro.service.ProGroupService(this.company);
				s.duplicateGroup( db.Group.manager.get(f.getValueOf("group")) ,false, f.getValueOf("name"),f.getValueOf("place"));
				
			}catch(e:tink.core.Error){
				throw Error(sugoi.Web.getURI(),e.message);
			}
			
			throw Ok("/p/pro", "Groupe dupliqué");
		}
		
		view.form = f;
		view.title = "Dupliquer un groupe";
		
	}
	
	
}