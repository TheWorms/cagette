package mangopay;
import Common;
import mangopay.Types;
import mangopay.db.*;
import mangopay.MangopayPlugin;
import tink.core.Error;

/**
	MangoPay API connector
	@docs https://docs.mangopay.com/
**/
class Mangopay
{
	public static var CLIENT_ID:String = null;
	public static var API_KEY:String = null;
	public static var DEBUG:Bool = null;
	public static var BASE_URL:String = null;
		
	static public function init(){
		if(CLIENT_ID==null){
			// DEBUG = (App.config.DEBUG || App.config.HOST.substr(0,3)=="pp." || App.config.HOST.indexOf(".dev.") > -1 );
			if(App.config.get("MANGOPAY_CLIENT_ID")=="" || App.config.get("MANGOPAY_CLIENT_ID")==null){
				throw "No Mangopay config in config.xml";
			}

			CLIENT_ID = App.config.get("MANGOPAY_CLIENT_ID");
			API_KEY = App.config.get("MANGOPAY_API_KEY");
			BASE_URL = App.config.get("MANGOPAY_BASE_URL");
		}
	}

	static public function callService(requestPath:String, ?methodName="GET", ?params:String, ?exceptionOnResultCode=true):Dynamic {

		init();
		
		var serviceUrl = BASE_URL + "/" + CLIENT_ID + "/" + requestPath;

		var auth = haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(CLIENT_ID + ":" + API_KEY));		
		var headers = [
			"Authorization" => "Basic " + auth,
			"Content-type" 	=> "application/json;charset=utf-8",
			"Accept" 		=> "application/json",
			"Cache-Control" => "no-cache",
			"Pragma" 		=> "no-cache",
		];
		var curl = new sugoi.apis.linux.Curl();
		var result : Dynamic = null;
		var r = null;
		try{
			var rawResult = curl.call(methodName, serviceUrl, headers, params);

			if(rawResult != null && rawResult != ""){
				result = haxe.Json.parse(rawResult);
			}
			
		}catch(e:Dynamic){
			throw new Error( Std.string(e) + "\nraw result : " + Std.string(r) );
		}
		
		if( Reflect.hasField(result, "errors") ) {

			//something bad happened...
			var error : mangopay.Error = result;
			App.current.logError(result);
			throw TypedError.typed( 500 , error.Message , error );

		} else if ( exceptionOnResultCode && Reflect.hasField(result, "ResultCode") && result.ResultCode != null ) {
			var resultCode = Std.parseInt(result.ResultCode);
			if ( resultCode != 0) {
				App.current.logError(result);
				throw TypedError.typed(resultCode, result.ResultMessage, result);
			}
		}
		
		return result;

	}

	static public function getNaturalUser(mangopayUserId:Int) : NaturalUser {
		return callService("users/" + mangopayUserId + "/");
	}

	static public function getLegalUser(mangopayUserId:Int) : LegalUser {
		return callService("users/" + mangopayUserId + "/");
	}

	static public function createNaturalUser(user:db.User) : NaturalUser {
		var obj : NaturalUser = {
			Tag: "" + user.id,
			Email: user.email,
			FirstName: user.firstName,
			LastName: user.lastName,
			Address: null,
			Birthday: user.birthDate.getTime()/1000,
			Nationality: user.nationality,
			CountryOfResidence: user.countryOfResidence
		};
		if (user.zipCode != null && user.city != null && user.address1 != null && user.countryOfResidence != null) {
			obj.Address = {
			AddressLine1: user.address1,
			AddressLine2: user.address2,
			City: user.city,
			PostalCode: user.zipCode,
			Country: user.countryOfResidence
			};
		}
		var params = haxe.Json.stringify(obj);
		var naturalUser:NaturalUser = callService("users/natural/", "POST", params);
		var mangopayUser = new MangopayUser();
		mangopayUser.user = user;
		mangopayUser.mangopayUserId = naturalUser.Id;
		mangopayUser.insert();
		
		return naturalUser;
	}

	/**
		Get a user's wallet list
	**/
	static public function getUserWallets(mangopayUserId:String,page:Int,walletsPerPage:Int) : Array<Wallet> {
		var params  = {
			Page : page,
			Per_page : walletsPerPage,
			Sort : "CreationDate:DESC"
		};
		return callService("users/" + mangopayUserId + "/wallets/",haxe.Json.stringify(params));
	}

	/**
		Get or create a wallet for a user
	**/
	static public function getOrCreateUserWallet(mangopayUserId:String, group: db.Group) : Wallet {	
		
		var description = "Group: " + group.name;
		var groupId = Std.string(group.id);

		//potential BUG here : if user has more than 30 wallets , we wont see all of them !!
		//solution : WE NEED TO STORE THE WALLET ID LOCALLY
		var wallets : Array<Wallet> = Mangopay.getUserWallets(mangopayUserId,1,30);
		for ( wallet in wallets ) {
			if ( StringTools.replace(wallet.Tag, "GroupID: ", "" ) == groupId ) {
				return wallet;
			}
		}
		var wallet : Wallet = {
			Tag : "GroupID: " + groupId,
			Owners : [mangopayUserId],
			Description : description,
			Currency : "EUR"
		};
		var params = haxe.Json.stringify(wallet);
		return callService("wallets/", "POST", params);
	}

	/**
		Get or create a wallet for a group
	**/
	static public function getOrCreateGroupWallet(mangopayUserId:String, group:db.Group) : Wallet {	
		var conf = MangopayPlugin.getGroupConfig(group);
		if(conf==null) throw new Error("No wallet for group "+group.id);
		if(conf.walletId==null){
			
			conf.lock();

			//create wallet
			var wallet : Wallet = {
				Tag : "GroupID: " + group.id,
				Owners : [mangopayUserId],
				Description : "Group: " + group.name,
				Currency : "EUR"
			};
			wallet = callService("wallets/", "POST", haxe.Json.stringify(wallet));
			
			conf.walletId = wallet.Id;
			conf.update();
			return wallet;
		}else{
			return callService("wallets/"+conf.walletId, "GET");
		}
		
	}

	/**
		/!\ page is starting at 1
	**/
	static public function getWalletOperations(wallet:Wallet,resultPerPage:Int,page:Int,afterDate:Date,beforeDate:Date):Array<Transaction>{
		var beforeDate = beforeDate.getTime()/1000;
		var afterDate = afterDate.getTime()/1000;
		return callService('wallets/${wallet.Id}/transactions/?Per_Page=$resultPerPage&Page=$page&BeforeDate=$beforeDate&AfterDate=$afterDate');
	}

	static public function createCardWebPayIn(payIn:CardWebPayIn) : CardWebPayIn {
		var params = haxe.Json.stringify(payIn);
		return callService("payins/card/web/", "POST", params);
	}

	static public function getPayIn(payInId:String) : CardWebPayIn {
		return callService("payins/" + payInId + "/");
	}

	/**
	@doc https://docs.mangopay.com/endpoints/v2.01/transactions#e263_list-a-wallets-transactions

	WARNING : dates should be UTC not local time !!
	**/
	static public function getUserTransactions(mangopayUserId:String,resultPerPage:Int,page:Int,afterDate:Date,beforeDate:Date,type:TransactionType) : Array<Transaction> {
		var beforeDate = beforeDate.getTime()/1000;
		var afterDate = afterDate.getTime()/1000;
		var params = '?Per_Page=$resultPerPage&Page=$page&BeforeDate=$beforeDate&AfterDate=$afterDate&Type=$type';
		return callService('users/$mangopayUserId/transactions/$params',"GET");
	}

	/**
		https://docs.mangopay.com/endpoints/v2.01/refunds#e191_create-a-payin-refund
	**/
	static public function createPayInRefund(refund : Refund) : Refund {
		var params = haxe.Json.stringify(refund);
		return callService("payins/" + refund.InitialTransactionId + "/refunds/", "POST", params);
	}

	static public function getPayInRefunds(payInId:Int): Array<Refund> {
		return callService("payins/" + payInId + "/refunds");
	}

	static public function createTransfer(amount:Int, debitedWalletId:String, creditedWalletId:String, authorId:String) : Transfer {
		var tempTransfer : Transfer = {
			// ?Tag: String,
			DebitedFunds: {
				Currency: Euro,
				Amount: amount
			},
			Fees: {
				Currency: Euro,
				Amount: 0
			},
			DebitedWalletId: debitedWalletId,
			CreditedWalletId: creditedWalletId,
			AuthorId: authorId
		};
		var params = haxe.Json.stringify(tempTransfer);
		var transfer : Transfer = callService("transfers/", "POST", params);
		if (transfer.Status == Succeeded){
			return transfer;
		}else{
			throw new Error(transfer.ResultMessage);
		}
	}

	static public function createIBANBankAccount(mangopayUserId: Int, account: IBANBankAccount) : IBANBankAccount {
		account.Type = "IBAN";
		var params = haxe.Json.stringify(account);
		return callService("users/" + mangopayUserId + "/bankaccounts/iban/", "POST", params);
	}

	static public function getIBANBankAccount(mangopayLegalUser:MangopayLegalUser) : IBANBankAccount {		
		var allBankAccounts : Array<IBANBankAccount> = callService("users/" + mangopayLegalUser.mangopayUserId + "/bankaccounts/");
		return allBankAccounts.find( account -> account.Active==true && Std.string(account.Id) == Std.string(mangopayLegalUser.bankAccountId) );
	}

	static public function deactivateIBANBankAccount(mangopayUserId: Int, bankAccountId: String) : IBANBankAccount {
		var obj = { Active: false };
		var params = haxe.Json.stringify(obj);
		return callService("users/" + mangopayUserId + "/bankaccounts/" + bankAccountId + "/", "PUT", params);
	}

	/**
		Create Payout
	**/
	/*static public function createVendorPayOut(payout : PayOut, vendor : db.Vendor, multiDistribKey : String) : PayOut {

		var company = pro.db.CagettePro.getFromVendor(vendor);
		var params = haxe.Json.stringify(payout);
		var payOut : PayOut = callService("payouts/bankwire/", "POST", params);

		var mangopayPayOut = new MangopayVendorPayOut();
		mangopayPayOut.company = company;
		mangopayPayOut.payOutId = payOut.Id;
		mangopayPayOut.multiDistribKey = multiDistribKey;
		mangopayPayOut.reference = payOut.BankWireRef;
		mangopayPayOut.insert();

		return payOut;
	}*/

	/**
		Create a bankwire payout thru mangopay API and store a trace locally
	**/
	static public function createGroupPayOut(payout : PayOut, md : db.MultiDistrib) : PayOut {

		var payOut = callService("payouts/bankwire/", "POST", haxe.Json.stringify(payout));

		var mangopayPayOut = new MangopayGroupPayOut();
		mangopayPayOut.payOutId = payOut.Id;
		mangopayPayOut.cachedDatas = payOut;
		mangopayPayOut.multiDistrib = md;
		mangopayPayOut.insert();

		return payOut;
	}

	static public function getPayOut(payOutId:String) : PayOut {
		return callService("payouts/" + payOutId + "/",null,null,false);
	}

	/*static public function getUserKYCDocuments(mangopayUserId: Int) : Array<KYCDocument> {	
		return callService("users/" + mangopayUserId + "/kyc/documents/");
	}

	static public function getRequiredKYCDocumentTypes(legalStatus: LegalStatus) : Array<String> {
		if(legalStatus == null) throw new Error("Vous devez définir quel est votre type de structure");
		switch(legalStatus)
		{
			case Soletrader:
				return ["IDENTITY_PROOF", "REGISTRATION_PROOF"];

			case Organization:
				return ["IDENTITY_PROOF", "ARTICLES_OF_ASSOCIATION", "REGISTRATION_PROOF"];

			case Business:
				return ["IDENTITY_PROOF", "ARTICLES_OF_ASSOCIATION", "REGISTRATION_PROOF", "SHAREHOLDER_DECLARATION"];
		}
	}

	static public function getOrCreateKYCDocument(mangopayUserId: Int, type: String) : KYCDocument {
		var kycDocuments : Array<KYCDocument> = Mangopay.getUserKYCDocuments(mangopayUserId);
		for ( document in kycDocuments ) {
			if ( document.Type == type ) {
				return document;
			}
		}
		var document : KYCDocument = {
			Type: type
		};
		var params = haxe.Json.stringify(document);
		return callService("users/" + mangopayUserId + "/kyc/documents/", "POST", params);
	}*/

	static public function translate(str: String) {

		switch(str)
		{
			//KYC Documents
			case "IDENTITY_PROOF":
				return "Carte d'identité ou passeport";

			case "ARTICLES_OF_ASSOCIATION":
				return "Statuts signés";
			
			case "REGISTRATION_PROOF":
				return "Preuve d'enregistrement (ex : kbis de moins de 3 mois)";

			case "SHAREHOLDER_DECLARATION":
				return "Liste des actionnaires détenant plus de 25% de la société";

			//Status
			case "CREATED":
				return "Créé";

			case "VALIDATION_ASKED":
				return "En attente de validation";

			case "VALIDATED":
				return "Validé";

			case "REFUSED":
				return "Refusé";

			//KYC document refused reason
			case "DOCUMENT_UNREADABLE":
				return "Document illisible";

			case "DOCUMENT_NOT_ACCEPTED":
				return "Document pas accepté";

			case "DOCUMENT_HAS_EXPIRED":
				return "Document expiré";

			case "DOCUMENT_INCOMPLETE":
				return "Document incomplet";

			case "DOCUMENT_MISSING":
				return "Document manquant";

			case "DOCUMENT_DO_NOT_MATCH_USER_DATA":
				return "Document ne correspond pas à ce compte";
			
			case "DOCUMENT_DO_NOT_MATCH_ACCOUNT_DATA":
				return "Document ne correspond pas à ce compte";

			case "SPECIFIC_CASE":
				return "Cas particulier";

			case "DOCUMENT_FALSIFIED":
				return "Faux document";

			case "UNDERAGE_PERSON":
				return "Pesonne mineure";


			default:
				return str;
		};

	}

	public static function parsePayInError(payIn:CardWebPayIn):String{
		return switch(payIn.ResultCode)	{
			case "001001": //Unsufficient wallet balance
				"Solde insuffisant sur votre wallet.";

			case "001030": //User has not been redirected
				"Vous n'avez pas été redirigé(e) vers la page de paiement.";
			
			case "001031": //User canceled the payment
				"Vous avez annulé le paiement.";

			case "101002": //The transaction has been cancelled by the user
				"Vous avez annulé le paiement.";

			case "001032": //User is filling in the payment card details
				"Vous n'avez pas fini de remplir la page de paiements.";

			case "001033": //User has not been redirected then the payment session has expired
				"La session de paiement a expiré.";

			case "001034": //User has let the payment session expire without paying
				"La session de paiement a expiré.";

			case "101001": //The user does not complete transaction
				"Le paiement n'a pas été finalisé.";

			case "105101": //Invalid card number
				"Le numéro de carte que vous avez rentré est incorrect.";

			case "105102": //Invalid cardholder name
				"Le nom du propriétaire ne correspond pas à celui de la carte.";

			case "105103": //Invalid PIN code
				"Le code PIN que vous avez rentré est incorrect.";

			case "105104": //Invalid PIN format
				"Le format du code PIN que vous avez rentré est incorrect.";

			case "101101": //Transaction refused by the bank (Do not honor)
				"Le paiement a été refusé par votre banque. Veuillez contacter votre banque pour plus d'informations.";

			case "101102": //Transaction refused by the bank (Amount limit)
				"Le paiement a été refusé par votre banque à cause d'un plafond atteint. Veuillez contacter votre banque pour plus d'informations.";

			case "101103": //Transaction refused by the terminal
				"Le paiement a été refusé par le terminal.";

			case "101104": //Transaction refused by the bank (card limit reached)
				"Le paiement a été refusé par votre banque car le plafond de votre carte a été atteint. Veuillez contacter votre banque pour plus d'informations.";

			case "101105": //The card has expired
				"Votre carte est expirée.";

			case "101106": //The card is inactive
				"Votre carte est désactivée.";

			case "101110": //The payment has been refused
				"MANGOPAY a refusé le paiement.";

			case "101410": //The card is not active
				"Votre carte est désactivée.";

			case "101111": //Maximum number of attempts reached
				"Le nombre d'essais de paiement a été atteint.";

			case "101112": //Maximum amount exceeded
				"Le plafond de votre carte a été atteint.";

			case "101113": //Maximum Uses Exceeded
				"Trop de tentatives de paiement avec votre carte. Vous devez réessayer après 24 heures.";
			
			case "101115": //Debit limit exceeded
				"Le plafond de votre carte a été atteint.";

			case "101116": //Amount limit
				"La limite du montant a été atteinte.";

			case "101118": //An initial transaction with the same card is still pending
				"Un paiement en attente a déjà été fait avec cette carte.";

			case "101199": //Transaction refused
				"Le paiement a été refusé par votre banque. Veuillez contacter votre banque pour plus d'informations.";

			case "101399": //Secure mode: 3DSecure authentication is not available
				"L'authentification par 3DSecure n'est pas disponible.";

			case "101304": //Secure mode: The 3DSecure authentication session has expired
				"La session d'authentification 3DSecure a expiré.";
			
			case "101303": //Secure mode: The card is not compatible with 3DSecure
				"Votre carte n'est pas compatible avec 3DSecure.";
					
			case "101302": //Secure mode: The card is not enrolled with 3DSecure
				"Votre carte n'a pas le 3DSecure.";

			case "101301": //Secure mode: 3DSecure authentication has failed
				"L'authentification 3DSecure a échoué.";
			
			default :
				'#${payIn.ResultCode} - ${payIn.ResultMessage}';

		};
	}


	public static function getStatment(groupName:String){		
		var str = getMatches( ~/[a-zA-Z0-9]/ , groupName ).join("").substr(0,9);
		return " "+str;
	}

	/**
		return a ereg matches in an array
	**/
	static function getMatches(ereg:EReg, input:String, index:Int = 0):Array<String> {
		var matches = [];
		while (ereg.match(input)) {
		  matches.push(ereg.matched(index)); 
		  input = ereg.matchedRight();
		}
		return matches;
	  }

}