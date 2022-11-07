module IB
require 'active_support/core_ext/date/calculations'
require 'csv'
	module BuisinesDays
		#		https://stackoverflow.com/questions/4027768/calculate-number-of-business-days-between-two-days

		# Calculates the number of business days in range (start_date, end_date]
		#
		# @param start_date [Date]
		# @param end_date [Date]
		#
		# @return [Fixnum]
		def self.business_days_between(start_date, end_date)
			days_between = (end_date - start_date).to_i
			return 0 unless days_between > 0

			# Assuming we need to calculate days from 9th to 25th, 10-23 are covered
			# by whole weeks, and 24-25 are extra days.
			#
			# Su Mo Tu We Th Fr Sa    # Su Mo Tu We Th Fr Sa
			#        1  2  3  4  5    #        1  2  3  4  5
			#  6  7  8  9 10 11 12    #  6  7  8  9 ww ww ww
			# 13 14 15 16 17 18 19    # ww ww ww ww ww ww ww
			# 20 21 22 23 24 25 26    # ww ww ww ww ed ed 26
			# 27 28 29 30 31          # 27 28 29 30 31
			whole_weeks, extra_days = days_between.divmod(7)

			unless extra_days.zero?
				# Extra days start from the week day next to start_day,
				# and end on end_date's week date. The position of the
				# start date in a week can be either before (the left calendar)
				# or after (the right one) the end date.
				#
				# Su Mo Tu We Th Fr Sa    # Su Mo Tu We Th Fr Sa
				#        1  2  3  4  5    #        1  2  3  4  5
				#  6  7  8  9 10 11 12    #  6  7  8  9 10 11 12
				# ## ## ## ## 17 18 19    # 13 14 15 16 ## ## ##
				# 20 21 22 23 24 25 26    # ## 21 22 23 24 25 26
				# 27 28 29 30 31          # 27 28 29 30 31
				#
				# If some of the extra_days fall on a weekend, they need to be subtracted.
				# In the first case only corner days can be days off,
				# and in the second case there are indeed two such days.
				extra_days -= if start_date.tomorrow.wday <= end_date.wday
												[start_date.tomorrow.sunday?, end_date.saturday?].count(true)
											else
												2
											end
			end

			(whole_weeks * 5) + extra_days
		end
	end
	class Contract
		# Receive EOD-Data and store the data in the `:bars`-property of IB::Contract
    #
    # contract.eod duration: {String or Integer}, start: {Date}, to: {Date} what: {see below} 
		#
    #
    #
    # The Enddate has to be specified (as Date Object), `:to`,  default: Date.today
		#
		# The Duration can either be specified as Sting "yx D", "yd W", "yx M" or as Integer.
    #
		# Alternatively a start date can be specified with the `:start` parameter.
		#
		# The parameter `:what` specifies the kind of received data.
    #
		#  Valid values:
		#   :trades, :midpoint, :bid, :ask, :bid_ask,
		#   :historical_volatility, :option_implied_volatility,
		#   :option_volume, :option_open_interest
		#
    # Error-handling
    # --------------
    # * Basically all Errors simply lead to log-entries:
    # * the contract is not valid,
    # * no market data subscriptions
    # * other servers-side errors
    # 
    # If the duration is longer then the maximum range, the response is
    # cut to the maximum allowed range
    #
    # Customize the result
    # --------------------
		# The results are stored in the `:bars` property of the contract
    # and can be preprocessed through a block, thus
		#
		# puts IB::Symbols::Index::stoxx.eod( duration: '10 d')){|r| r.to_human}
		#   <Bar: 2019-04-01 wap 0.0 OHLC 3353.67 3390.98 3353.67 3385.38 trades 1750 vol 0>
		#   <Bar: 2019-04-02 wap 0.0 OHLC 3386.18 3402.77 3382.84 3395.7 trades 1729 vol 0>
		#   <Bar: 2019-04-03 wap 0.0 OHLC 3399.93 3435.9 3399.93 3435.56 trades 1733 vol 0>
		#   <Bar: 2019-04-04 wap 0.0 OHLC 3434.34 3449.44 3425.19 3441.93 trades 1680 vol 0>
		#   <Bar: 2019-04-05 wap 0.0 OHLC 3445.05 3453.01 3437.92 3447.47 trades 1677 vol 0>
		#   <Bar: 2019-04-08 wap 0.0 OHLC 3446.15 3447.08 3433.47 3438.06 trades 1648 vol 0>
		#   <Bar: 2019-04-09 wap 0.0 OHLC 3437.07 3450.69 3416.67 3417.22 trades 1710 vol 0>
		#   <Bar: 2019-04-10 wap 0.0 OHLC 3418.36 3435.32 3418.36 3424.65 trades 1670 vol 0>
		#   <Bar: 2019-04-11 wap 0.0 OHLC 3430.73 3442.25 3412.15 3435.34 trades 1773 vol 0>
		#   <Bar: 2019-04-12 wap 0.0 OHLC 3432.16 3454.77 3425.84 3447.83 trades 1715 vol 0>
		#
    #
    # Limitations
    # -----------
    # To identify a request, the con_id of the asset is used
    # Thus, parallel requests of a single asset with different time-frames will fail
    #
    # Examples
    # --------
		#
		# puts Symbols::Stocks.wfc.eod(  start: Date.new(2019,10,9), duration: 3 )
		#		<Bar: 2020-10-23 wap 23.3675 OHLC 23.55 23.55 23.12 23.28 trades 5778 vol 50096>
		#		<Bar: 2020-10-26 wap 22.7445 OHLC 22.98 22.99 22.6 22.7 trades 6873 vol 79560>
		#		<Bar: 2020-10-27 wap 22.086 OHLC 22.55 22.58 21.82 21.82 trades 7503 vol 97691>

		# puts Symbols::Stocks.wfc.eod(  to: Date.new(2019,10,9), duration: 3 )
		#		<Bar: 2019-10-04 wap 48.964 OHLC 48.61 49.25 48.54 49.21 trades 9899 vol 50561>
		#		<Bar: 2019-10-07 wap 48.9445 OHLC 48.91 49.29 48.75 48.81 trades 10317 vol 50189>
		#		<Bar: 2019-10-08 wap 47.9165 OHLC 48.25 48.34 47.55 47.82 trades 12607 vol 53577>
		#
    # puts Stock.new(symbol: :iwm).eod(  start: Date.new(2019,10,9) , duration: '3W' )
    #   <Bar: (02.07.21)00:00:00 wap 229.921 OHLC 229.19 232.33 227.42 229.19 trades 308673 vol 543523>
    #   <Bar: (09.07.21)00:00:00 wap 223.676 OHLC 229.01 230.15 217.85 226.7 trades 628599 vol 1003058>
    #   <Bar: (16.07.21)00:00:00 wap 219.844 OHLC 225.15 226.89 214.47 214.95 trades 782081 vol 1275212>
    #   <Bar: (20.07.21)00:00:00 wap 213.574 OHLC 212.62 219.27 209.05 218.97 trades 489533 vol 805738>
    #
    # puts Stock.new(symbol: :iwm).eod(  start: Date.new(2019,10,9), duration: '3M' )
    #   <Bar: (30.04.21)00:00:00 wap 226.194 OHLC 221.79 230.95 220.78 225.09 trades 766915 vol 1292828>
    #   <Bar: (28.05.21)00:00:00 wap 220.385 OHLC 226.86 228.5 210.19 225.6 trades 2585436 vol 4182406>
    #   <Bar: (30.06.21)00:00:00 wap 228.693 OHLC 226.65 233.7 221.13 230.27 trades 2557100 vol 4269840>
    #   <Bar: (20.07.21)00:00:00 wap 220.491 OHLC 230.77 232.33 209.05 218.97 trades 2105400 vol 3412088>
    #  
		def eod start:nil, to: Date.today, duration: nil , what: :trades

			tws = IB::Connection.current
			recieved =  Queue.new
			r = nil
      # the hole response is transmitted at once!
			a = tws.subscribe(IB::Messages::Incoming::HistoricalData) do |msg|
				if msg.request_id == con_id
					#					msg.results.each { |entry| puts "  #{entry}" }
          self.bars = msg.results   #todo: put result in dataframe
				end
				recieved.push Time.now
			end
			b = tws.subscribe( IB::Messages::Incoming::Alert) do  |msg|
				if [321,162,200].include? msg.code
					tws.logger.error msg.message
					# TWS Error 200: No security definition has been found for the request
					# TWS Error 354: Requested market data is not subscribed.
				  # TWS Error 162  # Historical Market Data Service error
          recieved.close
				end
		  end

			duration =  if duration.present?
                 duration.is_a?(String) ? duration.gsub(" ", "") : duration.to_s + "D"
									elsif start.present?
										BuisinesDays.business_days_between(start, to).to_s + "D"
									else
										"1D"
                  end.insert(-2, " ")

      barsize = case duration[-1]
                when "D"
                  :day1
                when "W"
                  :week1
                when "M"
                  :month1
                end
			tws.send_message IB::Messages::Outgoing::RequestHistoricalData.new(
				:request_id => con_id,
				:contract =>  self,
				:end_date_time => to.to_time.to_ib, #  Time.now.to_ib,
				:duration => duration, #    ?
				:bar_size => barsize, #  IB::BAR_SIZES.key(:hour)?
				:what_to_show => what,
				:use_rth => 0,
				:format_date => 2,
				:keep_up_todate => 0)

      recieved.pop # blocks until a message is ready on the queue or the queue is closed

			tws.unsubscribe a
			tws.unsubscribe b

      block_given? ?  bars.map{|y| yield y} : bars  # return bars or result of block

		end # def

    # creates (or overwrites) the specified file (or symbol.csv) and saves bar-data
    def to_csv file: "#{symbol}.csv"
      if bars.present?
        headers = bars.first.invariant_attributes.keys
        CSV.open( file, 'w' ) {|f| f << headers ; bars.each {|y| f << y.invariant_attributes.values } }
      end
    end

    # read csv-data into bars
    def from_csv file: nil
      file ||=  "#{symbol}.csv"
      self.bars = []
      CSV.foreach( file,  headers: true, header_converters: :symbol) do |row|
        self.bars << IB::Bar.new( **row.to_h )
      end
    end


    
    def get_bars(end_date_time, duration, bar_size, what_to_show) 

      tws = IB::Connection.current
      recieved =  Queue.new
      r = nil
      # the hole response is transmitted at once!
      a = tws.subscribe(IB::Messages::Incoming::HistoricalData) do |msg|
        if msg.request_id == con_id
          # msg.results.each { |entry| puts "  #{entry}" }
          self.bars = msg.results
        end
        recieved.push Time.now
      end
      b = tws.subscribe( IB::Messages::Incoming::Alert) do  |msg|
        if [321,162,200].include? msg.code
          tws.logger.info msg.message
          # TWS Error 200: No security definition has been found for the request
          # TWS Error 354: Requested market data is not subscribed.
          # TWS Error 162  # Historical Market Data Service error
          recieved.close
        end
      end

      # duration =  if duration.present?
      # duration.is_a?(String) ? duration : duration.to_s + " D"
      # elsif start.present?
      # BuisinesDays.business_days_between(start, to).to_s + " D"
      # else
      # "1 D"
      # end

      tws.send_message IB::Messages::Outgoing::RequestHistoricalData.new(
        :request_id => con_id,
        :contract =>  self,
        :end_date_time => end_date_time, #to.to_time.to_ib, #  Time.now.to_ib,
        :duration => duration, # see ib/messages/outgoing/bar_request.rb => max duration for 5sec bar lookback is 10 000 - i.e. will yield 2000 bars
        :bar_size =>  bar_size, #  IB::BAR_SIZES.key(:hour)?
        :what_to_show => what_to_show,
        :use_rth => 0,
        :format_date => 2,
        :keep_up_todate => 0)

      recieved.pop # blocks until a message is ready on the queue or the queue is closed

      tws.unsubscribe a
      tws.unsubscribe b

      block_given? ?  bars.map{|y| yield y} : bars  # return bars or result of block

    end # def 

	end  # class
end # module

