package hosted.db ;
import sys.db.Types;
using tools.ObjectListTool;
/**
 * GroupStats
 */
@:index(active,visible)
class GroupStats extends sys.db.Object
{
	public var id : SId;
	@:relation(groupId) public var group : db.Group;	
	public var active : SBool; // distrib en cours
	public var visible : SBool; // visible sur les cartes et annuaires
	public var membersNum: SInt; //nbre de membres
	public var contractNum : SInt; //nbre de contrats non-pro actifs
	public var cproContractNum : SInt; //nbre de contrats pro actifs
	
	public function new() 
	{
		super();
		active = false;
		visible = false;
		membersNum = 0;
		contractNum = 0;
		cproContractNum  = 0;
	}

	public static function getOrCreate(groupId:Int,?lock=false) {
		var  o =  manager.select($groupId==groupId, lock);
		if (o == null) {
			o = new hosted.db.GroupStats();
			o.groupId = groupId;
			o.membersNum = o.getMembersNum();
			o.insert();
		}
		return o;
	}
	
	public function getAmap() {
		return this.group;
	}
	
	public function getMembersNum():Int {
		return db.UserGroup.manager.count($groupId == this.group.id);
	}
	
	/**
	 * Detect if this group can be visible on the map + directories.
	 */
	public function updateVisible(){
		
		var g = getAmap();
		if(g==null) return null;

		//compute main place
		var mainPlace = g.getMainPlace();
		
		//has "cagette network" flag on
		var cn = g.flags.has(db.Group.GroupFlags.CagetteNetwork);
		
		var from = DateTools.delta(Date.now(), -1000.0 * 60 * 60 * 24 * 14);
		var to =   DateTools.delta(Date.now(),  1000.0 * 60 * 60 * 24 * 30 * 6);

		//has active distribs in the next 6 months
		var del = db.MultiDistrib.manager.count($distribStartDate > from && $distribStartDate < to && $group == g ) > 0;
		if (this.membersNum < 3) del = false;
		
		this.lock();
		this.visible = (del && cn );
		this.active = del;
		this.membersNum = g.getMembersNum();
		this.update();
		
		return {
			cagetteNetwork:cn,
			geoloc: mainPlace!=null && mainPlace.lat!=null ,
			distributions:del,
			members:this.membersNum >= 3,
			visible:this.visible,
			active:this.active,
		};
		
	}
	
	
}