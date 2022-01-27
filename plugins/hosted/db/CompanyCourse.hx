package hosted.db;
import sys.db.Types;

@:id(companyId,courseId)
class CompanyCourse extends sys.db.Object
{	
	@:relation(companyId) 	public var company : pro.db.CagettePro;
	@:relation(courseId) 	public var course : hosted.db.Course;
	@:relation(userId)		public var user : SNull<db.User>;
	
	public var moodlePass : SNull<SString<128>>;
	public var moodleUser : SNull<SString<128>>;
	public var cagettePass : SNull<SString<128>>;
	public var cagetteUser : SNull<SString<128>>;
	// public var date : SDateTime;
	
	public static function make(company,course,user, moodleUser,moodlePass,cagetteUser,cagettePass){
		var cc = new hosted.db.CompanyCourse();
		cc.course = course;
		cc.company = company;
		cc.user = user;
		cc.cagettePass = cagettePass;
		cc.cagetteUser = cagetteUser;
		cc.moodlePass = moodlePass;
		cc.moodleUser = moodleUser;
		cc.insert();
		return cc;
	}

	public static function find(company:pro.db.CagettePro){
		var cc = hosted.db.CompanyCourse.manager.select($company==company);
		if(cc!=null && cc.course!=null){
			return cc;
		}else{
			return null;
		}
	}
}