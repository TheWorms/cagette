package pro.test; import utest.*;
using Lambda;
import service.OrderService;
import tools.FloatTool;
import pro.payment.MangopayMPPayment;


/**
 * Test cagette-pro Marketplace payment
 * 
 * @author webwizard
 */
class TestMarketplacePayment extends utest.Test
{

	function setup(){
		//reset DB before each test
		test.TestSuite.initDB();
		test.TestSuite.initDatas();
	}

	/**
	 *  Test money dispatch
	 */
	function testFundsRepartition(){

		var CHICKEN = test.TestSuite.CHICKEN;
		var FRANCOIS = test.TestSuite.FRANCOIS;
		var COURGETTES = test.TestSuite.COURGETTES;
		var CROISSANT = test.TestSuite.CROISSANT;

		//Create a MultiDistrib by setting an existing distrib to the same dates as another
		var multiDistrib = new MultiDistrib();
		var distrib1 = test.TestSuite.DISTRIB_LEGUMES_RUE_SAUCISSE;
		var distrib2 = test.TestSuite.DISTRIB_PATISSERIES;
		distrib1.lock();
		distrib2.lock();
		distrib1.date = distrib2.date;
		distrib1.end = distrib2.end = new Date(2038, 12, 31, 23, 59, 0);
		distrib1.update();
		distrib2.update();
		var contract1 = distrib1.contract;
		var contract2 = distrib2.contract;
		multiDistrib.distributions = [distrib1, distrib2];
	    multiDistrib.contracts = [contract1, contract2];
		
		//François buys products for a multidistrib, in 2 times
		var francoisOrder1 = OrderService.make( FRANCOIS, 1, CHICKEN, distrib1.id);
		var francoisOrder2 = OrderService.make( FRANCOIS, 2, COURGETTES, distrib1.id);
		var francoisOrderOperation1 = service.PaymentService.onOrderConfirm([francoisOrder1, francoisOrder2]);

		var francoisOrder3 = OrderService.make( FRANCOIS, 4, CROISSANT, distrib2.id);
		var francoisOrderOperation2 = service.PaymentService.onOrderConfirm([francoisOrder3]);
		

		//Julie buys products for the same multidistrib
		var julieOrder1 = OrderService.make(test.TestSuite.JULIE, 3, test.TestSuite.CROISSANT, distrib2.id);
		var julieOrder2 = OrderService.make(test.TestSuite.JULIE, 5, test.TestSuite.FLAN, distrib2.id);
		var julieOrderOperation = service.PaymentService.onOrderConfirm([julieOrder1, julieOrder2]);

		//They both pay by credit card
		var francoisPayment1 = db.Operation.makePaymentOperation(FRANCOIS,contract1.amap,MangopayMPPayment.TYPE, CHICKEN.price + 2*COURGETTES.price , "payment", francoisOrderOperation1[0]);
		var francoisPayment2 = db.Operation.makePaymentOperation(FRANCOIS,contract1.amap,MangopayMPPayment.TYPE, 4*CROISSANT.price , "payment", francoisOrderOperation2[0]);

		var juliePayment = db.Operation.makePaymentOperation(test.TestSuite.JULIE,contract2.amap,MangopayMPPayment.TYPE, 3 * test.TestSuite.CROISSANT.price + 5 * test.TestSuite.FLAN.price, "payment", julieOrderOperation[0]);
		
		//Check dispatch for François :
		// 1 x chicken = 15€
		// 2 x courgettes = 2 x 3.5€ = 7
		// 4 x croissants = 4 x 2.8€ = 11.2
		// total : 33.2
		var basket = francoisOrder1.basket;
		Assert.equals( 15.0 	, CHICKEN.price  );
		Assert.equals( 3.5	, COURGETTES.price );
		
		var dispatch = MangopayPlugin.getVendorsPaymentDispatch(basket);
		var fixedFees = MangopayPlugin.computeFixedFees(dispatch,basket);

		var vendorChicken = CHICKEN.contract.vendor;
		var vendorPastry = test.TestSuite.FLAN.contract.vendor;

		Assert.isTrue( FloatTool.isEqual( 22 		, dispatch[vendorChicken.id].amount ));
		Assert.isTrue( FloatTool.isEqual( 11.2		, dispatch[vendorPastry.id].amount ));

		//shared 0.18 fixed fee x 2 ( because 2 payment ops )
		Assert.isTrue( FloatTool.isEqual( 0.12*2		, dispatch[vendorChicken.id].fixedFees ));
		Assert.isTrue( FloatTool.isEqual( 0.06*2		, dispatch[vendorPastry.id].fixedFees ));
		var fixed = dispatch[vendorChicken.id].fixedFees + dispatch[vendorPastry.id].fixedFees;
		Assert.isTrue( FloatTool.isEqual( 0.18*2		, fixed ) );

		//variable fees 
		Assert.isTrue( FloatTool.isEqual( 0.4 , dispatch[vendorChicken.id].variableFees ));	// 22 x 0.018 = 0.396 , rounded 0.4
		Assert.isTrue( FloatTool.isEqual( 0.2 , dispatch[vendorPastry.id].variableFees ));		// 11.2 x 0.018 = 0.2016 , rounded 0.2
		var variable = dispatch[vendorChicken.id].variableFees + dispatch[vendorPastry.id].variableFees;
		Assert.isTrue( FloatTool.isEqual( 0.6 , variable ) ); 									// 33.2 * 0.018 = 0.5976 , rounded 0.6

		/*
		//Get all the repartition
		var vendorDataByVendorId = OrderService.getMultiDistribVendorOrdersByProduct(distrib1.date, distrib1.place);

		//Check this is what we expect for each vendor
		Assert.equals(vendorDataByVendorId.get(contract1.vendor.id).orders[0].total, 2 * test.TestSuite.COURGETTES.price);
		Assert.equals(vendorDataByVendorId.get(contract1.vendor.id).orders[1].total, 1 * test.TestSuite.CHICKEN.price);
		Assert.equals(vendorDataByVendorId.get(contract1.vendor.id).orders[2].total, 3 * test.TestSuite.CROISSANT.price);
		Assert.equals(vendorDataByVendorId.get(contract1.vendor.id).orders[3].total, 5 * test.TestSuite.FLAN.price);
		*/
	}
}