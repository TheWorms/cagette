package mangopay.db;
import sys.db.Types;
import mangopay.Mangopay;
import Common;

/**
	A Mangopay Legal User
**/
@:id(mangopayUserId)
class MangopayLegalUser extends sys.db.Object
{
	public var mangopayUserId : SString<64>;   		//user id in mangopay
    public var name : SString<256>;					// name of legal User (organization/company)
	public var companyNumber : SNull<SString<256>>; 	    
    public var legalStatus : SNull<SString<32>>; 	//enum abstract mangopay.Types.LegalStatus
	
    @:relation(legalReprId) public var legalRepresentative : db.User;
	public var bankAccountId:SNull<SInt>;
    
	//fees
	public var fixedFeeAmount : SFloat; 				//fixed fee, in euros
	public var variableFeeRate : SFloat; 				//variable fee, percentage/100
    public var disabled : Bool;

    public function new(){
		super();
		fixedFeeAmount = 0.0;		// 0.18 if 0.18€
		variableFeeRate = 0.036; 	// 0.018 if 1.8%, 0.036 if 3.6%
		disabled = true; //disabled by default, until the KYC is validated by mangopay
	}

	/**
		get mangopay Legal user from representative
	**/	
	public static function get(user:db.User){
		return manager.select($legalRepresentative == user, true);
	}
}