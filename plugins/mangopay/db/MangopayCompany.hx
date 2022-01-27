package mangopay.db;
import sys.db.Types;
import mangopay.Mangopay;

/**
	Stores the MangoPay User id for a Cagette Pro Account
**/
@:id(companyId)
class MangopayCompany extends sys.db.Object
{
	
	@:relation(companyId) public var company : pro.db.CagettePro;
	public var mangopayUserId : SString<256>;
		
	public static function get(company:pro.db.CagettePro){
		return MangopayCompany.manager.select($company == company, true);
	}
}