package hosted.controller;

class Seo extends sugoi.BaseController
{

	@tpl("plugin/pro/hosted/seo/default.mtt")
	function doDefault(){
		
	}

	
	public function doExport118712(){
		var out = new Array<Array<String>>();
		var headers = ["id","denomination","adresse","activité","URL","telephone","e-mail","description","logo"];
		var escape = sugoi.tools.Csv.escape;
		for( cpro in pro.db.CagettePro.manager.search(true,false)){			
			var vendor = cpro.vendor;
			//farmer did not authorize to be displayed on directories
			if(!vendor.directory) continue;
			//not training accounts
			if(cpro.training) continue;

			out.push([
				Std.string(vendor.id),
				escape(vendor.name),
				escape(vendor.getAddress()),
				(vendor.profession!=null) ? vendor.getProfession() : "",
				"https://app.cagette.net"+vendor.getLink(),
				vendor.phone,
				vendor.email,
				escape(vendor.desc),
				"https://app.cagette.net"+view.file(vendor.getImageId())
			]);

		}

		sugoi.tools.Csv.printCsvDataFromStringArray(out,headers,"118712_CagetteNet.csv");
		
	}


	
}