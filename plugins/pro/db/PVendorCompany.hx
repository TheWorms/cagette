package pro.db;
import sys.db.Object;
import sys.db.Types;
/**
 * The company distributes products of this vendor
 */
@:id(companyId,vendorId)
class PVendorCompany extends Object
{
	@:relation(companyId) public var company : pro.db.CagettePro;
	@:relation(vendorId) public var vendor : db.Vendor;

	public static var MAX_VENDORS = 4;

	public static function make(vendor:db.Vendor,company:pro.db.CagettePro){
		var exists = manager.select($vendor==vendor && $company==company,false);
		if(exists!=null) return exists;

		var vc = new PVendorCompany();
		vc.vendor = vendor;
		vc.company = company;
		vc.insert();
		return vc;
	}
}