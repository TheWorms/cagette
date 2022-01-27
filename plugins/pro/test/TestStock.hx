package pro.test; import utest.*;

import pro.service.PCatalogService;
import pro.db.POffer;
import pro.service.PStockService;
import test.TestSuite;

using Lambda;
/**
 * Test stocks in Cpro
 * 
 * @author fbarbut
 */
class TestStock extends utest.Test
{

    var company:pro.db.CagettePro;
    var catalog:pro.db.PCatalog;
    var rcs:Array<connector.db.RemoteCatalog>;
  
	function setup(){
		//reset DB before each test
		test.TestSuite.initDB();
		test.TestSuite.initDatas();

        company = pro.test.ProTestSuite.COMPANY;
		catalog = pro.test.ProTestSuite.CATALOG1;
		var s = new pro.service.PProductService(company);

		//import products and offers 
		s.importFromCsv(pro.test.TestProductService.csvData(), false, false,false);
		for( o in company.getOffers()){
			pro.service.PCatalogService.makeCatalogOffer(o,catalog,o.price); 
		}

        //link to 2 groups
        rcs = [];
		rcs.push( pro.service.PCatalogService.linkCatalogToGroup(catalog,TestSuite.AMAP_DU_JARDIN,1) );
        rcs.push( pro.service.PCatalogService.linkCatalogToGroup(catalog,TestSuite.LOCAVORES,1) );
	}


    /**
        Update central stock in cpro, should update stock in groups.
    **/
    public function testCproStock(){

        var offs = company.getOffers();
        var orangeJuice = offs[0];
        var appleJuice = offs[1];

        var stockService = new PStockService(company);

        //update central stock
        for( o in [orangeJuice,appleJuice]){
            o.lock();
            o.stock = 10;
            o.update();

            stockService.updateStockInGroups(o);
        }

        //test in groups
        Assert.equals(2,rcs.length);

        for( rc in rcs){

            var orangeJuiceProduct = getProductInRemoteCatalog(rc, orangeJuice.ref );
            var appleJuiceProduct  = getProductInRemoteCatalog(rc, appleJuice.ref );

            Assert.isTrue( orangeJuiceProduct!=null );
            Assert.isTrue( appleJuiceProduct!=null );
            //stock should be 10
            Assert.equals( 10.0 , orangeJuiceProduct.stock );
            Assert.equals( 10.0 , appleJuiceProduct.stock );
        }

        //create distribs
        var distribs = [];
        var now = Date.now();
        for( rc in rcs){
            var catalog = rc.getContract();
            
            distribs.push( service.DistributionService.create(
                rc.getContract() ,
                tools.DateTool.deltaDays(now,20) ,
                tools.DateTool.deltaDays(now,21),
                catalog.group.getPlaces().first().id ,
                tools.DateTool.deltaDays(now,-1),
                tools.DateTool.deltaDays(now,18) 
            ));
        }

        //SEB buys orange Juice in AMAP_DU_JARDIN, stock should decrease.
        var orangeJuiceProduct = getProductInRemoteCatalog(rcs[0], orangeJuice.ref );
        var appleJuiceProduct  = getProductInRemoteCatalog(rcs[0], appleJuice.ref );

        service.OrderService.make(TestSuite.SEB , 2 , orangeJuiceProduct, distribs[0].id );
        
        //stocks in group AMAP_DU_JARDIN should be 8
        Assert.equals( 8.0 , orangeJuiceProduct.stock );
        Assert.equals( 10.0 , appleJuiceProduct.stock );

        //stocks in group LOCAVORES should be also 8
        var orangeJuiceProduct = getProductInRemoteCatalog(rcs[1], orangeJuice.ref );
        var appleJuiceProduct  = getProductInRemoteCatalog(rcs[1], appleJuice.ref );
        Assert.equals( 8.0 , orangeJuiceProduct.stock );
        Assert.equals( 10.0 , appleJuiceProduct.stock );

        //centralstock is still 10
        var stocks = PStockService.getStocks(orangeJuice);
        Assert.equals(10.0,stocks.centralStock);
        Assert.equals(2.0,stocks.undeliveredOrders);
        Assert.equals(8.0,stocks.availableStock);

        //Use case : we had a new product in catalog, stock should be up to date 
        var pproduct = new pro.db.PProduct();        
        pproduct.name = "Abricots";
        pproduct.company = this.company;
        pproduct.insert();
        var abricots = new pro.db.POffer();
        abricots.product = pproduct;
        abricots.stock = 20;
        abricots.price = 4.5;
        abricots.ref = "APR";
        abricots.insert();
        pro.service.PCatalogService.makeCatalogOffer(abricots,catalog,abricots.price); 
        //sync catalogs
        var log = PCatalogService.sync(catalog.id);
       // Sys.println(log.join("\n"));

        //new product should have a correct stock
        var abricotsProduct = getProductInRemoteCatalog(rcs[0], abricots.ref );
        Assert.equals(20.0,abricotsProduct.stock);
        var abricotsProduct = getProductInRemoteCatalog(rcs[1], abricots.ref );
        Assert.equals(20.0,abricotsProduct.stock);


        //Use case "VRAC Paris" : if a product is inactive, it should not change the undeliveredOrders value.
        orangeJuice.active = false;
        orangeJuice.update();
        PCatalogService.sync(catalog.id);
        var orangeJuiceProduct = getProductInRemoteCatalog(rcs[0], orangeJuice.ref );
        Assert.equals(false,orangeJuiceProduct.active);
        var stocks = PStockService.getStocks(orangeJuice);
        Assert.equals(10.0,stocks.centralStock);
        Assert.equals(2.0,stocks.undeliveredOrders);
        Assert.equals(8.0,stocks.availableStock);

        //stock is still managed even if the product is disabled
        service.OrderService.make(TestSuite.FRANCOIS , 4 , orangeJuiceProduct, distribs[0].id );
        var orangeJuiceProduct = getProductInRemoteCatalog(rcs[0], orangeJuice.ref );
        var stocks = PStockService.getStocks(orangeJuice);
        Assert.equals(10.0,stocks.centralStock);
        Assert.equals(6.0,stocks.undeliveredOrders);
        Assert.equals(4.0,stocks.availableStock);

        //variant : remove from catalog, stock should always be updated
        var orangeCatalogOffer = Lambda.find(catalog.getOffers(), function(co) return co.offer.ref==orangeJuice.ref);
        orangeCatalogOffer.lock();
        orangeCatalogOffer.delete();
        Assert.isNull(Lambda.find(catalog.getOffers(), function(co) return co.offer.ref==orangeJuice.ref));
        PCatalogService.sync(catalog.id);                   
        //update stock
        orangeJuice.stock = 30;
        orangeJuice.update();
        stockService.updateStockInGroups(orangeJuice);
        var orangeJuiceProduct = getProductInRemoteCatalog(rcs[0], orangeJuice.ref );
        Assert.equals(false,orangeJuiceProduct.active);
        Assert.equals(24,orangeJuiceProduct.stock); //30 - 6

        
        //Decrease stock definitely when orders close
        var d = distribs[0];
        d.date = tools.DateTool.deltaDays(now,-1) ;
        d.end = tools.DateTool.deltaDays(now,-1) ;
        d.update();
        PStockService.decreaseStocksOnDistribEnd(d,rcs[0]);
        var orangeJuice = pro.db.POffer.manager.get(orangeJuice.id,true);//reget
        //main stock should be decreased to 24 ( 30 - 6 )
		Assert.equals(24.0 , orangeJuice.stock);
		Assert.equals(0.0 ,  orangeJuice.countCurrentUndeliveredOrders()); 
		Assert.equals(24.0 , orangeJuiceProduct.stock);  
        

        //test that a product can go back to null stock ( disabling stock mgmgt )
        appleJuice.stock = null;
        appleJuice.update();
        stockService.updateStockInGroups(appleJuice);
        var appleJuiceProduct = getProductInRemoteCatalog(rcs[1], appleJuice.ref );
        Assert.isNull(appleJuiceProduct.stock);

    }
	
    /**
        finds a product in a remote catalog
    **/
    function getProductInRemoteCatalog(rc:connector.db.RemoteCatalog,ref:String):db.Product{
        return rc.getContract().getProducts(false).find( p -> return p.ref == ref );
    }




    /**
	 *  Test stock management in cpro
	 */
	/*function testStocks(){

		var bubar = test.TestSuite.FRANCOIS;
		var seb = test.TestSuite.SEB;

		var company = pro.test.ProTestSuite.COMPANY;
		var catalog = pro.test.ProTestSuite.CATALOG1;
		
		//import products
		var s = new pro.service.PProductService(company);
		var r = s.importFromCsv(TestProductService.csvData(), false, false,false);		
		for( o in company.getOffers()){
			pro.service.PCatalogService.makeCatalogOffer(o,catalog,o.price); 
		}

		pro.service.PCatalogService.linkCatalogToGroup(catalog,test.TestSuite.LOCAVORES,seb.id);
		Assert.isTrue(catalog.getOffers().length>0);

		//be sure that we have a catalog which is linked to a group
		var rc = connector.db.RemoteCatalog.getFromCatalog(catalog).first();		
		Assert.isTrue(rc!=null);

		//set a stock to apple juice
		var juice  = Lambda.find( company.getOffers() , function(x) return x.ref=="AA-0026-1" );
		Assert.isTrue(juice!=null);
		Assert.equals("Jus de pomme",juice.product.name);
		juice.lock();
		juice.stock = 10;
		juice.update();
		pro.service.PStockService.updateStockInGroups(juice);

		//check stock is also 10 in the group
		var contract = rc.getContract();
		var p = Lambda.find( contract.getProducts(), function(x) return x.ref=="AA-0026-1" );
		Assert.isTrue(p!=null);
		Assert.equals(10.0,p.stock);
		Assert.isTrue(contract.flags.has(StockManagement));

		//create a distrib		
		var now = Date.now();
		var d = service.DistributionService.create(
			contract,
			tools.DateTool.deltaDays(now,10),
			tools.DateTool.deltaDays(now,10),
			contract.group.getPlaces().first().id,
			tools.DateTool.deltaDays(now,-1),
			tools.DateTool.deltaDays(now,8),
			null,
			false,
			null
		);
		
		//make an order
		var uo = service.OrderService.make(bubar,2,p,d.id);
		Assert.equals(2.0,uo.quantity);
		Assert.equals(8.0,uo.product.stock);
		//p.lock(); //to get last version
		Assert.equals(8.0,p.stock);
		//stock should remain at 10 in cpro since distrib did not took place.
		Assert.equals(10.0,juice.stock);
		Assert.equals(2.0,juice.countCurrentUndeliveredOrders());

		//edit order
		service.OrderService.edit(uo,1);
		Assert.equals(10.0,juice.stock);
		Assert.equals(9.0,p.stock);//should have raised from 8 to 9

		//simulate the distrib just ended : stock should be decreased
		d.date = DateTools.delta(now,1000.0*60*60*-1);
		d.update();
		
		stockService.decreaseStocksOnOrderClose(d,rc);
		Assert.equals(9.0,juice.stock);
		Assert.equals(0.0,juice.countCurrentUndeliveredOrders());
		Assert.equals(9.0,p.stock);
	}*/

}