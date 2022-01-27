package who.db;
import sys.db.Object;
import sys.db.Types;

class WConfig extends Object
{
	public var id : SId;
	@:relation(contract1Id) public var contract : db.Catalog;			
	public var active : SBool;
	//public var delay : SInt; //number of days after orders closing to complete the wholesale order
	
	private static var activeWconfigCache = new Map<Int,WConfig>();

	public static function isActive(c:db.Catalog):WConfig{

		var keys :Array<Int> = [for(k in activeWconfigCache.keys()) k];
		//in cache
		if(keys.has(c.id)){
			return activeWconfigCache[c.id];
		}else{
			//not in cache
			var x = manager.select($contract == c, false);
			if (x != null && x.active){
				activeWconfigCache[c.id] = x;
				return x;
			}else{
				activeWconfigCache[c.id] = null;
				return null;
			}	
		}

		
	}
	
	public static function getOrCreate(c:db.Catalog):WConfig{
		
		var x =  manager.select($contract == c, true);
		if (x == null){
			x = new WConfig();
			x.contract = c;
			x.active = false;
			x.insert();
		}
		return x;
	}
	
}
