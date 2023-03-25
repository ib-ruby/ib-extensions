module IB
  module Extensions
    VERSION = "1.3.1"
  end
end


__END__

Changelog V. 1.2 -> 1.3

* added probability_of_expiring to IB::Option
* IB::Contract.eod returns a Polars DataFrame
* improved IB::Option.request_greeks
* improved IB::Contract.verify

1.3.1:  Contract.eod:  Parameter  polars: true|false 

