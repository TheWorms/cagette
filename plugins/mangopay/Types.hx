package mangopay;

@:enum
abstract TransactionStatus(String) {
  var Created = "CREATED";
  var Succeeded = "SUCCEEDED";
  var Failed = "FAILED";
}

@:enum
abstract TransactionType(String) {
  var Payin = "PAYIN";
  var Transfer = "TRANSFER";
  var Payout = "PAYOUT";
}

@:enum
abstract Currency(String) {
  var Euro = "EUR"; 
}

@:enum
abstract LegalStatus(String) {
  	var Soletrader = "SOLETRADER";
	var Organization = "ORGANIZATION";
	var Business = "BUSINESS"; 
}

typedef NaturalUser = {
	?Id: String, //string because int overflows
	?CreationDate: Float,
	?Tag: String,
	?PersonType: String,
	Email: String,
	?KYCLevel: String,
	FirstName: String,
	LastName: String,
	?Address: {
		AddressLine1: String,
		?AddressLine2: String,
		City: String,
		?Region: String,
		PostalCode: String,
		Country: String
	},
	Birthday: Float,
	Nationality: String,
	CountryOfResidence: String,
	?Occupation: String,
	?IncomeRange: Int,
	?ProofOfAddress: String,
    ?ProofOfIdentity: String,
	?Capacity: String,
	?errors: String
};

//@doc https://docs.mangopay.com/endpoints/v2.01/users#e259_create-a-legal-user
typedef LegalUser = {
	?Id: String,
	?CreationDate: Float,
	?Tag: String,
	?PersonType: String,//NATURAL or LEGAL
	Email: String,
	?KYCLevel: String,//LIGHT, REGULAR
	?HeadquartersAddress: {
		AddressLine1: String,
		?AddressLine2: String,
		City: String,
		?Region: String,
		PostalCode: String,
		Country: String
	},
	LegalPersonType: LegalStatus,//BUSINESS,ORGANIZATION,SOLETRADER
	Name: String,
	?LegalRepresentativeAddress: {
		AddressLine1: String,
		?AddressLine2: String,
		City: String,
		?Region: String,
		PostalCode: String,
		Country: String
	},
	LegalRepresentativeBirthday: Float,
	LegalRepresentativeCountryOfResidence: String,
	LegalRepresentativeNationality: String,
	?LegalRepresentativeEmail: String,
	LegalRepresentativeFirstName: String,
	LegalRepresentativeLastName: String,
	?LegalRepresentativeProofOfIdentity: String,
	?Statute: String,
	?ShareholderDeclaration: String,
	?ProofOfRegistration: String,
	?CompanyNumber: String
};

typedef Wallet = {
	?Id: String,
	?CreationDate: Float,
	?Tag: String,
	Owners: Array<String>, //userId are strings
	?Balance:Money,
	?FundsType: String,
	Description: String,
	Currency: String
};
 
typedef CardWebPayIn = {
	?Id: String,
	?CreationDate: Float,
	?Tag: String,
	DebitedFunds	: Money,
	?CreditedFunds	: Money,
	Fees			: Money,
	?DebitedWalletId: String,
	CreditedWalletId: String,
	AuthorId: String,
	?CreditedUserId: String,
	?Nature: String,
	?Status: TransactionStatus,
	?ExecutionDate: Float,
	?ResultCode: String,
	?ResultMessage: String,
	?Type: String,
	?PaymentType: String,
	?ExecutionType: String,
	ReturnURL: String,
	CardType: String,
	?SecureMode: String,
	Culture: String,
	?TemplateURL: String,
	?StatementDescriptor: String,
	?RedirectURL: String
};

typedef Transaction = {
	Id: String,
	CreationDate: Float,
	Tag: String,
	DebitedFunds : Money,
	CreditedFunds: Money,
	Fees: Money,
	DebitedWalletId : String,
	CreditedWalletId: String,
	AuthorId: String,
	CreditedUserId: String,
	Nature : String,
	Status: TransactionStatus,
	ExecutionDate: Float,
	ResultCode : String,
	ResultMessage: String,
	Type: TransactionType
}

typedef Refund = {
	?Id: String,
	?CreationDate: Float,
	?Tag: String,
	?DebitedFunds:Money,
	?CreditedFunds:Money,
	?Fees:Money,
	?DebitedWalletId: String,
	?CreditedWalletId: String,
	AuthorId: String,
	?CreditedUserId: String,
	?Nature: String,
	?Status: String,
	?ExecutionDate: Float,
	?ResultCode: String,
	?ResultMessage: String,
	?Type: String,
	InitialTransactionId: String,
	?InitialTransactionType: String,
	?RefundReason: {
		RefusedReasonType: String,
		RefusedReasonMessage: String
	}
};

typedef Transfer = {
	?Id: String,
	?CreationDate: Float,
	?Tag: String,
	DebitedFunds:Money,
	?CreditedFunds:Money,
	Fees: Money,
	DebitedWalletId: String,
	CreditedWalletId: String,
	AuthorId: String,
	?CreditedUserId: String,
	?Nature: String,
	?Status: TransactionStatus,
	?ExecutionDate: Float,
	?ResultCode: String,
	?ResultMessage: String,
	?Type: String
};

typedef IBANBankAccount = {
	?Id: String,
	?CreationDate: Float,
	?Tag: String,
	?Type: String,
	OwnerAddress: {
		AddressLine1: String,
		?AddressLine2: String,
		City: String,
		?Region: String,
		PostalCode: String,
		Country: String
	},
	OwnerName: String,
	?UserId: String,
	?Active: Bool,
	IBAN: String,
	?BIC: String
};

typedef PayOut = {
	?Id: String,
	?CreationDate: Float,
	?Tag: String,
	DebitedFunds:Money,
	?CreditedFunds: Money,
	Fees: Money,
	DebitedWalletId: String,
	?CreditedWalletId: String,
	AuthorId: String,
	?CreditedUserId: String,
	?Nature: String,
	?Status: TransactionStatus,
	?ExecutionDate: Float,
	?ResultCode: String,
	?ResultMessage: String,
	?Type: String,
	BankAccountId: String,
	BankWireRef: String,
	?PaymentType: String	
};

/*typedef KYCDocument = {
	?Id: String,
	?CreationDate: Float,
	?Tag: String,
	?UserId: Int,
	Type: String,
	?Status: String,
	?RefusedReasonMessage: String,
	?RefusedReasonType: String,
	?ProcessedDate: Float
};*/

typedef Error = {
  Message: String,
  Type: String,
  Id: String,
  Date: Float,
  errors: Dynamic,
  /*"errors" : {
    "Currency": "The code XPX cannot be found in the standard ISO 4217 : http://en.wikipedia.org/wiki/ISO_4217"
  }*/
};

typedef Money = {
	Currency : Currency,
	Amount : Int
}

/*typedef UBODeclaration = {
	Id : String,
	UserId : Int,
	Status : String,
	Reason : String,
	Message : String,
	Ubos : Array<UBO>,
}

typedef UBO = {
	Id : String,
	FirstName : String,
	LastName : String,
}*/
