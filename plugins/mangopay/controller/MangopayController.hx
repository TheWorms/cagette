package mangopay.controller;
import Common;
import pro.payment.*;
import mangopay.*;
import mangopay.db.*;
import mangopay.Types;
import sugoi.form.elements.*;
import sugoi.form.elements.NativeDatePicker.NativeDatePickerType;
import sugoi.tools.Utils;
import haxe.crypto.Base64;
import db.Operation;
using tools.ObjectListTool;

/**
 * Mangopay payment controller
 * @author web-wizard,fbarbut
 */
class MangopayController extends controller.Controller
{
	/**
		Mangopay payment entry point	
	 */
	@tpl("plugin/pro/transaction/mangopay/pay.mtt")
	public function doDefault(type:String, tmpBasket:db.TmpBasket){
		
		// throw Error("/","Les paiements en ligne par Mangopay sont fermés pour une période indéterminée (panne chez Mangopay). ");

		var url = sugoi.Web.getURI();
		
		//check
		var product = db.Product.manager.get(tmpBasket.getData().products[0].productId,false);
		if( product.catalog.group.id != app.getCurrentGroup().id ) throw "Cette commande ne correspond pas au groupe dans lequel vous êtes actuellement.";
		
		var user = App.current.user;

		//If one of these fields is null ask the user to specify them for Mangopay requirements
		if(user.birthDate == null || user.nationality == null || user.countryOfResidence == null || user.tosVersion==null)
		{
			var bd = if(user.birthDate==null) new Date(1970,0,1,0,0,0) else user.birthDate;

			var form = new sugoi.form.Form("mangopaydata");
			form.addElement(new form.CagetteDatePicker("birthday", "Date de naissance", bd, true,"","year"));
			form.addElement(new StringSelect("nationality", "Nationalité", db.User.getNationalities(), user.nationality, true));
			form.addElement(new StringSelect("countryOfResidence", "Pays de résidence", db.Place.getCountries(), user.countryOfResidence, true));
			var tosMsg = "J'accepte les <a href='/cgu' target='_blank'>conditions générales d'utilisation</a> 
			de Cagette.net et de <a href='/mgp' target='_blank'>Mangopay</a>";
			form.addElement(new Checkbox("tos", tosMsg, user.tosVersion!=null, true));

			if (form.isValid()) {

				//Check that the user is at least 18 years old
				if(!service.UserService.isBirthdayValid(form.getValueOf("birthday"))) {
					throw Error(url, "Merci de bien vouloir rentrer votre date de naissance. Vous devez avoir au moins 18 ans.");
				}

				if(form.getValueOf("tos")!=true){
					throw Error(url, "Vous devez accepter les conditions générales d'utilisation.");
				}
			
				app.user.lock();
				app.user.birthDate = form.getValueOf("birthday");
				app.user.nationality = form.getValueOf("nationality");
				app.user.countryOfResidence = form.getValueOf("countryOfResidence");
				app.user.tosVersion = sugoi.db.Variable.getInt("tosVersion");
				app.user.update();
				throw Ok(url, t._("Your account has been updated"));
			}

			view.form = form;
			return;
		}

		//If the user doesn't exist already in the mapping table it means that 
		//we haven't created yet a natural user in Mangopay
		var mangopayUser = MangopayUser.get(user);
		var naturalUserId:String = null;
		if(mangopayUser == null) {
			try{
				naturalUserId = Mangopay.createNaturalUser(user).Id;	
			}catch(e:tink.core.Error){
				throw Error("/transaction/pay/", "Erreur de création de compte Mangopay. "+e.message);
			}		
		} else {
			naturalUserId = mangopayUser.mangopayUserId;
		}

		//Create a wallet for this group if there is none for it
		var wallet : Wallet = null;
		if(type==pro.payment.MangopayECPayment.TYPE){
			//e-commerce : we put the money directly in the group wallet
			var legalUserId = MangopayPlugin.getGroupLegalUserId(app.user.getGroup());
			wallet = Mangopay.getOrCreateGroupWallet(legalUserId, user.getGroup());
		}else if (type==pro.payment.MangopayMPPayment.TYPE){
			//marketplace : we put the money in a user-group wallet
			wallet = Mangopay.getOrCreateUserWallet(naturalUserId, user.getGroup());
		}else{
			throw new tink.core.Error("payment type should be either mangopay-ec or mangopay-mp");
		}
		
		// Creating a Card Web PayIn for the buyer
		var group = app.user.getGroup();
		var conf = MangopayPlugin.getGroupConfig(group);
		var amount = MangopayPlugin.getAmountAndFees( tmpBasket.getTotal() , conf);
		var host = App.config.DEBUG ? "http://" + App.config.HOST : "https://" + App.config.HOST;

		var payIn : CardWebPayIn = {
			Tag: tmpBasket.ref,
			StatementDescriptor : Mangopay.getStatment(group.name),
			DebitedFunds: {
				Currency: 	Euro,
				Amount: 	Math.round(amount.amount * 100),
			},
			Fees: {
				Currency: 	Euro,
				Amount: 	Math.round(amount.fees * 100),
			},
			CreditedWalletId: wallet.Id,
			AuthorId: naturalUserId,
			ReturnURL: host+"/p/pro/transaction/mangopay/return/"+type+"/"+tmpBasket.id,
			CardType: "CB_VISA_MASTERCARD",
			Culture: "FR"
		};
		var cardWebPayIn : CardWebPayIn = Mangopay.createCardWebPayIn(payIn);
		throw Redirect(cardWebPayIn.RedirectURL);

	}

	/**
	 * Return/success URL
	 */
	@tpl("plugin/pro/transaction/mangopay/status.mtt")
	public function doReturn(type:String,tmpBasket:db.TmpBasket, args : { transactionId:String }){

		// if(App.config.DEBUG) throw "DEBUG : fake mangopay error";

		//Lock tmpBasket from the start ! otherwise there is a risk of double operation in Cagette.
		tmpBasket.lock();

		var payIn : CardWebPayIn = null;
		view.tmpBasket = tmpBasket;
		
		try{

			payIn = Mangopay.getPayIn(args.transactionId);

		}catch(e:tink.core.Error){

			//errors will be notified thru exceptions
			view.status = "error";
			payIn = e.data;
			view.errormessage = Mangopay.parsePayInError(payIn);
			return;
		}

		if (payIn.Status == Succeeded){
			view.status = "success";
			MangopayPlugin.processOrder(tmpBasket,payIn,type);
		}else{
			view.status = "error";
			view.errormessage = Mangopay.parsePayInError(payIn);			
		}
	}

	/**
	Form to add an IBAN Bank account in cpro
	**/
	@tpl('plugin/pro/company/mangopaybankaccount.mtt')
	public function doVendorBankAccount(){
		
		view.navbar = nav("company");
		view.nav = ["company","mangopay-vendor-account"];

		var company = pro.db.CagettePro.getCurrentCagettePro();
		var form = new sugoi.form.Form("mangopaybankaccount");
		form.addElement(new StringInput("ownerName", "Nom du propriétaire", company.vendor.name, true));
		form.addElement(new StringInput("address1", "Adresse 1", company.vendor.address1, true));
		form.addElement(new StringInput("address2", "Adresse 2", company.vendor.address2, true));
		form.addElement(new StringInput("city", "Ville", company.vendor.city, true));
		form.addElement(new StringInput("postalcode", "Code postal", company.vendor.zipCode, true));
		form.addElement(new StringSelect("country", "Pays", db.Place.getCountries(), "FR", true));
		form.addElement(new StringInput("iban", "IBAN", "", true));
		form.addElement(new StringInput("bic", "BIC", "", false));

		if (form.isValid()) {

			var bankAccount : IBANBankAccount = {
				OwnerAddress: {
					AddressLine1: form.getValueOf("address1"),
					AddressLine2: form.getValueOf("address2"),
					City: form.getValueOf("city"),
					PostalCode: form.getValueOf("postalcode"),
					Country: form.getValueOf("country")
				},
				OwnerName: form.getValueOf("ownerName"),
				IBAN: form.getValueOf("iban"),
				BIC: form.getValueOf("bic")
			};

			/*var mangopayCompany = MangopayCompany.get(pro.db.CagettePro.getCurrentCagettePro());
			try
			{
				var ibanBankAccount : IBANBankAccount = Mangopay.createIBANBankAccount(mangopayCompany.mangopayUserId, bankAccount);
				if (ibanBankAccount.Active == true)
				{
					throw Ok("/p/pro/transaction/mangopay/vendorKyc", "Votre compte bancaire a bien été ajouté.");
				}
			}
			catch(e : tink.core.Error)
			{
				var IBAN : String = e.data.errors.IBAN;
				var BIC : String = e.data.errors.BIC;
				
				if (IBAN != null && IBAN.indexOf("regular expression") != -1)
				{
					if (BIC != null && BIC.indexOf("regular expression") != -1)
					{
						throw Error("/p/pro/transaction/mangopay/vendorBankAccount", "Votre IBAN et BIC sont incorrects.");
					}
					else 
					{
						throw Error("/p/pro/transaction/mangopay/vendorBankAccount", "Votre IBAN est incorrect.");
					}
				}
				else if (BIC != null && BIC.indexOf("regular expression") != -1)
				{
					throw Error("/p/pro/transaction/mangopay/vendorBankAccount", "Votre BIC est incorrect.");
				}

				throw e;
			}*/		 
		}

		view.form = form;
		
	}

	function doGroup(d:haxe.web.Dispatch){
		d.dispatch(new mangopay.controller.MangopayGroupController());
	}

	

	

	function print(txt:String){
		Sys.println(txt+"<br/>");
	}
}