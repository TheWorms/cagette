package connector;
import Common;
import sugoi.ControllerAction;
import pro.db.PNotif;
import sugoi.plugin.*;

class ConnectorPlugIn extends PlugIn implements IPlugIn{
	
	public function new() {
		super();
		name = "connector";
		file = sugoi.tools.Macros.getFilePath();
		
		//suscribe to events
		App.current.eventDispatcher.add(onEvent);
		
		//add i18n strings
		//var i18n = App.t.getStrings();
		//i18n.set("dateStart","Début de validité");
		//i18n.set("dateEnd","Fin de validité");
		
	}
	
	function getRemoteCatalog(contractId:Int,?lock=false){
		var contract = db.Catalog.manager.get(contractId);
		return connector.db.RemoteCatalog.getFromContract(contract,lock);
	}
	
	public function onEvent(e:Event) {
		
		switch(e) {
			case Nav(navigation, name, cid):
				/*if (name == "contractAdmin"){
					
					//check if it is a remote contract
					var rc = getRemoteCatalog(cid);
					if (rc != null) {
						navigation.push({id:"cpro",name:"Producteur Cagette Pro",link:"/p/connector/contract/"+cid,icon:"farmer-pro"});
					}
				}*/	
			case PreNewDistrib(contract):
				
				//warn that the new distribution will be sent to the producer
				/*var rc = getRemoteCatalog(contract.id);
				if (rc != null){
					
					//look for existing request
					var requests = [];
					
					for (notif in pro.db.PNotif.manager.search($group == contract.amap, false)){
						
						switch(notif.type){
							case NTDeliveryRequest : 
								var data : DeliveryRequestContent = notif.content;
								if (data.remoteContractId == contract.id){
									requests.push("Demande de livraison pour le "+App.current.view.hDate(data.date));
								}
							case NTDeliveryUpdate :
								var data : DeliveryUpdate = notif.content;
								if (data.newDistribution.remoteContractId == contract.id){
									requests.push("Mise à jour de livraison pour le "+App.current.view.hDate(data.newDistribution.date));
								}
							default : 
						}
					}
					
					if (requests.length > 0){
						var s = "Attention, vous avez déjà des demandes de distribution en cours pour <b>"+contract.vendor.name+"</b> : <br/><ul>";
						for ( r in requests ) {							
							s += "<li>"+r+"</li>";
						}
						s += "</ul>";
						App.current.session.addMessage(s,true);	
						
					}else{
						
						var s = "Attention, vous êtes sur un catalogue <b>Cagette Pro</b> qui est supervisé par le producteur <b>"+contract.vendor.name+"</b>.<br/>Si vous créez une nouvelle distribution, elle sera proposée au producteur et il devra la valider pour qu'elle soit active.";
						App.current.session.addMessage(s);		
					}					
				}*/
				
			case NewDistrib(distrib):
				/*
				//ask the producer for a new delivery
				var remoteCata = getRemoteCatalog(distrib.contract.id);
				if (remoteCata != null){
					
					var notif = new pro.db.PNotif();
					notif.company = remoteCata.getCatalog().company;
					notif.title = "Demande de livraison pour le " + App.current.view.hDate(distrib.date);
					notif.type = pro.db.PNotif.NotifType.NTDeliveryRequest;
					notif.group = App.current.user.amap;
					var content : DeliveryRequestContent = {
						place : distrib.place.getFullAddress(),
						remotePlaceId : distrib.place.id,
						date : distrib.date,
						end : distrib.end,
						orderStartDate : distrib.orderStartDate,
						orderEndDate : distrib.orderEndDate,
						products : Lambda.array(Lambda.map(distrib.contract.getProducts(true), function(x) return x.ref)),
						remoteContractId : distrib.contract.id,
						distributors : []
					};
					notif.content  = content;
					notif.insert();
					
					//null date to tell that the distribution should not be recorded					
					distrib.date = null;
					
					var html = notif.group.name + " demande une livraison le " + App.current.view.hDate(content.date);
					html += "<br/>Adresse : " + content.place;
					html += "<br/>Connectez-vous à votre compte Cagette Pro pour valider ou refuser cette demande.";
					App.quickMail(notif.company.vendor.email, notif.title, html);					
			}*/
				
			case EditDistrib(distrib):
				
				//ask the producer for a new delivery
				/*var remoteCata = getRemoteCatalog(distrib.contract.id);
				if (remoteCata != null){
					
					var notif = new pro.db.PNotif();
					notif.company = remoteCata.getCatalog().company;
					notif.title = "Modification de livraison pour le " + App.current.view.hDate(distrib.date);
					notif.type = pro.db.PNotif.NotifType.NTDeliveryUpdate;
					notif.group = App.current.user.amap;
					
					//get the old distribution, use direct SQL to bypass the SPOD cache
					var oldDisttrib = sys.db.Manager.cnx.request('SELECT * FROM Distribution WHERE ID=${distrib.id}').results().first();
					var oldPlace = db.Place.manager.get(oldDisttrib.placeId, false);
					
					var content : DeliveryUpdate = {
						did:distrib.id,
						oldDistribution:{
							place : oldPlace.getFullAddress(),
							remotePlaceId : oldDisttrib.placeId,
							date : oldDisttrib.date,
							end : oldDisttrib.end,
							orderStartDate : oldDisttrib.orderStartDate,
							orderEndDate : oldDisttrib.orderEndDate,
							products : null,
							remoteContractId : oldDisttrib.contractId,
							distributors : null
						},
						newDistribution:{
							place : distrib.place.getFullAddress(),
							remotePlaceId : distrib.place.id,
							date : distrib.date,
							end : distrib.end,
							orderStartDate : distrib.orderStartDate,
							orderEndDate : distrib.orderEndDate,
							products : null,
							remoteContractId : distrib.contract.id,
							distributors : []
						}				
					};
					notif.content  = content;
					notif.insert();
					
					//null date to tell that the distribution should not be recorded					
					distrib.date = null;
					
					//email notif
					var html = notif.group.name + " demande une modification de livraison";
					html += "<br/>Adresse : " + content.newDistribution.place;
					html += "<br/>Date : " + App.current.view.hDate(content.newDistribution.date);
					html += "<br/>Connectez-vous à votre compte Cagette Pro pour valider ou refuser cette demande.";
					App.quickMail(notif.company.vendor.email, notif.title, html);	
				}
				*/
				
			/*case PreNewDistribCycle(cycle),NewDistribCycle(cycle):
				
				var remoteCata = getRemoteCatalog(cycle.contract.id);
				if (remoteCata != null){
					throw ErrorAction("/contractAdmin/distributions/" + cycle.contract.id, "Les distributions récurrentes ne sont pas disponibles car ce catalogue est géré par le producteur via Cagette Pro. Merci de créer des distributions une par une.");
				}
			*/	
			case DeleteDistrib(d):
				var remoteCata = getRemoteCatalog(d.catalog.id);
				if (remoteCata != null){
					throw ErrorAction("/contractAdmin/distributions/" + d.catalog.id, "Impossible d'effacer cette distribution car ce catalogue est géré par le producteur via Cagette Pro.");
				}
				
			case PreEditProduct(p), EditProduct(p), DeleteProduct(p), NewProduct(p):
				var remoteCata = getRemoteCatalog(p.catalog.id);
				if (remoteCata != null){
					throw ErrorAction("/contractAdmin/products/" + p.catalog.id, "Vous ne pouvez pas modifier ce produit car ce catalogue est géré par le producteur via Cagette Pro.");
				}
			case PreNewProduct(c):
				var remoteCata = getRemoteCatalog(c.id);
				if (remoteCata != null){
					throw ErrorAction("/contractAdmin/products/" + c.id, "Vous ne pouvez pas créer de produit car ce catalogue est géré par le producteur via Cagette Pro.");
				}
				
			case BatchEnableProducts(data) :
				var pids = data.pids;				
				var c = db.Product.manager.get(pids[0], false).catalog;								
				var remoteCata = getRemoteCatalog(c.id, true);				
				if (remoteCata != null){
					
					var cata = remoteCata.getCatalog();
					var offers = cata.getOffers();
					
					if (data.enable){
						var localDisabledProducts = remoteCata.getDisabledProducts();
						var msgs = [];
						//locally enable products
						for (pid in pids.copy() ){
							
							//check that I can enable it 
							var p = db.Product.manager.get(pid, false);
							var off = Lambda.find(offers, function(x) return x.offer.ref == p.ref);
							if (off == null || !off.offer.active){
								pids.remove(pid);
								msgs.push(p.name+" ("+p.ref+")");
							}
							
							//remove from local list
							localDisabledProducts.remove(pid);							
						}
						
						remoteCata.setDisabledProducts(localDisabledProducts);
						remoteCata.update();
						
						if(msgs.length>0 && App.current.session!=null )
							App.current.session.addMessage("Vous ne pouvez pas activer les produits suivants, car le producteur les a signalés comme indisponibles : " + msgs.join(", "));
						
					}else{
						//locally disable products
						var localDisabledProducts = remoteCata.getDisabledProducts();
						for( pid in pids){
							if(pid!=null && !Lambda.has(localDisabledProducts,pid)) localDisabledProducts.push(pid);
						}
						remoteCata.setDisabledProducts(localDisabledProducts);
						remoteCata.update();
					}
					
					
					
					//throw ErrorAction("/contractAdmin/products/" + c.id, "Vous ne pouvez pas activer ou désactiver de produits car ce catalogue est géré par le producteur via Cagette Pro.");
				}
				
			case DeleteContract(contract) :
				
				var remote = getRemoteCatalog(contract.id,true);
				if ( remote != null){
					remote.delete();
				}

			case DuplicateContract(contract) :
				if ( getRemoteCatalog(contract.id,true) != null){
					throw sugoi.ControllerAction.ErrorAction("/contractAdmin","C'est un catalogue Cagette Pro, il n'est pas possible de le dupliquer");
				}

			case EditContract(contract,form)	 :
				
				if ( getRemoteCatalog(contract.id,true) != null){
					//throw sugoi.ControllerAction.ErrorAction("/contractAdmin","C'est un catalogue Cagette Pro, seul le producteur a le droit de le modifier");

					//allow only to edit some options.
					form.removeElementByName("startDate");
					form.removeElementByName("endDate");
					form.removeElementByName("name");
					form.removeElementByName("vendorId");					
					form.removeElementByName("description");

					var text = "Ce catalogue est géré par un producteur équipé de <a href='http://www.cagette.pro'>Cagette Pro</a>, vous n'avez donc accès qu'à un nombre restreint de paramètres.";
					form.addElement(new sugoi.form.elements.Html("info","<div class='alert alert-info'>"+text+"</div>"),0);
				}
					
				
			default :
		}
	}
	
	/*function getDistributorsList(d:db.Distribution):Array<Int>{
		if (d == null) return null;
		var out = [];
		for ( x in [d.distributor1, d.distributor2, d.distributor3, d.distributor4]){
			if ( x != null ) out.push(x.id);
		}
		return out;
	}*/
}