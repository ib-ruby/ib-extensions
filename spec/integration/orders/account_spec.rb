require 'order_helper'

describe 'Order placement via Account'  do # :connected => true, :integration => true do
	let(:contract_type) { :stock }

	before(:all) { init_gateway }

	after(:all) do 
		remove_open_orders
		close_connection 
	end


	let( :jardine ){ IB::Stock.new symbol: 'J36', exchange: 'SGX' }  # trading hours: 2 - 10 am GMT, min-lot-size: 100
	let( :ge ){ IB::Stock.new symbol: 'GE', exchange: 'SMART' }  # trading hours: 2 - 10 am GMT, min-lot-size: 100
	let( :tui ){IB::Stock.new symbol: :tui1, exchange: :smart, currency: :eur }  # trading hours: 2 - 10 am GMT, min-lot-size: 100

	let( :the_client ){  IB::Gateway.current.clients.detect{|y| y.account ==  ACCOUNT} } 

	context 'Placing orders', :slow => true do
		before(:each) do
			gw = IB::Gateway.current
			gw.tws.clear_received   # just in case ...
		end
		# note:  if the tests don't pass, cancel all orders maually and run again  (/examples/canccel_orders)
    # note:  We explicitly set auto-adjust to false!
		it "wrong order" do
			the_order=  IB::Limit.order action: :buy, size: 100, :limit_price =>  0.453 # non-acceptable price
      expect{  the_client.place contract: jardine, order: the_order, auto_adjust: false }
        .to raise_error( IB::SymbolError, /The price does not conform to the minimum price variation/ )
			expect( should_log /The price does not conform to the minimum price variation/ ).to be_truthy
		end
		it "order too small" do
			the_order=  IB::Limit.order action: :buy, size: 10, :limit_price =>  20 # acceptable price
      expect{  the_client.place contract: jardine, order: the_order }
        .to raise_error( IB::SymbolError, /Order size 10 is smaller than the minimum required size of 100/)
			expect( should_log /Order size 10 is smaller than the minimum required size of 100/ ).to be_truthy
		end

    it "placing 10% below market price" do
      mp = tui.market_price
      mp = 4 if mp.to_i.zero?    # default-price
      the_price = mp -(mp*0.1)
      the_order=  IB::Limit.order action: :buy, size: 100, :limit_price =>  the_price
      local_id =  the_client.place contract: tui, order: the_order , convert_size: true, auto_adjust: true

			expect( local_id ).not_to be_nil
			expect( the_client.orders ).to have_at_least(1).entry
			expect( the_client.orders.first.order_states ).to have_at_least(1).entry
#			puts the_client.orders.first.order_states.last.inspect
      expect( the_client.orders.first.order_states.last.status).to eq( 'New')
                                                              .or eq("Submitted")
                                                              .or eq("PreSubmitted")
			expect( the_client.orders.first.order_states.last.filled).to be_zero
    end
	end
	

end # describe
