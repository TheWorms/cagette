package pro.db;
import sys.db.Object;
import sys.db.Types;
/**
 * Vendor (producteur)
 */
class PVe__ndor extends Object
{
	public var id : SId;
	public var name : SString<32>;
	
	public var email : STinyText;
	public var phone:SNull<SString<19>>;
		
	public var address1:SNull<SString<64>>;
	public var address2:SNull<SString<64>>;
	public var zipCode:SString<32>;
	public var city:SString<25>;
	
	public var desc : SNull<SText>;
	
	public var linkText:SNull<SString<256>>;
	public var linkUrl:SNull<SString<256>>;
	
	@hideInForms @:relation(imageId) public var image : SNull<sugoi.db.File>;
	@hideInForms @:relation(companyId) public var company : pro.db.CagettePro; //linked to this company

	
	public function new() 
	{
		super();
		name = "Producteur";
	}
	
	override function toString() {
		return "#"+id+"-"+name;
	}
	
	public static function getLabels(){
		var labels = pro.db.CagettePro.getLabels();
		labels["name"] = "Nom du producteur dont vous revendez les produits";
		return labels;
	}
	
}