package pro;
import datetime.DateTime;
using tools.DateTool;
/**
 * Compute Cagette Pro Fees
 * 
 * @author fbarbut
 */
class Abo
{
	
	public var company: pro.db.CagettePro;
	public var clients : Array<db.Group>;
	public var remoteCatalogs : Array<connector.db.RemoteCatalog>;
	public var contracts : Array<db.Catalog>;
	public var offset : Int;

	public function new(company:pro.db.CagettePro) 
	{
		clients = [];		
		remoteCatalogs = [];
		contracts = [];
		offset = 0;
		
		var _clients = new Map<Int,db.Group>();
		for ( c in company.getCatalogs()){
		
			for ( r in connector.db.RemoteCatalog.getFromCatalog(c) ){
				remoteCatalogs.push(r);
				var ct = r.getContract();
				contracts.push(ct);
				var group = ct.group;
				_clients.set(group.id, group);
			}
			
		}
		
		clients = Lambda.array(_clients);
		
	}
	
	/**
	 * get Distrib num in last 6 months
	 * @param	g
	 */
	public function getDistribNum(g:db.Group){
		
		var range = get6MonthRange();
		
		var cids = [];
		for ( c in contracts){
			if ( c.group.id == g.id) cids.push(c.id);
		}
		
		return db.Distribution.manager.count( ($catalogId in cids) && $date > range.from && $date < range.to);
	}
	
	public function getTurnOver(g:db.Group){
		
		var range = get6MonthRange();
		
		var cids = [];
		for ( c in contracts){
			if ( c.group.id == g.id) cids.push(c.id);
		}
		
		var distribs =  db.Distribution.manager.search( ($catalogId in cids) && $date > range.from && $date < range.to, false);
		var total = 0.0;
		for ( d in distribs) total += d.getHTTurnOver();
		return total;
		
	}
	
	/**
	 * 6 month interval (from last month to 6 month before)
	 */
	public function get6MonthRange():{from:Date,to:Date}{
		
		var out = {from:null, to:null};
		
		var now = Date.now();
		
		if (offset == null){
			offset = 0;
		}
		
		//with datetime lib
		/*now = now.add(Month(offset));	
		var from = now.snap(Month(Down)).add(Month(-6));
		out.from = from.getDate();
		
		var to = now.snap(Month(Down)).add(Day(-1)).add(Hour(23)).add(Minute(59));
		out.to = to.getDate();*/
		
		//without...
		now = now.setDateMonth(now.getDate(), now.getMonth() + offset);
		
		out.from = now.setHourMinute(0, 0).setDateMonth(1, now.getMonth() - 6);
		
		var to = now.setDateMonth(0, now.getMonth());
		to = to.setHourMinute(23, 59);
		out.to = to;
		
		return out;
		
		
	}
	
}