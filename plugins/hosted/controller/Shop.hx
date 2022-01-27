package hosted.controller;
/*
class Shop extends sugoi.BaseController
{

	
	
	@admin
	public function doInit(){
		hosted.db.Service.init();
	}
	
	// renouvellement
	@tpl("plugin/hosted/shop.mtt")
	public function doRenew() {
		view.services = hosted.db.Service.search("renew");
	}
	
	// nouvel abonnement
	@tpl("plugin/hosted/shop.mtt")
	public function doNew() {	
		view.services = hosted.db.Service.search("new");		
	}
	
	
	//passer au palier superieur
	@tpl("plugin/hosted/shop.mtt")
	public function doUpgrade() {	
		view.services = hosted.db.Service.search("upgrade");		
	}
	
	static var TOKEN = "OCpHP8ngxtCou3wsrimLrdJEU8YIF7lM";
	

	// buy service with Morning
	public function doBuy(s:hosted.db.Service) {
	
		view.s = s;
		
		var title = s.name+" - " + App.current.user.amap.name+" - " + Date.now().toString().substr(0, 10);
		
		var morning = new sugoi.apis.morning.MorningUp(TOKEN);
		var r = morning.createPayment(s.price, title , null, Std.string(Std.random(9999)), "https://app.cagette.net/p/hosted/shop/confirm");
		
		//return should be { hash => DkW0L, link => https://up.morning.com/cagette/Abonnement-Premium-100, success => true }
		if (r.success == true){
			
			app.session.data.morningToken = r.hash;
			app.session.data.serviceId = s.id;
			throw Redirect(r.link);
			
		}else{
			throw Error("/p/hosted/abo", "Erreur du prestataire de paiement : "+Std.string(r));
		}
		
	}
	

	// Confirm payment when coming from Morning payment window
	public function doConfirm(){
		
		var h = app.session.data.morningToken;
		//
		if (h == null || h==""){
			throw Error("/","Aucune trace de paiement n'a été detectée");
		}else{
			
			var morning = new sugoi.apis.morning.MorningUp(TOKEN);
			var r = morning.paymentInfo(h);
			
			if (r.success == true){
				
				var service = hosted.db.Service.manager.get(app.session.data.serviceId, false);
				
				app.session.data.morningToken = null;
				app.session.data.serviceId = null;
				//
				//r should be { hash => BH37N, transactions => [
				//{ 
					//date => 05/10/2016 11:46:02, 
					//amount => 150,
					//cardNumber => 497010XXXXXX0003,
					//coordinates => , 
					//refund => false, 
					//message => , 
					//environment => testing, 
					//success => true, 
					//identity => Roger LETEST },
				//{ date => 05/10/2016 11:50:24, amount => 150, cardNumber => 497010XXXXXX0000, coordinates => , refund => false, message => , environment => testing, success => true, identity => Roger LETEST }]
				//, link => https://up.morning.com/cagette/Abonnement-Premium-100-AMAP-du-jardin-public-2016-10-05, createdAt => 2016-10-05T09:45:41.000Z, type => direct, amount => 150, status => finished, 
				//title => Abonnement Premium 100 - AMAP du jardin public - 2016-10-05, success => true }
				//
				
				var transactions : Array<Dynamic> = cast r.transactions;
				var t = transactions[0];
				if (t == null) throw "transaction is null";
				
				if (service.price != Std.parseInt(t.amount)){
					throw 'Montant payé différent du montant demandé  ( ${service.price} != ${t.amount} )';
				}
				
				service.buy();
				
				throw Ok("/", 'Félicitations, l\'offre "${service.name}" a bien été activée');
				
			}else{
				throw Error("/p/hosted/abo", "Erreur de confirmation de paiement : "+h+" : "+Std.string(r));
			}
			
			
		}
		
	}
	
}*/