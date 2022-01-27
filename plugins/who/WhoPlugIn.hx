package who;
import db.Catalog;
import Common;
import datetime.DateTime;
import sugoi.plugin.*;

/**
 * Wholesale Order Plugin
 */
class WhoPlugIn extends PlugIn implements IPlugIn{
	
	public function new() {
		super();
		name = "wholesale-order";
		file = sugoi.tools.Macros.getFilePath();
		//suscribe to events
		App.current.eventDispatcher.add(onEvent);
	}
	
	public function onEvent(e:Event) {
		
		switch(e) {
			case Nav(nav, name, cid):
				
				if(name=="contractAdmin"){
					var c = Catalog.manager.get(cid,false);
					if(c!=null && connector.db.RemoteCatalog.getFromContract(c)!=null ){
						nav.push({id:"who",name:"Commande en gros", link:"/p/who/"+cid,icon:"wholesale"});		
					}					
				}
				
			case HourlyCron(now) :
				
				//send email to ask to equilibrate order 
				var from = DateTime.now().add(Hour(-1)).snap(Hour(Down)).format('%F %T');
				var to = DateTime.now().add(Hour( -1)).snap(Hour(Up)).format('%F %T');
				
				//select distribs which closed last hour with an active WConfig linked
				var sql = 'select d.* from Distribution d,WConfig c where orderEndDate >= "$from" and orderEndDate < "$to" and catalogId=contract1Id and c.active=1';
				var distribs = db.Distribution.manager.unsafeObjects(sql,false);
				
				//throw 'WHO : $from $to';
				
				for ( d in distribs){
					var user = d.catalog.contact;
					var m = new sugoi.mail.Mail();
					m.addRecipient(user.email , user.firstName+" " + user.lastName);
					m.setSender(App.config.get("default_email"),"Cagette.net");
					m.setSubject("Commande à ajuster : "+d.catalog.name);
					
					var orders = d.getOrders();
					
					var html = App.current.processTemplate("plugin/pro/who/mail/asktobalance.mtt", { group:d.catalog.group,d:d,orders:orders } );
					m.setHtmlBody(html);
					App.sendMail(m,d.catalog.group);
					
					Sys.sleep(0.25);
				}
				
			/*case Blocks(blocks, name):
				if (name == "home" ){
					
					//find distributions with wholesale-order plugin activated
					if (App.current.user == null || App.current.user.getGroup() == null) return;
					var now = Date.now();
					var cids = db.Catalog.getActiveContracts(App.current.user.getGroup());
					//distributions who are in between startDate and delivery date
					var dists = db.Distribution.manager.search($orderStartDate <= now && $date >= now && $contractId in (tools.ObjectListTool.getIds(cids)), {orderBy:date}, false);
					for (d in dists){
						
						var conf = who.db.WConfig.isActive(d.catalog);
						if ( conf != null){
						
							var html = App.current.processTemplate("plugin/who/block/home.mtt", {d:d});
							blocks.push( {id:"who",title:"Commandes en gros",html:html});
						}
						
					}
				}		*/			
			

			case GetMultiDistrib(md):
				var distributions = [];

				if(md!=null){
					distributions = md.getDistributions(db.Catalog.TYPE_VARORDER);
				}

				// display a button on the homepage
				if (App.current.user == null || App.current.user.getGroup() == null) return;
				for ( d in distributions ){						
					var conf = who.db.WConfig.isActive(d.catalog);
					if ( conf != null ){
						//md.actions.push({id:"who",link:"javascript:_.overlay('/p/who/popup/"+d.id+"','Commande en gros')",name:"Commande en gros",icon:"th"});

						var s = new who.service.WholesaleOrderService(d.catalog);

						var params : Dynamic = {};
						params.balancing = s.getBalancingSummary(d);
						params.d = d;
						params.manager = App.current.user.isContractManager(d.catalog);
						params.unit = Formatting.unit;
						params.now = Date.now();						
						if(md.extraHtml==null) md.extraHtml = "";
						md.extraHtml += App.current.processTemplate("plugin/pro/who/block/home.mtt", params);
						
					}
				}

			case ProductInfosEvent(productInfos,distribution) :

				//display a block in product infos popup
				if(distribution==null) return;
				var c = db.Catalog.manager.get(productInfos.catalogId,false);
				var conf = who.db.WConfig.isActive(c);
				if ( conf != null){
					if(productInfos.desc==null) productInfos.desc = "";

					var s = new who.service.WholesaleOrderService(c);
					var p = db.Product.manager.get(productInfos.id,false);
					var balancing = s.getBalancingSummary(distribution,p);
					if(balancing==null) return;

					var html = App.current.processTemplate("plugin/pro/who/block/productInfos.mtt",{
						balancing:balancing,
						d:distribution,
						unit:Formatting.unit,
						Math:Math
					});

					productInfos.desc += "<br/><hr/>"+html;
				}
			
		
			default :
		}
	}
	
}