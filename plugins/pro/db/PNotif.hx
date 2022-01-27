
package pro.db;
import Common;
import sys.db.Object;
import sys.db.Types;

enum NotifType {
	NTCatalogImportRequest;
	NTDeliveryRequest;
	NTOrdersClosed;
	NTDeliveryUpdate;
}

typedef CatalogImportContent = {
	//placeId : Int,
 	catalogId:Int,
	userId:Int, //client remote id
	message : String,
	catalogType : Int,
}

typedef DeliveryRequestContent = {
	pcatalogId:Int, //concerned cpro catalog
	distribId:Int, //multidistrib id
}

typedef DeliveryUpdate = {
	did:Int,//distrib id
	oldDistribution:DeliveryRequestContent,
	newDistribution:DeliveryRequestContent,
}

/**
 * Notifications
 */
class PNotif extends Object
{
	public var id : SId;	
	@:relation(companyId) 	public var company 	: pro.db.CagettePro;	
	@:relation(groupId) 	public var group 	: SNull<db.Group>;
	@:relation(userId) 		public var sender 	: SNull<db.User>; //sender of the notif
	public var type 	: SEnum<NotifType>;
	public var title	: STinyText;
	public var content 	: SSmallText;	
	public var date 	: SDateTime;	
	
	public function new(){
		super();
		date = Date.now();
	}

	public static function distributionInvitation(catalog:pro.db.PCatalog, distrib:db.MultiDistrib,sender:db.User){

		var notif = new pro.db.PNotif();
		notif.company = catalog.company;
		notif.title = "Demande de livraison pour le " + App.current.view.hDate(distrib.getDate());
		notif.type = NotifType.NTDeliveryRequest;
		notif.group = distrib.getGroup();
		var content : DeliveryRequestContent = {
			pcatalogId : catalog.id,
			distribId : distrib.id
		};
		notif.content  = haxe.Json.stringify(content);
		notif.sender = sender;
		notif.insert();
		
		var html = notif.group.name + " demande une livraison le " + App.current.view.hDate(distrib.getDate());
		html += "<br/>Adresse : " + distrib.getPlace().getFullAddress();
		html += "<br/>Connectez-vous à Cagette Pro pour valider ou refuser cette demande.";
		App.quickMail(notif.company.vendor.email, notif.title, html);	
	}

	public static function getDistributionInvitation(catalog:pro.db.PCatalog, distrib:db.MultiDistrib){
		var out = [];
		if(catalog==null || distrib==null) return out;
		for( n in manager.search($group==distrib.getGroup() && $type==NotifType.NTDeliveryRequest)){
			var content : DeliveryRequestContent = haxe.Json.parse(n.content);
			if(content.pcatalogId==catalog.id && content.distribId==distrib.id){
				out.push(n);
			}
		}
		return out;
	}

	public function getContent(){
		return haxe.Json.parse(this.content);
	}
}