package pro.controller;
import sugoi.form.ListData;
import sugoi.form.validators.EmailValidator;
import sugoi.form.elements.*;
import sugoi.form.Form;
import db.UserGroup;

/**
    List Groups and vendors for SEO purpose
**/
class Directory extends controller.Controller
{


	/**
        Countries
    **/
	public function doDefault(?country:String,?zipCode:String)
	{
        //print("<h1>Pays</h1>");
        if(zipCode!=null){
            print("<ul>");
            country = country.substr(0,2).toUpperCase();
            var zmin = Std.parseInt(zipCode)*1000;
            var zmax = Std.parseInt(zipCode)*1000+999;
            for( v in db.Vendor.manager.unsafeObjects('SELECT * FROM Vendor WHERE country="$country" AND zipCode>=$zmin && zipCode<=$zmax',false) ){
                li(v.name, v.getLink());
            }
            print("</ul>");


        }else if(country!=null){
            //list zipCodes
            print("<ul>");
            country = country.substr(0,2).toUpperCase();
            for( r in sys.db.Manager.cnx.request('select ROUND(v.zipCode/1000) as zip from Vendor v where country="$country" and zipCode is not null GROUP BY zip;').results()){
                li(r.zip, '/p/pro/directory/$country/${r.zip}');
            }
            print("</ul>");

        }else{

        
            //list countries
            print("<ul>");
            for( c in db.Place.getCountries()){
                li(c.label, '/p/pro/directory/${c.value}');
            }
            print("</ul>");
        }
        
	}

    public function doCountry(country:String){

        print("<h1>Codes postaux</h1>");
        print("<ul>");
		for( vendor in db.Vendor.manager.search($country==country,false) ){
            var zip = vendor.zipCode.substr(0,2);
            li( zip, '/p/pro/directory/zip/$zip');
        }
        print("</ul>");


    }

    function print(str){
        Sys.println(str);
    }

    function li(label, link){
        print('<li><a href="$link">$label</a></li>');
    }
	
	

	
	
}