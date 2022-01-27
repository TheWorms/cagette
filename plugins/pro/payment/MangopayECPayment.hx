package pro.payment;
import Common;
/**
 * Mangopay e-commerce payment
 * 
 * @author fbarbut
 */
class MangopayECPayment extends payment.PaymentType
{
	public static var TYPE(default, never)  = "mangopay-ec";

	public function new() 
	{
		// var t = sugoi.i18n.Locale.texts;
		this.type = TYPE;
		this.onTheSpot = false;
		this.icon = /*'<i class="icon icon-bank-card" aria-hidden="true"></i>'*/"<img src='/img/powered-by-mangopay2.png' style='width:230px;' />";
		this.name = "Carte bancaire";
		this.link = "/p/pro/transaction/mangopay/"+TYPE;
		this.adminDesc = "Pré-paiement par carte bancaire à la commande (Mangopay).";
		docLink = "https://wiki.cagette.net/admin:admin_mangopaygroup";
	}
	
}