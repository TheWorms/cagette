package pro.service;

import db.UserOrder;
import db.Distribution;
import db.Membership;
import db.Basket;

class NetworkStatsService{

    var from : Date;
    var to : Date;
    var cpro : pro.db.CagettePro;
    var groups : Array<db.Group>;
    var multiDistribs : Array<db.MultiDistrib>;

    public function new(cpro:pro.db.CagettePro,from:Date,to:Date) {
        this.cpro = cpro;
        this.from = from;
        this.to = to;       
        this.groups = cpro.getNetworkGroups(); 
        this.multiDistribs = [];
        for( group in groups){
            for (md in db.MultiDistrib.getFromTimeRange( group , from , to  )){
                this.multiDistribs.push(md);
            }
        }
        
        //limit to one year
        if( (to.getTime() - from.getTime())/1000 > 60*60*24*365   ){
            throw new tink.core.Error("Vous devez choisir une période inférieure ou égale à un an");
        }
    }

    public function getGroups(){
        return groups;
    }

    public function getBasketNumber() {
        var dids = multiDistribs.map(d -> d.id);
        return Basket.manager.count( $multiDistribId in dids );        
    }
    
    public function getSalesAmount(){
        var amount = 0.0;
        
        var dids = multiDistribs.map(d -> d.id);
        var baskets = Basket.manager.search( $multiDistribId in dids );
        for ( b in baskets){
            if(b.total==null){
                b.lock();
                b.total = b.getOrdersTotal();
                b.update();
            }
            amount += b.total;
        }
                
        return amount;
    }

    /**
        get years concerned by this timeframe
    **/
    function getYears(){
        var group = groups[0];
        var years = [group.getMembershipYear(from)];
        if(group.getMembershipYear(to)!=years[0]){
            years.push( group.getMembershipYear(to) );
        }
        return years;
    }

    public function getMembershipNumber(){
        var mc = 0;
        for ( group in groups){
            mc += Membership.manager.count($date >= from && $date < to  && $group == group);
        }
        return mc;
    }

    /**
        liste les gens qui ont une cotisation valide pour cette période
    **/
    public function getActiveMembershipMembers():Array<Int>{
        var userIds = [];
        var years = getYears();
        for (group in groups){
            var memberships = Membership.manager.search(($year in years) && $group == group && $date < to, false).array();       
            for (m in memberships){
                userIds.push(m.user.id);                
            }
        }        
        return tools.ObjectListTool.deduplicateInts(userIds);
    }

    /**
        compte combien d'adhérents ont commandé
    **/
    public function getActiveMembershipWithOrderNumber(){
        var mdIds = multiDistribs.map(md->md.id);
        var distribIds = Distribution.manager.search($multiDistribId in mdIds,false).array().map(d->d.id);
        if(distribIds.length==0) return 0;
        var userIds = getActiveMembershipMembers();
        if(userIds.length==0) return 0;
        return sys.db.Manager.cnx.request('select count(distinct userId) from UserOrder where distributionId in (${distribIds.join(",")}) and userId in (${userIds.join(",")})').getIntResult(0);
    }

    public function getMembersWithOrderNumber(){
        var mdIds = multiDistribs.map(md->md.id);
        var distribIds = Distribution.manager.search($multiDistribId in mdIds,false).array().map(d->d.id);
        if(distribIds.length==0) return 0;
        return sys.db.Manager.cnx.request('select count(distinct userId) from UserOrder where distributionId in (${distribIds.join(",")})').getIntResult(0);
    }

    

    public function getMembershipAmount(){
        var amount = 0.0;
        for (group in groups){
            for ( m in Membership.manager.search($date >= from && $date < to  && $group == group, false) ){
                //fix on the fly
                if(m.amount==0 || m.amount==null){
                    m.lock();
                    if(m.operation!=null){
                        m.amount = Math.abs(m.operation.amount);
                        m.update();
                    }
                }
                amount += m.amount;
            }
        }         
        return amount;
    }

    /**
        get number of different products that have been sold during this period
    **/
    public function getProductNumber(){
        var mdIds = multiDistribs.map(md->md.id);
        var distribIds = Distribution.manager.search($multiDistribId in mdIds,false).array().map(d->d.id);
        if(distribIds.length==0) return 0;
        // return sys.db.Manager.cnx.request('select count(distinct productId) from UserOrder where distributionId in (${distribIds.join(",")})').getIntResult(0);

        //have to deduplicate product by ref 
        return sys.db.Manager.cnx.request('select count(distinct p.ref) from UserOrder uo,Product p where uo.distributionId in (${distribIds.join(",")}) and p.id=uo.productId').getIntResult(0);        
    }

    public function getMembersNumber(){
        var groupIds = groups.map(g->g.id);
        return db.UserGroup.manager.count($groupId in groupIds);
    }

    
}