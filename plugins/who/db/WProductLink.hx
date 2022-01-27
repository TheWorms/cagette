package who.db;
import sys.db.Object;
import sys.db.Types;
import Common;

/*
class WProductLink 
{
	
	//@:relation(p1Id) public var p1 : db.Product;//detail product
	//@:relation(p2Id) public var p2 : db.Product;//detail product
	
	/**
	 * @deprecated
	 * @param	c
	 */
	/*public static function get(c:db.Contract){
		
		var pids = tools.ObjectListTool.getIds(c.getProducts(false));
		
		return who.db.WProductLink.manager.search($p1Id in pids, false);		
	}*/
	
	/**
	 * autolink with Cagette Pro Data and store links
	 */
	/*public static function autolink(c1:db.Contract,c2:db.Contract){
		var rc1 = connector.db.RemoteCatalog.getFromContract(c1);
		var c1off = rc1.getCatalog().getOffers();
		
		var rc2 = connector.db.RemoteCatalog.getFromContract(c2);
		var c2off = rc2.getCatalog().getOffers();
		
		for (off in c1off){
			
			//off is the retail product
			
			var offs = off.offer.product.getOffers();
			
			
			var big = offs.first();
			var little = off.offer;
			if ( big.id != little.id){
				
				var little = db.Product.getByRef(c1,little.ref);
				var big = db.Product.getByRef(c2,big.ref);
				
				make(little, big);
				//trace('big est $big, little est $little <br/>');
			}
		}
	}*/
	
	
	
	
	/*function totalOrder(p:db.Product,d:db.Distribution){
			
		var orders = db.UserContract.manager.search($distribution == d && $product == p, false);			
		var tot = 0.0;
		for ( o in orders ) tot += o.quantity;
		return tot;
		
	}*/
	
	
	/*public static function make(p1:db.Product, p2:db.Product){
		var pl = new WProductLink();
		pl.p1 = p1;
		pl.p2 = p2;
		pl.insert();
		return pl;
	}
	
	
	
}
*/
