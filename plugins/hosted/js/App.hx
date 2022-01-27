package hosted.js;

/**
 * JS for cagette-hosted plugin
 * @author fbarbut
 */
class App
{

	public function new() 
	{
		
	}
	
	/**
	 * init the Groups Map
	 */
	public function initMap(?adm=false) {
		return new hosted.js.CMap(adm);
	}
	
	
	
}