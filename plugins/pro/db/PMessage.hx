package pro.db;
import sys.db.Object;
import sys.db.Types;
 
class PMessage extends Object
{

	public var id : SId;
	@:relation(senderId) public var sender : db.User;
	@:relation(companyId) public var company : pro.db.CagettePro;
	public var recipientListId : SString<12>;
	public var title : SString<128>;
	public var body : SText;
	public var date : SDateTime;
	
	
}