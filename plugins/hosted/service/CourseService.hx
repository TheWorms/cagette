package hosted.service;

import pro.db.PUserCompany;
import pro.db.VendorStats;
import pro.db.CagettePro;

class CourseService {

    public static function createCproDef(trainingCpro:pro.db.CagettePro , ?defVendor:db.Vendor) {

        if(!trainingCpro.training) throw "ce Cagette Pro n'est pas un Cagette Pro pédagogique !";
        
        var props = ["name","email","image","phone","address1","address2",
		"zipCode","city","desc","linkText","linkUrl","vatRates"];
		var v = trainingCpro.vendor;
        
        if(defVendor==null){
            //copy vendor
            defVendor = new db.Vendor();
            for( p in props){
                Reflect.setProperty(defVendor,p,Reflect.getProperty(v,p));
            }
            defVendor.name = StringTools.replace(defVendor.name,"(formation)","");//remove "(formation)"
            defVendor.insert();
        }

        var defCpro = CagettePro.getFromVendor(defVendor);
        if(defCpro!=null) {
            defCpro.lock();
            if(defCpro.training) throw "Le compte pro sélectionné est aussi un compte pédagogique";
        }
		if(defCpro==null){
            defCpro = new pro.db.CagettePro();
            defCpro.vendor = defVendor;
        }		
        defCpro.training = false;
        defCpro.discovery = false;
        if(defCpro.id==null) defCpro.insert() else defCpro.update();

        defVendor.lock();
        defVendor.isTest = false;
        defVendor.update();

        if(v.name.indexOf("(formation)")<0){
            v.lock();
            v.name  = v.name +" (formation)";
            v.update();
        }
        
        //refresh stats
        VendorStats.updateStats(defVendor);

		//cpro access
		var cc = hosted.db.CompanyCourse.find(trainingCpro);
        if( !defCpro.getUsers().exists( u -> u.id==cc.user.id )){
            pro.db.PUserCompany.make(cc.user,defCpro);
        }
        
		//add company to course		
		hosted.db.CompanyCourse.make(defCpro, cc.course, cc.user,null,null,null,null);	
       
    }
    
}