package hosted.db;
import sys.db.Types;

/**
 *  une formation ALILO
 */
class Course extends sys.db.Object
{
	public var id : SId;
	public var ref : SString<64>;
	public var name : SString<128>;
	public var date : SDateTime; //J1
	public var end : SDateTime;  //J2
	@:relation(groupId) public var group : SNull<db.Group>; //test group
	@:relation(teacherId) public var teacher : SNull<db.User>;
	
	public function getCompanies(){
		return hosted.db.CompanyCourse.manager.search($course==this,{orderBy:userId},false);
	}

	public function getStudents(){
		return CompanyCourse.manager.search($courseId==id,false).array().filter( cc -> cc.company.training);		
	}

	public static function all(){
		return manager.search(true,{orderBy:-date},false);
	}

}