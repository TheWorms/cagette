package pro.db;
import sys.db.Types;

enum VendorType {
	VTCpro; 		// 0 Offre Pro formé
	VTFree; 		// 1 Gratuit
	VTInvited; 		// 2 Invité
	VTInvitedPro;   // 3 Invité Cagette Pro
	VTCproTest; 	// 4 Cagette Pro test (COVID19 ou en attente de formation)
	VTStudent; 		// 5 compte pro pédagogique
	VTDiscovery; 	// 6 Offre Découverte
}

/**
 * Stats on vendors for analytics
 * @author fbarbut
 */
@:index(type,active,ldate)
class VendorStats extends sys.db.Object
{
	public var id : SId;
	@:relation(vendorId) public var vendor : SNull<db.Vendor>;	
	public var type:SEnum<VendorType>;	//vendor type
	public var active:SBool;			//active or not
	public var referer:SNull<SString<256>>; // referer list
	public var turnover90days : SNull<SFloat>; //turnover of the last 90 days
	public var turnoverTotal : SNull<SFloat>; //turnover since the beginning
	public var marketTurnoverSinceFreemiumResetDate : SFloat; //market turnover since freemium reset date
	public var ldate : SDateTime; //last update date
	
	public function new(){
		super();
		active = false;
		type = VTInvited;
		ldate = Date.now();
	}

	public static function getOrCreate(vendor:db.Vendor):VendorStats{
		var vs = VendorStats.manager.select($vendor==vendor,true);
		if(vs==null){
			vs = new VendorStats();
			vs.vendor = vendor;
			vs.insert();
			
		}
		return vs;
	}

	/**
		update stats of a vendor
	**/
	public static function updateStats(vendor:db.Vendor){

		var vs = getOrCreate(vendor);

		var cpro = pro.db.CagettePro.getFromVendor(vendor);

		//type
		if(cpro!=null){

			if(vendor.isTest){
				vs.type = VTCproTest;
			}else if(cpro.discovery){	
				vs.type = VTDiscovery;
			}else if(cpro.training){				
				vs.type = VTStudent;
			}else{
				vs.type = VTCpro;
			}
			
		}else{

			if(PVendorCompany.manager.count($vendor ==vendor)>0){
				vs.type = VTInvitedPro;
			}else{
				vs.type = VTInvited;

				for( c in vendor.getActiveContracts() ){	
					if(c.contact==null)	continue;
					if ( c.contact.email==vendor.email ){
						vs.type = VTFree;
						break;
					}			
				}
			}
		}

		//active
		/*var isActive = false;
		else{
			//should have open distribs
			for( c in vendor.getActiveContracts() ){				
				if ( c!=null && c.getDistribs(true).length > 0 ){
					isActive=true;
					break;
				}			
			}
		}*/
		
		var now = Date.now();
		vs.ldate = now;
		
		//turnover 30 days
		var tf = new tools.Timeframe( DateTools.delta(now,-1000.0*60*60*24*90) , now , false );

		var cids = vendor.getContracts().array().map(v -> v.id);
		vs.turnover90days = 0.0;
		for( d in db.Distribution.manager.search($date > tf.from && $date < tf.to && ($catalogId in cids), false)){
			vs.turnover90days += d.getTurnOver();
		}
		vs.turnover90days = Math.round(vs.turnover90days);

		//turnover 3 months
		vs.turnoverTotal = 0.0;
		for( d in db.Distribution.manager.search( $catalogId in cids , false)){
			vs.turnoverTotal += d.getTurnOver();
		}
		vs.turnoverTotal = Math.round(vs.turnoverTotal);

		vs.active = vs.turnover90days > 0;

		//freemium turnover 
		var from = vendor.freemiumResetDate;
		vs.marketTurnoverSinceFreemiumResetDate = 0;
		var cids = vendor.getContracts().array().filter( cat -> cat.group.hasShopMode() ).map(c -> c.id);//only shopMode
		for( d in db.Distribution.manager.search($date > from && $date < now && ($catalogId in cids), false)){
			vs.marketTurnoverSinceFreemiumResetDate += d.getTurnOver();
		}

		//a trainee cannot be active
		if(cpro!=null && cpro.training){
			vs.active = false;
		}

		vs.update();
		return vs;
	}

	
}