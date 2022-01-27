package pro.service;
import pro.db.PCatalogOffer;
import haxe.io.Encoding;
import Common;
import tink.core.Error;

/**
 * Service for Cagette Pro products
 * @author fbarbut
 */
class PProductService
{
	
	public var csv : sugoi.tools.Csv; //CSV parser
	var company : pro.db.CagettePro;

	public function new(company:pro.db.CagettePro) 
	{
		this.company = company;
	}
	
	/**
	 * Import or update products from a CSV file
	 * 
	 * @param	csvData					raw csv Datas
	 * @param	preview					Do not update or insert products if true
	 * @param	disableMissingProducts
	 * @param	updateCatalogs			Ids of catalogs to update
	 * @return	out						Products + offers objects
	 */
	public function importFromCsv(?csvData:String,?preview=true,?disableMissingProducts=false,?ttcPrices=true,?updateCatalogs:Array<Int>,?doNotUpdateBaseProducts=false){
		
		//incompatible params : if we just want to update a catalog, do not manage missing products
		if(doNotUpdateBaseProducts) disableMissingProducts=false;

		var datas = new Array<Map<String,String>>();		
		var out = new Array<{product:pro.db.PProduct,offers:Array<pro.db.POffer>}>(); // product + offers
		
		//for disableMissingProducts 
		var existingProducts = company.getProducts(); 
		var existingOffers = company.getOffers();
		
		//check catalogs
		var catalogsToUpdate = [];
		if(updateCatalogs!=null){
			for ( catid in updateCatalogs){
				var cat = pro.db.PCatalog.manager.get(catid, false);
				if (cat == null) throw new Error(404,"Catalog #" + catid + " doesn't exists");
				if ( cat.company.id == this.company.id ){
					catalogsToUpdate.push(cat);
				}else{ 
					throw new Error(403,"You don't own catalog #" + catid); 
				}
			}
		}
		
		//convert to utf-8 if needed
		csvData = Formatting.utf8(csvData);		
		
		//import
		if (csvData != null){
			csv = new sugoi.tools.Csv();
			csv.setHeaders( ["productName", "ref", "desc", "unit", "organic", "bulk", "txp" ,"offerName", "offerRef","qt", "price", "vat","active","imageUrl","imageDate"] );
			datas = csv.importDatasAsMap( csvData );
			datas.shift(); //remove second header
			try{ App.current.session.data.csvImportedData = datas;}catch(e:Dynamic){}
		}else{
			try{datas = App.current.session.data.csvImportedData;}catch(e:Dynamic){}
			if (datas == null) throw new Error("Can't find datas in session, please provide a csvData argument or previously call readCSV whith saveDataInSession=true");
		}
				
		var fv = new sugoi.form.filters.FloatFilter();
		var lastProduct : pro.db.PProduct = null;
		var lastofferId : Int = 1;
		var lastOutput : {product:pro.db.PProduct, offers:Array<pro.db.POffer> } = null;
		
		for (p in datas) {
			if(doNotUpdateBaseProducts) continue;

			if ( p["productName"] != null && (lastProduct == null?true:p["ref"] != lastProduct.ref) ){
				
				//PRODUCT
				if (p["ref"] == null || p["ref"] == "") {
					throw new Error("Il ne peut pas y avoir de référence nulle pour un produit.");
				}
				var product = pro.db.PProduct.getByRef(p["ref"],company,true);
				if(product == null ) product = new pro.db.PProduct();
				
				product.company = company;
				product.name = p["productName"];
				product.ref = p["ref"];
				product.desc = p["desc"];
				
				//unit
				if (p["unit"] != null){
					product.unitType = switch(p["unit"].toLowerCase()){
						case "kg" : Kilogram;
						case "g" : Gram;
						case "l" : Litre;
						case "litre" : Litre;
						case "cl" : Centilitre;
						default : Piece;
					}	
				}
				
				//taxonomy
				if (p["txp"] != null){
					product.txpProduct = db.TxpProduct.manager.get(Std.parseInt(p["txp"]), false);
				}
				
				product.organic = p["organic"] == "1";
				product.bulk = p["bulk"] == "1";
				product.active = if (p["active"] == null || p["active"] == "" || p["active"]=="1") true else false;

				//image
				if(!preview && p["imageUrl"]!=null && p["imageDate"]!=null){
					var d = Date.fromString(p["imageDate"]);
					if(d!=null && d.getTime()!=0){
						if(product.image==null || product.image.cdate==null || d.getTime() > product.image.cdate.getTime() ){
							//download image
							var path = new haxe.io.Path(p["imageUrl"]);
							var data = "";
							try{
								data = haxe.Http.requestUrl(path.toString());
							}catch(e:Dynamic){
								var p = path.toString();
								App.current.session.addMessage('An error occured while downloading the image : <a href="$p">$p</a>',true);
							}
							if(data!=null){
								var fileName = path.file+"."+path.ext;							
								//sys.io.File.saveBytes(sugoi.Web.getCwd()+"/../tmp/"+fileName,haxe.io.Bytes.ofString(data));
								var file = sugoi.db.File.createFromBytes(haxe.io.Bytes.ofString(data),fileName);
								product.image = file;
								data = null;
							}
						}
					}
				}

				//insert or update
				if (!preview) {
					if (product.id == null){
						Reflect.setField(product,"newProduct",1);
						product.insert();
					} else {
						product.update();
					} 
				}
				
				if (!preview && disableMissingProducts ){
					for (ep in Lambda.array(existingProducts) ){
						if (ep.ref == product.ref) existingProducts.remove(ep);
					}
				}
				
				var x = {product:product,offers:[]};
				out.push(x);
				
				lastOutput = x;
				lastProduct = product;
				lastofferId = 1;
			}
			

			//OFFER
			if ( p["offerRef"] == null ){
				if (lastProduct == null){
					p["offerRef"] = ""+Std.random(99999);		
				}else{
					p["offerRef"] = lastProduct.ref + "-" + lastofferId;		
				}
				lastofferId++;
			}

			var offer = pro.db.POffer.getByRef(p["offerRef"],lastProduct,true);
			if(offer==null) offer = new pro.db.POffer();
			
			offer.product = lastProduct;
			offer.ref = p["offerRef"];
			offer.name = p["offerName"];
			offer.active = if (p["active"] == null || p["active"] == "" || p["active"] == "1") true else false;

			if(lastProduct.bulk) offer.smallQt = 0.1;
			
			//if (offer.ref == "CS-0212-1" ) trace(p + "----" + offer.htPrice);
			offer.quantity = fv.filterString(p["qt"]);
			if (offer.quantity == 0.0) offer.quantity = null;
			offer.vat = fv.filterString(p["vat"]);
			//price
			var price = fv.filterString(p["price"]);
			if (price == null) throw new Error("l'offre " + offer.ref + " n'a pas de prix.\nLigne du CSV : "+p);
			if (ttcPrices){
				offer.price = price;
			}else{
				//convert HT to TTC
				if(offer.vat==null) offer.vat=0;
				offer.price = price * (1+offer.vat/100);
			}
			
			//checks
			if (company.refExists(offer.ref,lastProduct,offer)){
				throw new Error("la référence \""+offer.ref+"\" du produit "+lastProduct.name+"-"+offer.name+" est déjà utilisée dans une autre offre");
			}
			
			if (!preview) offer.id == null ? offer.insert() : offer.update();
			
			if (disableMissingProducts && !preview){
				for (eo in existingOffers.copy() ){
					if (eo.ref == offer.ref) existingOffers.remove(eo);
				}
			}
			
			lastOutput.offers.push(offer);
		}
		
		//disable missing products
		if (disableMissingProducts && !preview){
			for ( o in existingOffers){
				o.lock();
				o.active = false;
				o.update();
			}
			for ( p in existingProducts){
				p.lock();
				p.active = false;
				p.update();
			}
		}
		
		//update catalogs		
		if (catalogsToUpdate.length > 0 && !preview ){
			var offers = company.getOffers();
			//loop on datas
			for ( p in datas ){
				//update this offer in catalogs
				for ( cat in catalogsToUpdate ){
					var catalogOffer = Lambda.find(cat.getOffers(), function(x) return x.offer.ref == p["offerRef"]);
					//if catalogOffer does not exist, make it
					if(catalogOffer==null){
						var offer = Lambda.find(offers,o->return o.ref==p["offerRef"]);
						catalogOffer = PCatalogOffer.make(offer,cat,fv.filterString(p["price"]));
					}else{
						catalogOffer.lock();
						catalogOffer.price = fv.filterString(p["price"]);
					}

					if (!ttcPrices){
						//convert HT to TTC
						if(catalogOffer.offer.vat==null) catalogOffer.offer.vat=0;
						catalogOffer.price = catalogOffer.price * (1+catalogOffer.offer.vat/100);
					}

					//put updated offer in $out, to print the number of updated products
					if(doNotUpdateBaseProducts){
						if(Lambda.find(out,function(x) return x.product.id==catalogOffer.offer.product.id )==null){
							out.push({product:catalogOffer.offer.product,offers:[]});
						}
					}

					catalogOffer.update();
					
				}		
			}
			
			//need sync
			for ( c in catalogsToUpdate ) c.toSync();
		}
		
		if(!preview) try{App.current.session.data.csvImportedData = null;}catch(e:Dynamic){}
		return out;
	}
	
	/**
	 * Guess the unit+qty from the product name
	 * @param	p
	 * @param	String>
	 */
	function guessUnit(p:Map<String,String>){
		
		var regex = new EReg("([0-9]+) ?(g|kg|l|cl)", "g");
		if (regex.match( p["productName"].toLowerCase() )){
			p["unit"] = regex.matched(2);
			p["qt"] = regex.matched(1);	
			p["productName"] = regex.replace(p["productName"], "");			
		}
		
		if ( p["productName"].toLowerCase().indexOf(" bio") > 0 ){
			p["organic"] = "1";
		}
		
		return p;
	}

	/**
	 *  Create a product with minimum fields
	 *  @param name - 
	 *  @param unit - 
	 *  @param ref - 
	 *  @param company - 
	 */
	public static function make(name:String,unit:Unit,ref:String,company:pro.db.CagettePro){
		var p = new pro.db.PProduct();
		p.name = name;
		p.unitType = unit;
		p.ref = ref;
		p.company = company;
		p.insert();
		return p;
	}

	public static function makeOffer(product:pro.db.PProduct,quantity:Float,ref:String){
		var off = new pro.db.POffer();
		off.product = product;
		off.quantity = quantity;
		off.ref = ref;
		off.insert();
		return off;
	}

	public static function makeCatalogOffer(offer:pro.db.POffer, catalog:pro.db.PCatalog, price:Float){
		var catOff = new pro.db.PCatalogOffer();
		catOff.offer = offer;
		catOff.catalog = catalog;
		catOff.price = price;
		catOff.insert();
		return catOff;
	}

	public static function generateRef(company:pro.db.CagettePro):String{
		var str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
		var ref = "";
		for( i in 0...20){

			ref = str.substr(Std.random(str.length),1) + str.substr(Std.random(str.length),1) + str.substr(Std.random(str.length),1);

			if(!company.refExists(ref)) break;

		}
		return ref;
	}

	public static function getForm(?d:pro.db.PProduct,?company:pro.db.CagettePro):sugoi.form.Form{

		if(d==null){
			d = new pro.db.PProduct();
		}

		var f = form.CagetteForm.fromSpod(d);

		if(d.id==null){
			f.getElement("ref").value = pro.service.PProductService.generateRef(company);
		}

		f.removeElement( f.getElement("type") );

		f.getElement("bulk").description = "Ce produit est vendu en vrac ( sans conditionnement ). Le poids/volume commandé peut être corrigé après pesée.";
		f.getElement("bulk").docLink = "https://formation.alilo.fr/mod/page/view.php?id=793";		
	
		f.getElement("variablePrice").description = "Comme au marché, le prix final sera calculé en fonction du poids réel après pesée.";
		f.getElement("variablePrice").docLink = "https://formation.alilo.fr/mod/page/view.php?id=792";
		f.getElement("multiWeight").description = "Permet de peser séparément chaque produit. Idéal pour la volaille par exemple.";
		f.getElement("multiWeight").docLink = "https://formation.alilo.fr/mod/page/view.php?id=792";



		var ref = d.ref;
		var txId = d.txpProduct == null ? null : d.txpProduct.id;
		var html = service.ProductService.getCategorizerHtml(d.name,txId,f.name);
		f.addElement(new sugoi.form.elements.Html("html",html, 'Nom'),1);

		f.addElement(new sugoi.form.elements.Html("html","<span class='disabled'>Une catégorie manquante selon vous ? Écrivez au support : support@cagette.net</span><br/>",""),2);

		return f;
	}
	
}