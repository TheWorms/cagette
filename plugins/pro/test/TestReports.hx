package pro.test; import utest.*;
using Lambda;
using tools.FloatTool;
import service.OrderService;
import test.TestSuite;
import service.ReportService;


class TestReports extends utest.Test
{  
	function setup(){
		test.TestSuite.initDB();
		test.TestSuite.initDatas();
	}

	/**
	Test orders by products in a timeframe
	**/
	function testOrdersByProductTimeframe(){

		//record orders
		var seb = TestSuite.SEB;
		var francois = TestSuite.FRANCOIS;
		var julie = TestSuite.JULIE;

		//distrib de légumes
		var d = TestSuite.DISTRIB_LEGUMES_RUE_SAUCISSE;
		var carrots = TestSuite.CARROTS;
		var courgettes = TestSuite.COURGETTES;
		var potatoes = TestSuite.POTATOES;

		OrderService.make(seb,4,courgettes,d.id);
		OrderService.make(seb,1,potatoes,d.id);

		OrderService.make(francois,6,courgettes,d.id);
		OrderService.make(francois,2,potatoes,d.id);
		OrderService.make(francois,3,carrots,d.id);

		OrderService.make(julie,8,carrots,d.id);
		OrderService.make(julie,3,potatoes,d.id);

		//courgettes = 10 x 3.5€ = 35€

		//record orders in a  SECOND distrib with a different price
		courgettes.lock();
		courgettes.price+=2;
		courgettes.update();

		var d2 = service.DistributionService.create(
			d.catalog,
			new Date(2018,2,12,0,0,0),
			new Date(2018,2,12,0,3,0),
			d.catalog.group.getPlaces().first().id,
			new Date(2018,2,8,0,0,0),
			new Date(2018,2,11,0,0,0)
		);
		OrderService.make(julie,6,courgettes,d2.id);
		OrderService.make(julie,11,carrots,d2.id);

		//courgettes = 6 x 5.5€ = 33 €

		var orders = pro.service.ProReportService.getOrdersByProduct({startDate:new Date(2017,0,0,0,0,0),endDate:new Date(2018,3,1,0,0,0)});

		
		var courgettesOrder = Lambda.find(orders.orders, function(o) return o.pid==courgettes.id);
		Assert.equals( 16.0 , courgettesOrder.quantity );
		//total should manage the various prices along distributions
		Assert.equals( 68.0 , courgettesOrder.totalTTC );

		var carrotsOrder = Lambda.find(orders.orders, function(o) return o.pid==carrots.id);
		Assert.equals( 22.0 , carrotsOrder.quantity );
		

		


	}

	

}