
* lib/gateway.rb
	* rename `active_accounts` to `clients`  
	  Clients are just tradeable `IB::Accounts`.  
 
  * rename ' for_active_accounts' to `account_data`
		Account-data provides a thread-safe access to contracts, portfolio- and account-values of a given account.

  * rename `simple_account_data_scan`  to `account_Data_scan`

  * connect: raises an error if connection is not possible because of using a not unique client_id

	* initialize::  tolerates arguments other then specified. 

	* made methods that never should call by users private:  
	  check_connection, initialize_alerts, initialize_managed_accounts, prepare_connection 
 
* lib/ib/gateway   
  
  Directory contains gateway related stuff

	* account-infos.rb
	* order-handling.rb

* lib/ib/alerts
   
	* included specific alert-definitions in this directory:
	  order-alerts, gateway-alerts

* moving model/spread.rb to `ib-api`  Gem

#### Preparation of a Gem-Release 

* Gateway#connect: initializing order-array by calling :RequestAllOrders after establishing the connection.

* Gateway#connect: Occasionally the request for AccountPositions/AllOrders fails. Then a reconnect is
                   appropriate. This is now implemented.

* Order.auto_adjust

     Auto Adjust implements a simple algorithm to ensure that an order is accepted
    
     It reads `contract_detail.min_tick`. 
    
     If min_tick < 0.01, the real tick-increments differ from the min_tick_value
    
     For J36 (jardines) min tick is 0.001, but the minimal increment is 0.005
     For Tui1 its the same, min_tick is 0.00001 , minimal increment is 0.00005
    
     Thus, for min-tick smaller then 0.01, the value is rounded to the next higher digit.
     
     | min-tick     |  round     |
     |--------------|------------|
     |   10         |   110      |
     |    1         |   111      |
     |    0.1       |   111.1    |
     |    0.001     |   111.11   |
     |    0.0001    |   111.11   |
     |    0.00001   |   111.111  |
     |--------------|------------|

* Client.place:   defaults are 
  *   auto_adjust is "true" 
  *   convert_size: true

  If a negative value for 'total amount' is used, then Order.action is set to :sell.   
  If a positive value is used, Order.action is kept 

* Client.place raises an `IB::Symbol Error` if the order is not submitted 

* Included Contract#included_in?( an IB::Account ) and Contract#portfolio_value( an IB::Account )

  Suppose, you want to check, if a complex Contract is included in the Portfolio

  ```ruby
  s = Straddle.build symbol: Symbols::Index.stoxx, strike=4200, expiry: 20211217
  puts s.included__in?(IB::Gateway.current.clients.first).to_human
  =>  "<Straddle ESTX50(4200.0)[Dec 2021]>" 
  puts s.portfolio_value( IB::Gateway.current.clients.first ).to_human
  => <PortfolioValue: Uxxxxxx Pos=-4 @ 225.158;Value=-9006.31;PNL=-1812.31 unrealized;<Option: ESTX50 20211217 put 4200.0 DTB EUR>
 => <PortfolioValue: Uxxxxxxx Pos=-4 @ 99.398;Value=-3975.9;PNL=-61.9 unrealized;<Option: ESTX50 20211217 call 4200.0 DTB EUR>

  ```
  Both methods are available for IB::Contracts.

* IB::Gateway.current.get_account_data  accepts only one parameter and is not persistent anymore
   The former second argument (watchlists: ) is defaulted by those initialized through e IB::Gateway.new  (IB::Gateway.current.active_watchlists)  
   The method now fetches the account- and portfoliodate, initialises Account#contracts, Account#portfolio_values, Account#account_values , Account#focusses and desubscribes from the TWS. (Before, the subscription to AccountData was permanently active).

* IB::Gateway.current.add_watchlist( a symbol ) -- Watchlists can added after initialisation

* New directory structure:  IB::Extensions::Modulename
* Extensions are modules which are included in IB::Contracts
* IB::Option.underlying fetches the contract as specified in contract-details of  IB::Option
