package pro.controller.api;
import haxe.Json;
import tink.core.Error;
import Common;

/**
 * Datafood API (cagette Pro)
 */
class DFC extends controller.Controller
{
	
	/**
	 * Display a catalog
    https://grappe.io/data/api/5ccaac308dcde8003322d46b-DFC-fake-source-1

    http://localhost/api/pro/dfc/V1.2/catalog/24
	 */
	public function doCatalog(catalog:pro.db.PCatalog){
		

        var products = [];
        for( co in catalog.getOffers()){
			var i = co.offer.getInfos();
			i.price = co.price;
			products.push({
                "@id": "/suppliedProduct/item"+co.offer.id,
                "DFC:hasUnit": {
                    "@id": "/unit/"+co.offer.product.unitType,
                },
                "DFC:quantity": co.offer.quantity,
                "DFC:description": co.offer.getName()
            });
		}

        

        var jsonld = {
                "@context": {
                    "DFC": "http://datafoodconsortium.org/ontologies/DFC_FullModel.owl#",
                    "@base": "https://www.cagette.net/api/pro/dfc/"
                },
                "@id": "/entreprise/"+catalog.company.vendor.id,
                "@type": "DFC:Entreprise",
                "DFC:supplies": products,
        };

		Sys.print(Json.stringify(jsonld));
	}


    /**
	 * Display a contract
	 */
	public function doContract(contract:db.Catalog){

        var products = [];
        for( p in contract.getProducts() ){
			//var i = p.getInfos();
			
			products.push({
                "@id": "/suppliedProduct/item"+p.id,
                "DFC:hasUnit": {
                    "@id": "/unit/"+p.unitType,
                },
                "DFC:quantity": p.qt,
                "DFC:description": p.getName()
            });
		}

        

        var jsonld = {
            "@context": {
                "DFC": "http://datafoodconsortium.org/ontologies/DFC_FullModel.owl#",
                "@base": "https://www.cagette.net/api/pro/dfc/"
            },
            "@id": "/entreprise/"+contract.vendor.id,
            "@type": "DFC:Entreprise",
            "DFC:supplies": products
        };

		Sys.print(Json.stringify(jsonld));
	}
	

	
}