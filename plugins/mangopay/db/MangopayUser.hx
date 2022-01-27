package mangopay.db;
import sys.db.Types;
import mangopay.Mangopay;

/**
	link a User (regular customer) to a mangopay User
**/
@:id(userId)
class MangopayUser extends sys.db.Object
{
	@:relation(userId) public var user : db.User;
	public var mangopayUserId : SString<64>; //mangopay userId as string ( int overflows )
		
	public static function get(user:db.User){
		return MangopayUser.manager.select($user == user, true);
	}
}