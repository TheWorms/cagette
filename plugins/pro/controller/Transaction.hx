package pro.controller;

/**
 * ...
 * @author fbarbut
 */
class Transaction extends controller.Controller
{

	public function doMangopay(d:haxe.web.Dispatch){
		d.dispatch(new mangopay.controller.MangopayController());
	}
	
}