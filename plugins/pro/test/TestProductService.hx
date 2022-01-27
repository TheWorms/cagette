package pro.test; import utest.*;
using Lambda;
/**
 * Test cagette-pro product service
 * 
 * @author fbarbut
 * @date 2018-02-08
 */
class TestProductService extends utest.Test
{

	/**
		Jus d'orange 25cl
		Jus de pomme
			- 1000 cl.
			- 25 cl.
		Jus de pomme cassis 75cl
		Jus de pomme passion 75cl bio*
		Philtre d'Amour (Pomme/citron/cassis/épices) 75 cl
	**/
    /**
     *  last product is "jus de pomme" with 2 offers
     */
    static var _csvData = null;
	//'"warning there should be 2 header lines !";;;;;\n"Nom du produit";"Réf";"Description";"Unité";"Bio";"qt a virgule";"Catégorisation";"Nom offre";"Référence unique";"Quantité";"Prix H.T";"taux de TVA";"actif";"URL Image";"Date Image"\n"Philtre d\'Amour (Pomme/citron/cassis/épices) 75 cl";"AA-0001";;;1;;671;;"AA-0001";;2,56;5,5;1;;"2018-01-01"\n"Jus de pomme cassis 75cl";"AA-0002";;;1;;671;;"AA-0002";;2,56;5,5;1;;"2018-01-01"\n"Jus de pomme passion 75cl bio*";"AA-0003";;;1;;671;;"AA-0003";;2,56;5,5;1;;"2018-01-01"\n"Jus d\'orange 25cl";"AA-0025";;;1;;671;;"AA-0025";;1,4;5,5;1;"2018-01-01"\n"Jus de pomme";"AA-0026";"Bon jus de pomme";"cl";1;;671;;"AA-0026-1";25;1,15;5,5;1;;"2018-01-01"\n;;;;;;;;"AA-0026-2";1000;4;5,5;1;;';
	public static function csvData() {
		if(_csvData==null){
			_csvData = sys.io.File.getContent(Sys.getCwd()+"../data/ImportProductsPro.csv");
		}
		return _csvData;
	}


	public function new(){
		super();
		// csvData = StringTools.replace(csvData,"\t",""); //remove tabs which are not in a real csv file
	}

	/**
	 * executed before each test
	 */
	function setup(){
		
		//reset DB before each test
		test.TestSuite.initDB();
		test.TestSuite.initDatas();

	}
	
	/**
	 * test a product import in Cagette pro
	 */
	public function testImport(){
		var company = pro.test.ProTestSuite.COMPANY;
		var catalog = pro.test.ProTestSuite.CATALOG1;
		var catalog2 = pro.test.ProTestSuite.CATALOG2;
		var s = new pro.service.PProductService(company);
		
		//preview
		var preview = s.importFromCsv(csvData(), true, false,false);
        Assert.equals(5,preview.length); //should be 5 products
		Assert.equals(0,company.getProducts().length);
		Assert.equals(0,company.getOffers().length);

		/**
		 *  real import (ttcPrice false)
		 */
		var r = s.importFromCsv(csvData(), false, false,false);
		Assert.equals(5,r.length); //should be 5 products
		Assert.equals(5,company.getProducts().length);
		var offers = company.getOffers();
		Assert.equals(6,offers.length);


		var o = findOfferByRef("AA-0026-1",offers);
		Assert.equals("Jus de pomme",o.product.name);
		Assert.equals("Bon jus de pomme",o.product.desc);
		Assert.equals(5.5,o.vat);
		Assert.equals(1.15*1.055,o.price);//compute ttc price
		Assert.equals(25.0,o.quantity);
		Assert.equals(Common.Unit.Centilitre,o.product.unitType);
		
		var o = findOfferByRef("AA-0026-2",offers);
		Assert.equals("Jus de pomme",o.product.name);
		Assert.equals("Bon jus de pomme",o.product.desc);
		Assert.equals(5.5,o.vat);
		Assert.equals(4*1.055,o.price);//compute ttc price
		Assert.equals(1000.0,o.quantity);
		Assert.equals(Common.Unit.Centilitre,o.product.unitType);
				
		var o = findOfferByRef("AA-0001",offers);		
		Assert.equals("Philtre d'Amour (Pomme/citron/cassis/épices) 75 cl",o.product.name);
		
		//  fill the catalogs
		for( o in offers){
			//catalog 1
			if(o.ref=="AA-0026-1" || o.ref=="AA-0026-2" || o.ref=="AA-0001"){
				//modify prices
				pro.service.PCatalogService.makeCatalogOffer(o,catalog,o.price+1); 
				pro.service.PCatalogService.makeCatalogOffer(o,catalog2,o.price+2); 
			}
		}

		//check catalog
		var coffs = catalog.getOffers();
		Assert.equals(3,coffs.length);
		var coff = findCatOfferByRef("AA-0026-1",coffs);		
		Assert.equals(coff.offer.product.name,"Jus de pomme");
		Assert.equals(coff.price,coff.offer.price+1);

		
	}

	/**
	 *  import with TTC prices + update catalog 1
	 */
	function testUpdateCatalogOnly(){

		var company = pro.test.ProTestSuite.COMPANY;
		var catalog = pro.test.ProTestSuite.CATALOG1;
		var catalog2 = pro.test.ProTestSuite.CATALOG2;
		var s = new pro.service.PProductService(company);
		s.importFromCsv(csvData(), false, false,false);
		//  fill the catalogs
		for( o in company.getOffers()){
			//catalog 1
			if(o.ref=="AA-0026-1" || o.ref=="AA-0026-2" || o.ref=="AA-0001"){
				//modify prices
				pro.service.PCatalogService.makeCatalogOffer(o,catalog,o.price+1); 
				pro.service.PCatalogService.makeCatalogOffer(o,catalog2,o.price+2); 
			}
		}

		//update a catalog
		var r = s.importFromCsv(csvData(), false, false,true,[catalog.id]);
		Assert.equals(5,r.length); //should be 5 products
		var offers = catalog.getOffers();		
		Assert.equals(6,offers.length);//should be 6 offers, because its adding the new products to the catalog

		//check if catalog offers are correct
		for( coff in offers){
			var o = coff.offer;
			switch(o.ref){
				case "AA-0026-1":
				Assert.equals("Jus de pomme",o.product.name);
				Assert.equals("Bon jus de pomme",o.product.desc);
				Assert.equals(5.5,o.vat);
				Assert.equals(1.15,coff.price); //ttc price ths time !
				Assert.equals(25.0,o.quantity);
				Assert.equals(Common.Unit.Centilitre,o.product.unitType);
				case "AA-0026-2":
				Assert.equals("Jus de pomme",o.product.name);
				Assert.equals("Bon jus de pomme",o.product.desc);
				Assert.equals(5.5,o.vat);
				Assert.equals(4.0,coff.price);//ttc price this time !
				Assert.equals(1000.0,o.quantity);
				Assert.equals(Common.Unit.Centilitre,o.product.unitType);
				default:null;				
			}
		}

		//check price update on base products
		for( o in company.getOffers()){
			switch(o.ref){
				case "AA-0026-1":
				Assert.equals(1.15,o.price); //ttc price ths time !
				case "AA-0026-2":
				Assert.equals(4.0,o.price); //ttc price this time !
				default:null;				
			}
		}

		//check catalog 2 has still old prices
		for( coff in catalog2.getOffers()){
			var o = coff.offer;
			switch(o.ref){
				case "AA-0026-1":
				Assert.equals(1.15*1.055+2,coff.price); //ttc price ths time !
				case "AA-0026-2":
				Assert.equals(4*1.055+2,coff.price); //ttc price this time !
				default:null;				
			}
		}


	}

	/**
	*  import and update catalog 1 with TTC prices + Do not update base products.
	*/
	function testDoNotUpdateBaseProducts(){
		
		var company = pro.test.ProTestSuite.COMPANY;
		var catalog = pro.test.ProTestSuite.CATALOG1;
		var catalog2 = pro.test.ProTestSuite.CATALOG2;
		var s = new pro.service.PProductService(company);
		s.importFromCsv(csvData(), false, false,true); //import in TTC
		//  fill the catalogs
		for( o in company.getOffers()){
			//catalog 1
			if(o.ref=="AA-0026-1" || o.ref=="AA-0026-2" || o.ref=="AA-0001"){
				//modify prices
				pro.service.PCatalogService.makeCatalogOffer(o,catalog,o.price+1); 
				pro.service.PCatalogService.makeCatalogOffer(o,catalog2,o.price+2); 
			}
		}

		//change prices of base offers
		for( o in company.getOffers()){
			o.lock();
			o.price *= 4;
			o.update();
		}

		// trace(company.getOffers());

		var o = findOfferByRef("AA-0026-1",company.getOffers());
		Assert.equals(1.15*4,o.price);
		Assert.equals(true,o.active);
		Assert.equals(true,o.product.active);
		var o = findOfferByRef("AA-0026-2",company.getOffers());
		Assert.equals(4.0*4,o.price);
		Assert.equals(true,o.active);
		Assert.equals(true,o.product.active);
	
		// update catalog 1 only, not base products, TTC prices )
		var r = s.importFromCsv(csvData(), false, true ,true,[catalog.id],true);

		var o = findCatOfferByRef("AA-0026-1",catalog.getOffers());
		Assert.equals(1.15,o.price);
		var o = findCatOfferByRef("AA-0026-2",catalog.getOffers());
		Assert.equals(4.0,o.price);
	
		//check prices have NOT been updated on base products
		var o = findOfferByRef("AA-0026-1",company.getOffers());
		Assert.equals(1.15*4,o.price);
		Assert.equals(true,o.active);
		Assert.equals(true,o.product.active);
		var o = findOfferByRef("AA-0026-2",company.getOffers());
		Assert.equals(4.0*4,o.price);
		Assert.equals(true,o.active);
		Assert.equals(true,o.product.active);
	

		//check catalog 2 has still old prices
		var o = findCatOfferByRef("AA-0026-1",catalog2.getOffers());
		Assert.isTrue(o!=null);
		Assert.equals(1.15+2,o.price);

		var o = findCatOfferByRef("AA-0026-2",catalog2.getOffers());
		Assert.isTrue(o!=null);
		Assert.equals(4.0+2,o.price);


	}

	function findCatOfferByRef(ref:String,offers:Iterable<pro.db.PCatalogOffer>):pro.db.PCatalogOffer{
		return Lambda.find(offers,function(o) return o.offer.ref==ref );
	}

	function findOfferByRef(ref:String,offers:Iterable<pro.db.POffer>):pro.db.POffer{
		return Lambda.find(offers,function(o) return o.ref==ref );
	}
	

}