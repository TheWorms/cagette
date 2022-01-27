package mangopay.db;
import sys.db.Types;
import mangopay.Mangopay;

/**
	Stores Payout Ids for a vendor 
**/
@:id(companyId, multiDistribKey)
class MangopayVendorPayOut extends sys.db.Object
{
	@:relation(companyId) public var company : pro.db.CagettePro;

	public var payOutId : SString<256>;
	public var multiDistribKey : SString<64>;
	public var reference : SString<64>;
	
	public static function get(company : pro.db.CagettePro, multiDistribKey : String){
		return manager.select($company == company && $multiDistribKey == multiDistribKey, true);
	}
}