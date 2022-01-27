package pro.test; import utest.*;
using Lambda;
/**
 * Test Various operations between cpro catalogs and Cagette Groups
 * 
 * @author fbarbut
 */
class TestRemoteCatalog extends utest.Test
{
  
	function setup(){
		//reset DB before each test
		test.TestSuite.initDB();
		test.TestSuite.initDatas();
	}

	/**
	 *  Test Linkage and product sync
	 */
	function testLinkage(){

		var company = pro.test.ProTestSuite.COMPANY;
		var catalog = pro.test.ProTestSuite.CATALOG1;
		var s = new pro.service.PProductService(company);


		//import products and offers 
		s.importFromCsv(pro.test.TestProductService.csvData(), false, false,false);
		for( o in company.getOffers()){
			pro.service.PCatalogService.makeCatalogOffer(o,catalog,o.price); 
		}

		//do we have products ?
		Assert.isTrue(catalog.getOffers().length>0);

		var group = db.Group.manager.get(1);
		var rc = pro.service.PCatalogService.linkCatalogToGroup(catalog,group,1);

		Assert.isTrue(rc!=null);
		var contract = rc.getContract();
		var catalog = rc.getCatalog();
		Assert.isTrue(contract!=null);
		Assert.equals(catalog.id,catalog.id);
		Assert.equals(catalog.startDate.getTime(),contract.startDate.getTime());
		Assert.equals(catalog.endDate.getTime(),contract.endDate.getTime());
		Assert.equals("Commande de produits YABON",contract.name);

		var groupProducts = contract.getProducts();
		for( catOff in catalog.getOffers() ){

			//each offer should have a linked product in the group
			var p = Lambda.find( groupProducts, function(x) return x.ref==catOff.offer.ref );
			Assert.isTrue(p!=null);
			Assert.equals(p.qt,catOff.offer.quantity);
			Assert.equals(p.unitType,catOff.offer.product.unitType);
		}

	}

	/**
		Check that locally disabled (blacklisted) products remain disabled, 
		even after some syncs from vendor catalog.
	**/
	function testBlacklistProduct(){

		var company = pro.test.ProTestSuite.COMPANY;
		var catalog = pro.test.ProTestSuite.CATALOG1;
		var s = new pro.service.PProductService(company);

		//import products and offers 
		s.importFromCsv(pro.test.TestProductService.csvData(), false, false,false);
		for( o in company.getOffers()){
			pro.service.PCatalogService.makeCatalogOffer(o,catalog,o.price); 
		}
		//link catalog
		var group = db.Group.manager.get(1);
		var rc = pro.service.PCatalogService.linkCatalogToGroup(catalog,group,1);
		var contract = rc.getContract();

		Assert.equals(6, contract.getProducts().length); //we got 6 products
		Assert.equals(0,rc.getDisabledProducts().length); //we got no disabled products

		//disable 2 apple juices
		var jdp1 = db.Product.getByRef(contract,"AA-0026-1");
		var jdp2 = db.Product.getByRef(contract,"AA-0026-2");
		service.ProductService.batchDisableProducts( [jdp1.id, jdp2.id ] );
		Assert.equals( 4 , contract.getProducts(true).length );

		//create a new offer and add it to catalog
		var p = pro.service.PProductService.make("PineApple Juice",Common.Unit.Kilogram, "PINE",company);
		var off = pro.service.PProductService.makeOffer(p,1,"PINE-01");
		pro.service.PCatalogService.makeCatalogOffer(off,catalog,4.8); 
		catalog.toSync();
		
		pro.service.PCatalogService.sync();

		//trace(Lambda.array(contract.getProducts()));

		//should have 7 products
		Assert.equals( 7 , contract.getProducts(false).length );
		//should have 5 enabled products
		Assert.equals( 5 , contract.getProducts(true).length );

		//disable pineapple juice
		var pineapple =  db.Product.getByRef(contract,"PINE-01");
		service.ProductService.batchDisableProducts( [ pineapple.id ] );
		Assert.equals( 3 ,rc.getDisabledProducts().length);
		Assert.equals( 4 , contract.getProducts(true).length );

		//re-enable pineapple juice
		service.ProductService.batchEnableProducts( [ pineapple.id ] );
		Assert.equals( 2 ,rc.getDisabledProducts().length);
		Assert.equals( 5 , contract.getProducts(true).length );

		//check that a disabled product in cpro, cannot be activated in a group
		var jdpOffer = pro.db.POffer.getByRef("AA-0026-1", pro.db.PProduct.getByRef("AA-0026",company));
		jdpOffer.lock();
		jdpOffer.active = false;
		jdpOffer.update();
		catalog.toSync();
		pro.service.PCatalogService.sync();
		service.ProductService.batchEnableProducts( [ jdp1.id ] );
		Assert.equals( 5 , contract.getProducts(true).length ); //should not have authorized this, stay at 5

	}


}