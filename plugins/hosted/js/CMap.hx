package hosted.js;
import leaflet.L;

class CMap {
	
	public var map:LeafletMap;	
	public var points : Array<Marker>;
	public var isAdmin: Bool;
	
	public function new(adm:Bool) {
		js.Browser.window.onload = onload;
		points = [];
		isAdmin = adm;
	}


	
	//when everything is loaded
	function onload() {
		//bourges centre de la france : 47.0836,2.3948
		
		this.map = L.map('map',{scrollWheelZoom: false}).setView([47.0836,2.3948], 6);

		var mapboxToken = App.config.get("mapbox_token");
		
		//mapbox
		L.tileLayer('https://api.tiles.mapbox.com/v4/{id}/{z}/{x}/{y}.png?access_token=' + mapboxToken, {
			attribution: 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://mapbox.com">Mapbox</a>',
			maxZoom: 32,
			id: 'bubar.cih3inmqd00tjuxm7oc2532l0',
			accessToken: mapboxToken,
		}).addTo(map);
		
		map.on('moveend', loadDatas );
		
		loadDatas();

	}
	

	
	public function loadDatas(?e:Dynamic) {
	
		var bounds = map.getBounds();
		var min = bounds.getSouthWest();
		var max = bounds.getNorthEast();
		//trace("MIN : "+min.lat +"-"+ min.lng);
		//trace("MAX : " + max.lat +"-" + max.lng);
		
		var r = new haxe.Http("/p/hosted/book/mapDatas/" + min.lat + "/" + max.lat + "/" + min.lng + "/" + max.lng);
		r.onData = onDatas;
		r.request();
		
	}
	
	
	public function onDatas(d:String) {
		
		//remove previous points
		for (a in points) map.removeLayer(a);
	
		//print datas
		
		var groups : Array<Dynamic> = haxe.Unserializer.run(d);
		var markers = untyped L.markerClusterGroup();
		for (g in groups) {
			
			var marker = L.marker([g.lat, g.lng], {icon:getIcon()} );
			
			//trace('[${g.lat}, ${g.lng}] ${g.name}');
			
			var html = '<h3><a href="https://app.cagette.net/group/${g.id}" target="_blank">${g.name}</a></h3>${g.address}';
			
			marker.bindPopup( html )/*.addTo(map)*/;
			points.push(marker);
			
			markers.addLayer(marker);
	
		}
		map.addLayer(markers);
	
		
	}
	

	function getIcon(){
		return L.icon( { iconUrl: '/pa/hosted/img/marker-icon.png',iconSize: [25, 41] } );
	}

	
	private function nullSafe(s:Dynamic):String{
		if (s == null) return "";
		return s;
	}
	

	
	
}
