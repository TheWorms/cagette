package pro.db;
import sys.db.Object;
import sys.db.Types;

/**
 * Product in a catalog
 */
@:id(offerId,catalogId)
class PCatalogOffer extends Object
{
	@:relation(offerId) public var offer : pro.db.POffer;
	@:relation(catalogId) public var catalog : pro.db.PCatalog;
	public var price : SFloat;
	
	
	public static function make(offer,catalog,price){
		var co = new PCatalogOffer();
		co.offer = offer;
		co.catalog = catalog;
		co.price = price;
		co.insert();
		return co;
	}
}

