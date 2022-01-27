package mangopay.db;
import sys.db.Types;
import mangopay.Mangopay;
import Common;

@:id(groupId)
class MangopayLegalUserGroup extends sys.db.Object
{
	@:relation(legalUserId) public var legalUser : mangopay.db.MangopayLegalUser;
	@:relation(groupId) public var group : db.Group;	
    public var walletId : SNull<SString<64>>;			// wallet ID of this group

    public function new(){
        super();
    }
	
	public static function get( group:db.Group, ?lock = false) {		
		return manager.select( $group == group , lock);		
	}

	// public get group(): db.Group {
	// 	return null;
	// }
}