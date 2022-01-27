package mangopay.db;
import sys.db.Types;
import mangopay.Types;

/**
	Stores Payout Ids for a group 
**/
//@:id(payOutId, multiDistribId)
class MangopayGroupPayOut extends sys.db.Object
{
    public var id : SId;
    @:relation(multiDistribId) public var multiDistrib     : db.MultiDistrib;
	public var payOutId         : SString<64>; //payout ID in mangopay
    public var cachedDatas      : SNull<SData<PayOut>>; //payout data stored from Mangopay API

	public static function get(md:db.MultiDistrib,?lock=false){

        var payout = manager.select($multiDistrib == md, lock);		
        if(payout!=null){
            payout.refreshDatas();
        } 
        return payout;
	}

    /*public static function all(group:db.Amap){
        var all = manager.search($group == group,{orderBy:-cdate}, false);
        for ( a in all) a.refreshDatas();
        return all;
    }*/

    /**
        Get payout datas from Mangopay API
    **/
    function refreshDatas():Void{
        if(this.payOutId==null || this.payOutId=="") return;
        if(this.cachedDatas==null || this.cachedDatas.Status!=Succeeded){
            this.lock();
            this.cachedDatas = mangopay.Mangopay.getPayOut(this.payOutId);
            this.update();
        }
    }

    public function hasSucceeded():Bool{
        // if(this.payOutId==0) return true;
        return this.cachedDatas!=null && this.cachedDatas.Status==Succeeded;
    }

    public function getAmount():Float{
        if(this.payOutId==null || this.payOutId=="") return 0.0;
        return this.cachedDatas.DebitedFunds.Amount/100;
    }
}