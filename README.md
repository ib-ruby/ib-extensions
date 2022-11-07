# IB/Extensions

---

__Documentation: [https://ib-ruby.github.io/ib-doc/](https://ib-ruby.github.io/ib-doc/)__  

__Questions, Contributions, Remarks: [Discussions are opened in ib-api](https://github.com/ib-ruby/ib-api/discussions)__


__Helpers and Macros that ease the usage of the TWS-API of Interactive Brokers__

To activate use
```
gem 'ib-extensions'
```
in the Gemfile and require the extensions as needed

## Include all
(except gateway)
```
require 'ib-api'
require 'ib/extensions'
```

## Verify
```
require 'ib-api'
require 'ib/verify'
```
Verifies a given contract, for details refer to the [documentation](https://ib-ruby.github.io/ib-doc/Verify_contracts.html )

## Market Price
```
require 'ib-api'
require 'ib/market-price'
```
Returns the most recent market-price of a given contract  ( [documentation](https://ib-ruby.github.io/ib-doc/market_price.html) )

## Historical Data (EOD)
```
require 'ib-api'
require 'ib/eod'

puts IB::Symbols.Index.estx.eod( duration: '10 d' )
```
Fetch historical data with just one line of code  ([documentation](https://ib-ruby.github.io/ib-doc/Historical_data.html) )

## Order Prototypes
```
require 'ib-api'
require 'ib/order-prototypes'

order = IB::Limit.order size: 100, price: 10, action: :buy
order = IB::StopLimit.order size: 100, price: 10, stop_price: 9.5
```

then transmit the order through  the [place_order](https://ib-ruby.github.io/ib-doc/order_placement.html)  method of IB::Connection or  Account-based  preview, place, modify and cancel methods of [IB::Gateway](https://ib-ruby.github.io/ib-doc/order_placement.html).

More details in the [documentation](https://ib-ruby.github.io/ib-doc/order_prototypes.html) 


## Spread Prototypes

``` ruby
require 'ib-api'
require 'ib/spread-prototypes'
```

Compose most common spreads through

``` ruby
s = IB::Straddle.build from: IB::Symbols::Index.stoxx, 
                            strike: 4200, 
                            expiry: 202112 
                            
t = IB::Strangle.build from: IB::Symbols::Index.stoxx, 
                            c: 2400, p: 2200, 
                            expiry: 202103 

puts s.as_table
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                      Straddle ESTX50(4200.0)[Dec 2021]                                      │
├────────┬────────┬────────────┬──────────┬──────────┬────────────┬───────────────┬───────┬────────┬──────────┤
│        │ symbol │ con_id     │ exchange │ expiry   │ multiplier │ trading-class │ right │ strike │ currency │
╞════════╪════════╪════════════╪══════════╪══════════╪════════════╪═══════════════╪═══════╪════════╪══════════╡
│ Spread │ ESTX50 │ -532066861 │   DTB    │          │     10     │               │       │        │   EUR    │
│ Option │ ESTX50 │  266033438 │   DTB    │ 20211217 │     10     │     OESX      │  put  │ 4200.0 │   EUR    │
│ Option │ ESTX50 │  266033423 │   DTB    │ 20211217 │     10     │     OESX      │ call  │ 4200.0 │   EUR    │
└────────┴────────┴────────────┴──────────┴──────────┴────────────┴───────────────┴───────┴────────┴──────────┘
 ```
and use the speads like any other contract. ([documentation](https://ib-ruby.github.io/ib-doc/spreads.html))

## Gateway 
```
require 'ib-gateway'
```
IB::Gateway is an enhancement of IB::Connection. Upon initialization, it detects active accounts and stores them in thread safe arrays. 

``` ruby
g =  IB::Gateway.current
clients =  G.clients
puts client.first.portfolio_values.as_table
┌───────────┬─────────────────────────────────────────────┬─────┬──────────┬──────────┬───────────┬────────────┬──────────┐
│           │                                             │ pos │ entry    │ market   │ value     │ unrealized │ realized │
╞═══════════╪═════════════════════════════════════════════╪═════╪══════════╪══════════╪═══════════╪════════════╪══════════╡
│ Uxxxxxxx  │ Stock: BEPC USD NYSE                        │ 200 │   43.038 │   41.042 │    8208.4 │    -399.17 │          │
│ Uxxxxxxx  │ Option: CNHI 20210819 put 13.0 IDEM EUR     │  -2 │    0.386 │     0.01 │     -9.63 │     376.37 │          │
│ Uxxxxxxx  │ Stock: EQT SEK SFB                          │ 200 │    443.8 │  420.469 │  84093.85 │   -4666.19 │ -1369.02 │
│ Uxxxxxxx  │ Future: ESTX50 20210917 EUR                 │  -1 │   4145.3 │  4098.15 │  -40981.5 │      471.5 │          │
│ Uxxxxxxx  │ Option: ESTX50 20211217 call 4200.0 DTB EUR │  -4 │    97.85 │   99.398 │   -3975.9 │      -61.9 │          │
│ Uxxxxxxx  │ Option: IWM 20210903 call 230.0 AMEX USD    │  -4 │    1.943 │    0.124 │    -49.72 │     727.49 │          │

```
Details in the [documentation](https://ib-ruby.github.io/ib-doc/gateway.html)

Generally `puts IB::Model.as_table` provides a modern and convient output for the console and notebooks.

```ruby
g.update_orders
puts g.clients.first.orders.as_table
┌──────────┬───────────┬─────────────────────────────────────────┬──────┬─────┬────────┬────────┬───────┬────────┐
│ account  │ status    │                                         │ Type │ tif │ action │ amount │ price │ id/fee │
╞══════════╪═══════════╪═════════════════════════════════════════╪══════╪═════╪════════╪════════╪═══════╪════════╡
│ U123456  │ Submitted │ Option: SLV 20210716 put 24.0 SMART USD │ LMT  │ GTC │ sell   │ 5.0    │ 0.98  │ 0      │
└──────────┴───────────┴─────────────────────────────────────────┴──────┴─────┴────────┴────────┴───────┴────────┘
puts g.clients.first.orders.contract.as_table
┌────────┬────────┬───────────┬──────────┬──────────┬────────────┬───────────────┬───────┬────────┬──────────┐
│        │ symbol │ con_id    │ exchange │ expiry   │ multiplier │ trading-class │ right │ strike │ currency │
╞════════╪════════╪═══════════╪══════════╪══════════╪════════════╪═══════════════╪═══════╪════════╪══════════╡
│ Option │ SLV    │ 456347029 │  SMART   │ 20210716 │    100     │      SLV      │  put  │   24.0 │   USD    │
└────────┴────────┴───────────┴──────────┴──────────┴────────────┴───────────────┴───────┴────────┴──────────┘
```
Its used in [Simple Monitor](https://github.com/ib-ruby/simple-monitor)


## Notebooks
**`IB-Ruby`** code can be executed in [iruby jupyter notebooks](https://github.com/SciRuby/iruby). A few scripts are included in [IB-Examples](https://github.com/ib-ruby/ib-examples). (*.ipynb- files)


```
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ib-ruby/ib-extensions. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[ib-ruby/ib-extensions/blob/master/CODE_OF_CONDUCT.md).


## Code of Conduct

Everyone interacting in the Ib::Extensions project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ib-ruby/ib-extensions/blob/master/CODE_OF_CONDUCT.md).
