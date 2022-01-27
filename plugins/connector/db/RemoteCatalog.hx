package connector.db ;
import sys.db.Types;
/**
 * Permet coté Cagette.net d'avoir des infos sur un contrat Cagette pro
 */
@:index(remoteCatalogId,needSync)
class RemoteCatalog extends sys.db.Object
{
	public var id : SId; //same ID as linked Catalog 
	public var remoteCatalogId : SInt;  //related cpro PCatalog
	public var needSync : SBool;
	var disabledProducts : SNull<SText>; //list of locally disabled products separated by ","
	
	public function new(){
		needSync = false;
		super();
	}
	
	public function setDisabledProducts(pids:Array<Int>){
		this.disabledProducts = pids.join(",");
	}
	
	public function getDisabledProducts():Array<Int>{
		if (this.disabledProducts == null) return [];
		return this.disabledProducts.split(",").map(Std.parseInt);
	}
	
	/*public static function make(catalog:pro.db.PCatalog,clientGroup:db.Group,remoteUserId:Int){
		var contract = createContractFromRemoteCatalog(catalog,clientGroup,remoteUserId);
		return getFromContract(contract);
	}*/

	
	
	/**
	 *  get contract linked to this remoteCatalog record
	 *  @param lock=false - 
	 */
	public function getContract(?lock=false){
		return db.Catalog.manager.get(this.id, lock);
	}
	
	public static function getFromContract(c:db.Catalog,?lock=false){
		if(c==null) throw "contract is null";
		return manager.get(c.id,lock);
	}
	
	public function getCatalog(){
		return pro.db.PCatalog.manager.get(this.remoteCatalogId,false);
	}
	
	public function countRunningOrders(){
		var now = Date.now();
		return db.Distribution.manager.count($end >= now && $orderStartDate <= now && $catalogId==this.id);
	}
	
	public function countOrdersToDeliver(){
		var now = Date.now();
		return db.Distribution.manager.count($end >= now && $orderEndDate <= now && $catalogId==this.id);
	}
	
	public static function getFromCatalog(catalog:pro.db.PCatalog,?lock=false):List<RemoteCatalog>{
		return connector.db.RemoteCatalog.manager.search($remoteCatalogId == catalog.id, lock);
	}
	
	/**
	 *  Get remoteCatalogs from catalog+group
	 *  @param catalog - 
	 *  @param group - 
	 *  @return List<connector.db.RemoteCatalog>
	 */
	public static function getContracts(catalog:pro.db.PCatalog, group:db.Group):List<connector.db.RemoteCatalog>{
		var contracts = db.Catalog.manager.search($group == group, false);
		var cids = tools.ObjectListTool.getIds(contracts);		
		return connector.db.RemoteCatalog.manager.search( ($id in cids) && $remoteCatalogId==catalog.id);
	}

	/**
		Get all remoteCatalogs for one group
	**/
	public static function getFromGroup(company:pro.db.CagettePro, group:db.Group):Array<connector.db.RemoteCatalog>{
		var out = [];
		for( c in group.getActiveContracts()){
			var rc = getFromContract(c);
			if(rc!=null && rc.getCatalog()!=null){
				if(rc.getCatalog().company.id==company.id) out.push(rc);
			}
		}
		return out;
	}
	
	
}