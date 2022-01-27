package mangopay;
import Common;
import db.MultiDistrib;
import mangopay.Mangopay;
import mangopay.Types;
import mangopay.db.*;
import payment.OnTheSpotCardTerminal;
import pro.payment.*;
import sugoi.plugin.*;
import sugoi.tools.TransactionWrappedTask;
import tink.core.Error;

class MangopayPlugin extends PlugIn implements IPlugIn{
	
	public function new() {
		super();
		name = "mangopay";
		file = sugoi.tools.Macros.getFilePath();
		initi18n();
		
		//suscribe to events
		App.current.eventDispatcher.add(onEvent);
	}
	
	public function initi18n(){
		//add i18n strings
		var i18n = App.t.getStrings();
		i18n.set("mangopay","Carte bancaire - Mangopay");
		
	}
	
	public function onEvent(e:Event) {
		
		switch(e) {
			//Add Lemonway config in group admin
			case Nav(nav,name,id) :				
				switch(name) {
					case "company":
						//Mangopay-marketplace for cagette pro
						//nav.push({id: "mangopay-vendor-wallet", name: "Paiements", link: "/p/pro/transaction/mangopay/vendorWallet"});
						//nav.push({id: "mangopay-vendor-kyc", name: "Justificatifs Mangopay", link: "/p/pro/transaction/mangopay/vendorKyc"});	

					case "groupAdmin":
						//Mangopay-ec for groups
						var groupConf = MangopayPlugin.getGroupConfig(App.current.user.getGroup());
						if(  groupConf!= null ) {							
							nav.push({id: "mangopay-kyc", 	name: "Dossier Mangopay", link:"/p/pro/transaction/mangopay/group/module",icon:"book"});
							nav.push({id: "mangopay-wallet",name: "Paiements Mangopay", 	link:"/p/pro/transaction/mangopay/group/wallet",icon:"bank-transfer"});				
						}else{
							nav.push({id: "mangopay-setup",name: "Paiement en ligne", 	link:"/p/pro/transaction/mangopay/group/module", icon:"bank-card"});				
						}
				}

			case HourlyCron(now):
				
				//check tmpBaskets ( bug de brigitte )
				var task = new TransactionWrappedTask("Check unvalidated tmpBaskets (bug de brigitte)");
				task.setTask(function(){
					var range = tools.DateTool.getLastHourRange( now );
					//from -30mn to -1h30
					range.from = DateTools.delta( range.from, -1000.0*60*30 );
					range.to = DateTools.delta( range.to, -1000.0*60*30 );
						
					task.log('TmpBaskets created from ${range.from} to ${range.to}');
					var baskets = db.TmpBasket.manager.search($cdate >= range.from && $cdate < range.to, true);
					for( b in baskets ){
						var orders = checkTmpBasket(b);
						if(orders!=null) task.log("basket #"+orders[0].basket.id+" fixed !");
					}
	
					//delete tmpBaskets older than 1 month
					db.TmpBasket.manager.delete($cdate < DateTools.delta(Date.now(),-1000.0*60*60*24*30) );
				});
				task.execute(!App.config.DEBUG);
				
				


			//Add Manngopay in payment types
			case GetPaymentTypes(data) :
				var groupConf = getGroupConfig(App.current.getCurrentGroup());
				if(  groupConf!= null && groupConf.legalUser.disabled==false ) {				
					data.types.push(new pro.payment.MangopayECPayment());
				}

			//Transfer money to vendors when a user's basket is validated
			case ValidateBasket(basket) :

				return;

				/*
				if( !MangopayPlugin.hasOnlyMangopayPayments(basket) ) {
					return;
				}

				basket.lock();
				//get amounts to dispatch for this basket : Map with vendorId -> AmountToPay
				var amountDispatchByVendorId = MangopayPlugin.getVendorsPaymentDispatch(basket);

				//get vendors who are ready to accept Mangopay
				for(vendorId in amountDispatchByVendorId.keys()) {

					//find cpro account
					var vendor = db.Vendor.manager.get(vendorId,false);
					var company = findCompany(vendor);
					//Let's check that the vendor has already a Mangopay user
					var mangopayCompany = MangopayCompany.get(company);
					if(company != null && mangopayCompany != null){
						
						//do the transfer for the vendor vendorId
						var d = amountDispatchByVendorId[vendorId];
						// Sys.println(vendor.name + " should be paid " + amount + " €");
						
						var mangopayUser = MangopayUser.get( basket.getUser() );
						if(mangopayUser==null){
							throw new tink.core.Error("This user should have a Mangopay user");
						}
						
						var group = basket.getGroup();
						var userWallet : Wallet = Mangopay.getOrCreateWallet(mangopayUser.mangopayUserId, group);
						var companyWallet : Wallet = Mangopay.getOrCreateWallet(mangopayCompany.mangopayUserId, group );
						mangopay.Mangopay.createTransfer(Math.round(d.netAmount * 100), userWallet.Id, companyWallet.Id, mangopayUser.mangopayUserId);
						
						//store shared revenues infos
						basket.data = amountDispatchByVendorId;
						basket.update();
						
					}
				}*/

			case PreRefund(form,basket,refundAmount) :
				//the form to refund a payment operation

				if (hasOnlyMangopayPayments(basket)) {
					var t = sugoi.i18n.Locale.texts;
					
					//hide amount field
					var amount : sugoi.form.elements.FloatInput = cast form.getElement("amount");
					amount.inputType = ITHidden;
					form.addElement(new sugoi.form.elements.Html("amounthtml", Std.string(refundAmount) + " €", t._("Amount")));

					//payment type is only mangopay
					form.removeElementByName("Mtype");
					var mp = new pro.payment.MangopayECPayment();
					var el = new sugoi.form.elements.StringSelect("Mtype", t._("Payment type"), [{label: mp.name, value: mp.type}], mp.type,true);
					form.addElement(el);
					
				}

			case Refund(operation,basket) : 
				if (hasOnlyMangopayPayments(basket)) {

					
					var mangopayUser = MangopayUser.get(basket.getUser());
					if( mangopayUser == null ) throw "This user should have a Mangopay user ID";

					//We sort the payments operations by payment amounts so that we can refund first on the biggest amount
					var sortedPaymentsOperations = basket.getPaymentsOperations().array();
					sortedPaymentsOperations.sort(function(a, b): Int {
						if (a.amount < b.amount) return 1;
						else if (a.amount > b.amount) return -1;
						return 0;
					});

					//Let's do the refund on different payments if needed
					var refundRemainingAmount = Math.abs(operation.amount);
					var totalRefunded = 0.0;
					for ( payment in sortedPaymentsOperations ) {
						var amountToRefund = 0.0;
						if ( refundRemainingAmount == 0.0 ) break;
						
						if ( refundRemainingAmount <= payment.amount ) {
							//Partial Refund
							amountToRefund = refundRemainingAmount;
						} else {
							//Full Refund						
							amountToRefund = payment.amount;						
						}
						refundRemainingAmount -= amountToRefund;	

						//Let's do the refund for this payment
						var conf = getGroupConfig(basket.getGroup());
						var amount = getAmountAndFees(amountToRefund,conf);
						var refund : Refund = {				
							DebitedFunds: {				
								Currency: Euro,
								Amount: Math.round(amount.netAmount * 100)		
							},
							Fees: {				
								Currency: Euro,
								Amount: 0 - Math.round(amount.fees * 100),//negative : refund fees
							},
							AuthorId: mangopayUser.mangopayUserId,
							InitialTransactionId: payment.getPaymentData().remoteOpId				
						};				
						refund = Mangopay.createPayInRefund(refund);
						totalRefunded += amountToRefund;

						//create one operation for each refund
						var op  = new db.Operation();
						op.type = db.Operation.OperationType.Payment;
						op.setPaymentData({type:operation.getPaymentData().type,remoteOpId: refund.Id.string()});
						op.name = operation.name+ ' (${refund.Id})';
						op.group = operation.group;
						op.user = operation.user;
						op.relation = operation.relation;
						op.amount = 0 - Math.abs(amountToRefund);						
						op.date = Date.now();
						op.insert();
					}

					//delete initial operation
					operation.delete();					

					App.current.session.addMessage("Le remboursement par carte bancaire a été demandé.");
				}

			case PreOperationDelete(op) :
				//cannot delete a bank card payment op	
				var type = op.getPaymentType();
				if ( type == MangopayECPayment.TYPE || type == MangopayMPPayment.TYPE ){
					throw sugoi.ControllerAction.ErrorAction("/member/payments/" + op.user.id, "Vous ne pouvez pas effacer un paiement ou remboursement par carte bancaire." );
				}

			case PreOperationEdit(op) :
				//cannot edit a bank card payment op, unless the user is admin
				var type = op.getPaymentType();
				if ( !App.current.user.isAdmin() && (type == MangopayECPayment.TYPE || type == MangopayMPPayment.TYPE) ){
					throw sugoi.ControllerAction.ErrorAction("/member/payments/" + op.user.id, "Vous ne pouvez pas modifier un paiement ou remboursement par carte bancaire." );
				}	

			case PreDeleteMultiDistrib(md):
				//cannot delete a multidistrib if mangopay payments have been made
				
				for( b in md.getBaskets()){

					for( payment in b.getPaymentsOperations()){
						if(payment.getPaymentType()==MangopayECPayment.TYPE || payment.getPaymentType()==MangopayMPPayment.TYPE){
							throw new tink.core.Error("Vous ne pouvez pas effacer cette distribution, car elle contient des commandes avec paiement par carte bancaire");
						}
					}
					
				}

			default :
				//

		}
		
	}

	public static function hasOnlyMangopayPayments(basket : db.Basket) : Bool {
		var payments = basket.getPaymentsOperations();
		var mangopayPayments = [];
		for( payment in payments) {
			if(payment.getPaymentType() == MangopayMPPayment.TYPE || payment.getPaymentType() == MangopayECPayment.TYPE){
				mangopayPayments.push(payment);
			}
		}

		if(mangopayPayments.length == 0) {
			return false;
		} else if( mangopayPayments.length == payments.length) {
			return true;
		} else {				
			throw "Ce panier a été partiellement payé avec Mangopay et d'autres moyen de paiement ! "+payments.length+"/"+mangopayPayments.length;			
		}
	}

	public function findCompany(vendor:db.Vendor):pro.db.CagettePro{
		return pro.db.CagettePro.getFromVendor(vendor);
	}


	/**
	*	Get the vendors dispatch for a distributed payment for a given basket (needed for marketplace payments)
	**/
	public static function getVendorsPaymentDispatch(basket:db.Basket):Map<Int,RevenueAndFees> {
		// vendorId -> amount to transfer
		var amountDispatchByVendorId = new Map<Int,RevenueAndFees>();

		for( order in basket.getOrders())
		{
			var vendorId = order.product.catalog.vendor.id;
			var amount = order.quantity * order.productPrice;
			
			//manage amount
			if(amountDispatchByVendorId[vendorId] == null){
				amountDispatchByVendorId[vendorId] = {amount:amount,netAmount:null,fixedFees:null,variableFees:null};
			}else{
				amountDispatchByVendorId[vendorId].amount += amount;
			}
		}

		//manage netAmount and fees
		var conf = getGroupConfig(basket.getGroup());
		var fixedFeesMap = computeFixedFees(amountDispatchByVendorId,basket);

		for( vendorId in amountDispatchByVendorId.keys()){
			var data = amountDispatchByVendorId[vendorId];
			data.variableFees = round(data.amount * conf.legalUser.variableFeeRate );
			data.fixedFees = fixedFeesMap[vendorId];
			data.netAmount = round(data.amount - data.variableFees - data.fixedFees);
		}

		return amountDispatchByVendorId;
	}

	/**
		Returns a map containing shared fixed fees between vendors
	**/
	public static function computeFixedFees(dispatch:Map<Int,RevenueAndFees>,basket:db.Basket):Map<Int,Float>{
		var feesMap = new Map<Int,Float>();

		var total = 0.0;
		for(v in dispatch){
			total+=v.amount;
		}

		var conf = getGroupConfig(basket.getGroup());

		//as much fixed fee as payment operations
		var paymentOpNum = Lambda.count(basket.getPaymentsOperations());
		var totalFee = paymentOpNum * conf.legalUser.fixedFeeAmount;
		var remain :Float = paymentOpNum * conf.legalUser.fixedFeeAmount;

		//dispatch
		for( k in dispatch.keys()){
			var fee = round( totalFee * (dispatch[k].amount / total) );
			remain -= fee;
			feesMap[k] = fee;
		}

		//assign remaining cents to the biggest seller 
		var higher = null;
		for( k in dispatch.keys()){
			if(higher==null || dispatch[k].amount > dispatch[higher].amount){
				higher = k;
			}
		}

		feesMap[higher] += remain;

		return feesMap;
	}


	static function round(f:Float):Float{
		return Math.round(f*100)/100;
	}

	/**
		Get multidistrib net MP turnover ( payments made with MP less fees )
	**/
	static public function getMultidistribNetTurnover(md:MultiDistrib):Float{		
		var total = 0.0;
		var conf = getGroupConfig(md.getGroup());
		for( b in md.getBaskets() ){
			for( op in b.getPaymentsOperations() ){
				if( op.getPaymentType() == MangopayECPayment.TYPE ){					
					total += getAmountAndFees(op.amount,conf).netAmount;
				}
			}
		}
		return total;
	}

	/**
		Get net amount and fees from raw amount
		rounding at the right place is very important !
	**/
	static public function getAmountAndFees(_amount:Float, conf:mangopay.db.MangopayLegalUserGroup):{amount:Float,netAmount:Float,fees:Float}{
		var amount = round(_amount);
		var fees = round( conf.legalUser.fixedFeeAmount + ( Math.abs(amount) * conf.legalUser.variableFeeRate ) );
		//if amount is negative, its a refund, thats why we add fees to the negative amount.
		return {
			amount 		: amount,
			netAmount	: amount>0 ? amount - fees : amount + fees,
			fees 		: fees,
		};
	}
	

	/**
		Get multidistrib turnover details for a group ( justificatifs )
	**/
	static public function getMultiDistribDetailsForGroup(md:MultiDistrib){

		var conf = MangopayPlugin.getGroupConfig(md.getGroup());
		var out  = {
			mpTurnover 			: {ht:0.0,ttc:0.0},
			mpFixedFeeAmount 	: conf==null ? null : conf.legalUser.fixedFeeAmount,
			mpVariableFeeRate 	: conf==null ? null : conf.legalUser.variableFeeRate,
			mpFixedFees			: {ht:0.0,ttc:0.0},
			mpVariableFees		: {ht:0.0,ttc:0.0},
			//other payment types
			cashTurnover 		: {ht:0.0,ttc:0.0},
			checkTurnover 		: {ht:0.0,ttc:0.0},
			checkNumber : 0,
			transferTurnover 	: {ht:0.0,ttc:0.0},
			cardTerminalTurnover: {ht:0.0,ttc:0.0},
			onTheSpotTurnover 	: {ht:0.0,ttc:0.0},
			total				: {ht:0.0,ttc:0.0}
		};

		for( b in md.getBaskets() ){
			for( op in b.getPaymentsOperations() ){
				switch( op.getPaymentType() ){

					case payment.Cash.TYPE : 
						out.cashTurnover.ttc += op.amount;

					case payment.Check.TYPE : 
						out.checkTurnover.ttc += op.amount;
						out.checkNumber ++;

					case payment.Transfer.TYPE :
						out.transferTurnover.ttc += op.amount;
					
					case payment.OnTheSpotCardTerminal.TYPE:
						out.cardTerminalTurnover.ttc += op.amount;

					case payment.OnTheSpotPayment.TYPE :
						out.onTheSpotTurnover.ttc += op.amount;
						//throw new Error("A validated distribution should not contain undefined 'on the spot' payments.");

					case payment.MoneyPot.TYPE : 
					//do nothing

					case MangopayECPayment.TYPE,MangopayMPPayment.TYPE :
						//IMPORTANT D'ARRONDIR sinon décalage avec MP !
						out.mpTurnover.ttc += round(  op.amount );
						out.mpFixedFees.ttc += round( conf.legalUser.fixedFeeAmount );
						out.mpVariableFees.ttc += round( op.amount * conf.legalUser.variableFeeRate );
				}
			}
		}

		//total ttc
		out.total.ttc += out.cashTurnover.ttc;
		out.total.ttc += out.checkTurnover.ttc;
		out.total.ttc += out.transferTurnover.ttc;
		out.total.ttc += out.mpTurnover.ttc;
		out.total.ttc += out.cardTerminalTurnover.ttc;
		out.total.ttc -= out.mpFixedFees.ttc;
		out.total.ttc -= out.mpVariableFees.ttc;

		return out;
	}


		/*var legalRep = group.legalRepresentative;
		if(legalRep == null) {
			throw new Error("Vous devez définir un représentant légal dans les propriétés du groupe.");
		}

		if(legalRep.countryOfResidence == null || legalRep.birthDate == null || legalRep.nationality == null){
			throw new Error("Le représentant légal doit spécifier son pays de résidence, date d'anniversaire et nationalité");
		}

		if(group.legalStatus==null){
			throw new Error("Vous devez définir le statut légal de la structure qui collecte les paiements pour ce groupe Cagette (dans les propriétés du groupe).");
		}
	}*/

	/**
		Check Bug de Brigitte 
		( Quand un paiement mangopay est validé, mais que cagette n'a pas reçu le callback 
		et n'a donc pas transformé le tmpBasket en vraie commande )
	**/
	public static function checkTmpBasket(tmpBasket:db.TmpBasket):Array<db.UserOrder>{

		var mpUser = mangopay.db.MangopayUser.get(tmpBasket.user);
		var conf = getGroupConfig(tmpBasket.multiDistrib.getGroup());
		if(mpUser!=null && conf!=null && conf.legalUser.disabled==false){
			//time range : from 24h ago to now+10mn
			//warning, dates in mangopay are in UTC, so it may be 1 or 2 hours behind french time.
			var to   = DateTools.delta(Date.now(), 1000.0 * 60 * 10);//in case of offset system clock
			var from = DateTools.delta(Date.now(), 1000.0 * 60 * 60 * 24 * -1 );
			var mpOps = Mangopay.getUserTransactions(mpUser.mangopayUserId,20,1,from,to,mangopay.Types.TransactionType.Payin);
			var lastOps = db.Operation.getLastOperations(tmpBasket.user,tmpBasket.multiDistrib.getGroup(),50);

			for( mpOp in mpOps){
				//find related operation in Cagette
				var found = false;
				if(mpOp.Type==TransactionType.Payin && mpOp.Status==TransactionStatus.Succeeded){
					var mpOp : CardWebPayIn = cast mpOp;
					//this a succeeded payin
					for (op in lastOps ){
						if(op.getPaymentType()==pro.payment.MangopayECPayment.TYPE || op.getPaymentType()==pro.payment.MangopayMPPayment.TYPE){
							//its a mangopay payment
							if(Std.string(mpOp.Id) == op.getPaymentData().remoteOpId){
								//trace("related op found");
								found = true;
								break;
							}
						}
					}
					if(!found){
						//we have no operation in Cagette for this succeeded payin.
						//check if amount is equal
						var mpOpAmount = Std.string(Formatting.roundTo(mpOp.DebitedFunds.Amount/100,2));
						var tmpBasketAmount = Std.string(Formatting.roundTo( tmpBasket.getTotal() , 2));
						var amountEqual = mpOpAmount == tmpBasketAmount;

						//check if credittedWalletId is the wallet id of this group
						var credittedWalletOk = Std.string(mpOp.CreditedWalletId) == Std.string(conf.walletId);

						if(amountEqual && credittedWalletOk){

							//find which Mp payment type is enabled in this group
							var paymentTypes = service.PaymentService.getPaymentTypes(PCPayment,tmpBasket.multiDistrib.getGroup());
							
							var mp_type = Lambda.find(paymentTypes, function(pt) return pt.type==pro.payment.MangopayECPayment.TYPE || pt.type==pro.payment.MangopayMPPayment.TYPE );
							
							if(mp_type==null){
								throw 'unable to find MPpayement among '+paymentTypes.map(p -> return p.type)+' for tmpBasket '+tmpBasket.id;
							}

							//OK, process order !
							return processOrder( tmpBasket , mpOp , mp_type.type );

						}

					}

				}

			} 
		}

		return null;
	}


	/**
	 * Confirm order
	 */
	public static function processOrder( tmpBasket:db.TmpBasket , payIn:CardWebPayIn , paymentType:String ):Array<db.UserOrder>{
		
		if(paymentType!=pro.payment.MangopayECPayment.TYPE && paymentType!=pro.payment.MangopayMPPayment.TYPE){
			throw new Error("The payment type should be either mangopay-ec or mangopay-mp");
		}
		
		//create real orders
		var transactionId = payIn.Id;
		var total = payIn.DebitedFunds.Amount/100;
		var md = tmpBasket.multiDistrib;
		var user = tmpBasket.user;
		var date = md.getDate();
		var place = md.getPlace();
		var group = md.getGroup();
		var orders = service.OrderService.confirmTmpBasket(tmpBasket);
		
		//create debt operations
		var orderOps = service.PaymentService.onOrderConfirm(orders);
			
		//create payment operations
		//all orders are for the same multidistrib			
		var op = service.PaymentService.makePaymentOperation(
			user,
			group,
			paymentType,
			total,
			'Paiement CB pour commande du ${Formatting.hDate(date)} (${transactionId})',
			orderOps[0],
			transactionId
		);			
		op.pending = false;
		op.update();

		service.PaymentService.updateUserBalance(user, group);

		return orders;
	}	

	public static function getGroupConfig(group:db.Group):mangopay.db.MangopayLegalUserGroup{
		return mangopay.db.MangopayLegalUserGroup.get(group);
	}

	/**
		Get Group legal User 
	**/
	static public function getGroupLegalUserId(group: db.Group):String {
		
		var conf = MangopayPlugin.getGroupConfig(group);

		//this group can use mangopay and is well configured
		if(conf != null && conf.legalUser !=null ) {
			return conf.legalUser.mangopayUserId;
		}else{
			return null;
		}
		
	}
	
}