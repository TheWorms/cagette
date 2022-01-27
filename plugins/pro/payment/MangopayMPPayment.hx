package pro.payment;
import Common;
/**
 * Mangopay Marketplace payment
 * 
 * @author web-wizard
 */
class MangopayMPPayment extends payment.PaymentType
{
	public static var TYPE(default, never) = "mangopay-mp";

	public function new() 
	{
		// var t = sugoi.i18n.Locale.texts;
		this.type = TYPE;
		this.onTheSpot = false;
		this.icon = '<i class="icon icon-bank-card" aria-hidden="true"></i>';
		this.name = "Carte bancaire Mangopay (marketplace)";
		this.link = "/p/pro/transaction/mangopay/"+TYPE;
	}
	
}