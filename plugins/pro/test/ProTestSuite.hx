package pro.test; import utest.*;

/**
 * Cagette-pro test suite
 */
class ProTestSuite
{
	public static var COMPANY:pro.db.CagettePro;
	public static var CATALOG1:pro.db.PCatalog;
	public static var CATALOG2:pro.db.PCatalog;


   	public static function initDB(){
       	test.TestSuite.createTable(pro.db.CagettePro.manager);
		test.TestSuite.createTable(pro.db.PUserCompany.manager);
        test.TestSuite.createTable(pro.db.PCatalog.manager);
        test.TestSuite.createTable(pro.db.POffer.manager);
        test.TestSuite.createTable(pro.db.PProduct.manager);
        test.TestSuite.createTable(pro.db.PCatalogOffer.manager);
        test.TestSuite.createTable(pro.db.PVendor.manager);
        test.TestSuite.createTable(connector.db.RemoteCatalog.manager);
   	}

	public static function initDatas(){
		//cagette Pro profile
		var vendor = new db.Vendor();
		vendor.name = "GAEC YABON";
		vendor.email = "yabon@yabon.fr";
		vendor.zipCode = "000";
		vendor.city = "Yabonville";
		vendor.insert();      

		var company = new pro.db.CagettePro();
        //company.name = "GAEC YABON";
		company.vendor = vendor;
		company.insert();
		COMPANY = company;

		//catalog 1
		var catalog = new pro.db.PCatalog();
		catalog.name = "Vente directe Yabon";
		catalog.contractName = "Commande de produits YABON";
		catalog.startDate = new Date(2013,1,1,0,0,0);
		catalog.endDate = new Date(2030,1,1,0,0,0);
		catalog.company = company;
		catalog.insert();
		CATALOG1 = catalog;

		//catalog 2
		var catalog2 = new pro.db.PCatalog();
		catalog2.name = "Livraison en France Yabon";
		catalog2.startDate = new Date(2013,1,1,0,0,0);
		catalog2.endDate = new Date(2030,1,1,0,0,0);
		catalog2.company = company;
		catalog2.insert();
		CATALOG2 = catalog2;

   }



}