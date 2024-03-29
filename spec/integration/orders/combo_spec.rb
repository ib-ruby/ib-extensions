require 'order_helper'
require 'combo_helper'

RSpec.describe "What IF  Order"   do


  before(:all) { init_gateway }
		
	after(:all) {  remove_open_orders; close_connection }

	context "Butterfly" do
		before(:all) do
      gw =  IB::Gateway.current
      if gw
        @initial_order_id =  gw.tws.next_local_id

        gw.tws.clear_received   # just in case ...

        the_contract =  IB::Butterfly.build( from: IB::Stock.new( symbol: :goog ), expiry: 202112,
                                            right: :call, strike: 2700, front: 2650, back: 2750 )
        market_price =  3 #  the_contract.market_price 
        the_client =  gw.clients.detect{|x| x.account == ACCOUNT }

        @local_id_placed = the_client.preview contract: the_contract,
          order: IB::Limit.order( action: :buy,
                                 limit_price: market_price ,
                                 size: 10 )
      end
    end

		context IB::Connection do
			subject{  IB::Connection.current  }
			its( :next_local_id ){ is_expected.to eq @initial_order_id +1 }
			it { expect( subject.received[:OpenOrder]).to have_at_least(1).open_order_message }
			it { expect( subject.received[:OrderStatus]).to have_at_least(0).status_message }
			it { expect( subject.received[:OrderStatus]).to be_empty }
			it { expect( subject.received[:ExecutionData]).to be_empty }
			it { expect( subject.received[:CommissionReport]).to be_empty }

		end


		context IB::Messages::Incoming::OpenOrder do
			subject{ IB::Connection.current.received[:OpenOrder].last }
			it_behaves_like 'OpenOrder message'
		end

		context IB::Order do
			subject{ IB::Connection.current.received[:OpenOrder].last.order }
			it_behaves_like 'Placed Order' 
			it_behaves_like 'Presubmitted what-if Order',  IB::Bag.new
		end

		## separated from  context IB::Order
		#. ib.clear_received is evaluated before shared_examples are run, thus 
		#	 makes it impossible to load the order from the received-hash..
		context "finalize" do
			it 'is not actually being placed though' do
				ib = IB::Connection.current
				ib.clear_received
				ib.send_message :RequestOpenOrders
				ib.wait_for :OpenOrderEnd
				expect(  ib.received[:OpenOrder]).to have_exactly(0).order_message
			end
		end  # context "What if order"
	end
end
__END__
