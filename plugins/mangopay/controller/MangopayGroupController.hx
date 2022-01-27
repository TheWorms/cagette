package mangopay.controller;

import tools.FloatTool;
import Common;
import pro.payment.*;
import mangopay.Mangopay;
import mangopay.Types;
import mangopay.db.*;
import sugoi.form.elements.*;
import sugoi.tools.Utils;
import db.Operation;
import db.MultiDistrib;

using tools.ObjectListTool;

/**
 * Mangopay group controller
 */
class MangopayGroupController extends controller.Controller
{

    /**
		Mangopay Group payouts
	**/
	@tpl('plugin/pro/mangopay/group/wallet.mtt')
	public function doWallet(){
		
		view.nav = nav("groupAdmin");
		var group = app.user.getGroup();
		
		//If the legal user doesn't exist already in the mapping table it means that 
		//we haven't created yet a legal user in Mangopay
		var wallet = null;
		var mgpLegalUser = null;
		try{
			var groupConfig = MangopayPlugin.getGroupConfig(group);
			mgpLegalUser = groupConfig.legalUser;						
			wallet = Mangopay.getOrCreateGroupWallet(mgpLegalUser.mangopayUserId,group);

		}catch(error:tink.core.Error){
			throw Error("/amapadmin",error.message);
		}

		view.wallet = wallet;

		//distribs
		var now = Date.now();
		var timeframe = new tools.Timeframe(DateTools.delta(now,-1000.0*60*60*24*30.5 * 1),DateTools.delta(now,1000.0*60*60*24*30.5 * 1));
		view.timeframe = timeframe;
		var mds = MultiDistrib.getFromTimeRange(group,timeframe.from,timeframe.to);
		view.multidistribs = mds;
		view.getMangopayGroupPayout = function(md:MultiDistrib){
			return MangopayGroupPayOut.get(md);
		} 

		view.getMangopayECTotal = MangopayPlugin.getMultidistribNetTurnover; 

        var pageUrl = "/p/pro/transaction/mangopay/group/wallet";

		//trigger a transfer
		if(checkToken()){
			var bankAccount = Mangopay.getIBANBankAccount(mgpLegalUser);
			var mdid = Std.parseInt(app.params.get("md"));
			if(mdid==null) throw "md cannot be null";
			var md = db.MultiDistrib.manager.get(mdid);
			if(md==null) throw "md is null";
			if(md.getGroup()!=app.getCurrentGroup()) throw "bad md";

			if(bankAccount==null) {
				throw Error(pageUrl, "Vous devez définir votre IBAN.");
			}

			if(!md.isConfirmed()){
				throw Error(pageUrl, "Cette distribution doit être validée avant de demander un virement.");
			}

			var t = MangopayGroupPayOut.get(md,true);
			if (t!=null){
				if(t.hasSucceeded()){
					throw Error(pageUrl, "Vous avez déjà effectué une demande de virement.");
				}else{
					t.delete();
				}				
			}
			
			//Do a payout
			var amount = 0.0;
			if(app.params.get("amount")!=null){
				amount = Std.parseFloat(app.params.get("amount"));
			}else{
				amount = MangopayPlugin.getMultidistribNetTurnover(md);
			}

			var payout : PayOut = {
				DebitedFunds: {
					Currency: Euro,
					Amount: Math.round(amount*100)
				},
				Fees: {
					Currency: Euro,
					Amount: 0
				},
				DebitedWalletId: wallet.Id,
				AuthorId: mgpLegalUser.mangopayUserId,
				BankAccountId: bankAccount.Id,
				BankWireRef: "dist"+md.getDate().toString().substr(0,10)
			};

			try{
				Mangopay.createGroupPayOut(payout, md);
			}catch(e:tink.core.Error){
				if(e.code==1001){
					throw Error(pageUrl, "Vous n'avez pas suffisamment de fonds sur votre compte Mangopay pour faire ce virement.");
				}else{
					throw e;
				}
			}
				
			throw Ok(pageUrl, "Virement demandé.");
		}	

	}

	/**
		Payout detail
	**/
	@tpl('plugin/pro/transaction/mangopay/payout.mtt')
	function doPayOut(payoutId:String){
		var p = Mangopay.getPayOut(payoutId);
		view.payout = p;
		view.fromTime = Date.fromTime;
	}

	/**
		Justificatif
		payments details of a multidistrib
	**/
    @tpl('plugin/pro/mangopay/group/multiDistrib.mtt')
    function doMultiDistrib(md:MultiDistrib){
        
		view.md = md;
		view.justif = MangopayPlugin.getMultiDistribDetailsForGroup(md);

    }

	/**
		DEBUG a multidistrib : compare what we have in mangopay DB, and what we have locally.
	**/
	@admin @tpl('plugin/pro/mangopay/group/multiDistribDebug.mtt')
    function doMultiDistribDebug(md:db.MultiDistrib){
		view.d = md;
		var distribIncomeMP = 0.0;
		var distribIncomeCG = 0.0;
		
		//Mangopay datas
		var legalUserId = MangopayPlugin.getGroupLegalUserId(md.getGroup());
		var wallet = Mangopay.getOrCreateGroupWallet(legalUserId, md.getGroup() );

		var mgpOps = [];
		for( i in 1...100){
			var opsBunch =  Mangopay.getWalletOperations( wallet , 100 , i , md.orderStartDate , md.orderEndDate);
			if(opsBunch.length==0) break;
			for( o in opsBunch) {
				if(o.Status!=Succeeded) continue;
				if(o.Type!=Payin) continue;

				mgpOps.push(o);

				//get refunds wich have been made later than orderEndDate
				for ( r in Mangopay.getPayInRefunds(o.Id.parseInt())){
					// trace(r);
					if(r.Status=="SUCCEEDED"){
						mgpOps.push(cast r);
					}					
				}
			}
		}
	
		view.mgpOps = mgpOps;

		//CAGETTE DATAS
		var cgOps = new Array<Operation>();		
		for( b in md.getBaskets()){
			for( op in b.getPaymentsOperations() ){
				if( op.getPaymentType()==MangopayECPayment.TYPE ){
					// var conf = MangopayPlugin.getGroupConfig(md.getGroup());
					// var amount = MangopayPlugin.getAmountAndFees(op.amount,conf);
					// var mu = MangopayUser.get(op.user);
					cgOps.push(op);
					distribIncomeCG += op.amount;
				}
			}
		}

		view.find = function(cgOp:Operation,mgpOps:Array<Transaction>):Transaction{
			var op = mgpOps.find( o -> o.Id == cgOp.getPaymentData().remoteOpId);
			/*var op = Lambda.find(mgpDatas, function(mgpData){
				//trace(mgpData.userMgpId+"?="+cgData.userMgpId+", "+mgpData.netAmount+"?="+cgData.netAmount);
				return Std.parseInt(cast mgpData.userMgpId)==Std.parseInt(cast cgData.userMgpId) && FloatTool.isEqual(mgpData.netAmount,cgData.netAmount);
			});*/
			mgpOps.remove(op);
			return op;
		}

		view.money = function(m:Money){
			return m.Amount/100;
		}

		view.cgOps = cgOps;
		view.distribIncomeMP = distribIncomeMP;
		view.distribIncomeCG = distribIncomeCG;
    }

    /**
		Bug de Brigitte
		Essayer de retrouver les paiements qui ne sont pas référencés par Cagette.
	**/
	@admin @tpl('plugin/pro/mangopay/group/debug.mtt')
	function doDebug(group:db.Group){
		var conf = MangopayPlugin.getGroupConfig(group);
		var now = Date.now();
		var timeframe = new tools.Timeframe(DateTools.delta(now,-1000.0*60*60*24*3.5),DateTools.delta(now,1000.0*60*60*24*3.5));
		view.timeframe = timeframe;

		var wallet = Mangopay.getOrCreateGroupWallet(conf.legalUser.mangopayUserId, group );

		//get all ops in this timeframe
		var ops = [];
		for( i in 1...100){
			var opsBunch =  Mangopay.getWalletOperations( wallet , 100 , i , timeframe.from,timeframe.to);
			if(opsBunch.length==0) break;
			for( o in opsBunch){
				if(o.Status!=Failed) ops.push(o);
			} 
		}

		view.transactions = ops;
		view.group = group;
		view.findOperation = function(id:String){
			//trace("Look for mp payin "+id +" : <br/>");			
			for ( op in db.Operation.manager.search( $group==group && $type==OperationType.Payment,false ))
			{				
				if(op.getPaymentType()==pro.payment.MangopayECPayment.TYPE || op.getPaymentType()==pro.payment.MangopayMPPayment.TYPE){
					var i : PaymentInfos = op.getPaymentData();
					//trace(i.remoteOpId);
					if (Std.string(i.remoteOpId) == id){
						return op;
					}
				}

			}
			return null;
		}

		view.findUser = function(id:String){
			return MangopayUser.manager.select($mangopayUserId == id,false);
		}

		view.getRefunds = function(payInId:Int){
			return Mangopay.getPayInRefunds(payInId);
		}
	}


	/**
		Bug du mdkey , compta au centime près
		
		on liste les md, calcule ce qui doit etre viré.
		regarde ce qu'il y a sur le wallet et gueule si ça correspond pas.
	**/
	@admin @tpl('plugin/pro/mangopay/group/debug2.mtt')
	function doDebug2(group:db.Group){

		var group = group;
		view.group = group;
		
		//If the legal user doesn't exist already in the mapping table it means that 
		//we haven't created yet a legal user in Mangopay
		var legalUserId = null;
		var wallet = null;
		try{
			legalUserId = MangopayPlugin.getGroupLegalUserId(group);
			wallet = Mangopay.getOrCreateGroupWallet(legalUserId,group);
		}catch(error:tink.core.Error){
			throw Error("/amapadmin",error.message);
		}

		view.wallet = wallet;

		//distribs
		var now = Date.now();
		var threeMonthAgo = DateTools.delta(now,-1000.0*60*60*24*30.5*6); 
		var inThreeMonth = DateTools.delta(now,1000.0*60*60*24*30.5*6); 
		var mds = MultiDistrib.getFromTimeRange(group,threeMonthAgo,inThreeMonth);
		view.multidistribs = mds;
		view.getMangopayGroupPayout = function(md:MultiDistrib){
			return MangopayGroupPayOut.get(md);
		}

		view.getMangopayECTotal = MangopayPlugin.getMultidistribNetTurnover; 

	}

	@tpl('plugin/pro/mangopay/group/module.mtt')
	public function doModule(){
		view.nav = nav("groupAdmin");
		// if(app.params.get("enable")!=null){			
		// 	throw Redirect("/p/pro/transaction/mangopay/group/module");
		// }
	}
}