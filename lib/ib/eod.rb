module IB

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
		# Receive EOD-Data 
		#  
		# The Enddate has to be specified (as Date Object)
		#
		# The Duration can either be specified as Sting " yx D" or as Integer. 
		# Altenative a start date can be specified with the :start parameter.
		#
		# The parameter :what specified the kind of received data: 
		#  Valid values:
		#   :trades, :midpoint, :bid, :ask, :bid_ask,
		#   :historical_volatility, :option_implied_volatility,
		#   :option_volume, :option_open_interest
		# 
		# The results are available through a block, thus
		#  
		#     contract =  IB::Symbols::Index.stoxx.verify!
		#		  contract.eod( duration: '10 d' ) do | results |
		#		    results.each{ |s| puts s.to_human }
		#		  end
		#		   
		#
		#   Symbols::Index::stoxx.verify!.eod( duration: '10 d',  to: Date.today){|y| y.each{|z| puts z.to_human}}
		#   <Bar: 2019-04-01 wap 0.0 OHLC 3353.67 3390.98 3353.67 3385.38 trades 1750 vol 0>
		#   <Bar: 2019-04-02 wap 0.0 OHLC 3386.18 3402.77 3382.84 3395.7 trades 1729 vol 0>
		#   <Bar: 2019-04-03 wap 0.0 OHLC 3399.93 3435.9 3399.93 3435.56 trades 1733 vol 0>
		#   <Bar: 2019-04-04 wap 0.0 OHLC 3434.34 3449.44 3425.19 3441.93 trades 1680 vol 0>
		#   <Bar: 2019-04-05 wap 0.0 OHLC 3445.05 3453.01 3437.92 3447.47 trades 1677 vol 0>
		#   <Bar: 2019-04-08 wap 0.0 OHLC 3446.15 3447.08 3433.47 3438.06 trades 1648 vol 0>
		#   <Bar: 2019-04-09 wap 0.0 OHLC 3437.07 3450.69 3416.67 3417.22 trades 1710 vol 0>
		#   <Bar: 2019-04-10 wap 0.0 OHLC 3418.36 3435.32 3418.36 3424.65 trades 1670 vol 0>
		#   eBar: 2019-04-11 wap 0.0 OHLC 3430.73 3442.25 3412.15 3435.34 trades 1773 vol 0>
		#   <Bar: 2019-04-12 wap 0.0 OHLC 3432.16 3454.77 3425.84 3447.83 trades 1715 vol 0>
		#
		#    Symbols::Futures::mini_dax.eod( duration: '10 d',  to: Date.today){|y| y.each{|z| puts z.to_human}}
		#   <Bar: 2020-09-23 wap 12703.4 OHLC 12647.0 12809.0 12506.0 12631.0 trades 28125 vol 44456>
		#   <Bar: 2020-09-24 wap 12575.5 OHLC 12502.0 12674.0 12439.0 12583.0 trades 42847 vol 63952>
		#   <Bar: 2020-09-25 wap 12456.2 OHLC 12645.0 12693.0 12317.0 12421.5 trades 32886 vol 51720>
		#   <Bar: 2020-09-28 wap 12766.9 OHLC 12556.0 12866.0 12543.0 12849.0 trades 23649 vol 37770>
		#   <Bar: 2020-09-29 wap 12791.0 OHLC 12881.0 12929.0 12718.0 12797.0 trades 29808 vol 43414>
		#   <Bar: 2020-09-30 wap 12762.25 OHLC 12829.0 12880.0 12668.0 12779.0 trades 40230 vol 59884>
		#   <Bar: 2020-10-01 wap 12737.45 OHLC 12774.0 12842.0 12651.0 12692.5 trades 35234 vol 53122>
		#   <Bar: 2020-10-02 wap 12606.55 OHLC 12683.0 12723.0 12520.0 12662.0 trades 40192 vol 61242>
		#   <Bar: 2020-10-05 wap 12772.05 OHLC 12767.0 12874.0 12709.0 12820.0 trades 25390 vol 37778>
		#   <Bar: 2020-10-06 wap 12856.7 OHLC 12855.0 12950.0 12759.0 12899.5 trades 32128 vol 47322>
		def eod start:nil, to: Date.today, duration: nil , what: :trades 

			tws = IB::Connection.current
			recieved =  Queue.new

			tws.subscribe(IB::Messages::Incoming::HistoricalData) do |msg|
				if msg.request_id == con_id
					#					msg.results.each { |entry| puts "  #{entry}" }
					yield msg.results if block_given?
				end
				recieved.push Time.now
			end

			duration =  if duration.present?
										duration.is_a?(String) ? duration : duration.to_s + " D"
									elsif start.present?
										BuisinesDays.business_days_between(start, to).to_s + " D"
									else
										"1 D"
									end

			tws.send_message IB::Messages::Outgoing::RequestHistoricalData.new(
				:request_id => con_id,
				:contract =>  self,
				:end_date_time => to.to_time.to_ib, #  Time.now.to_ib,
				:duration => duration, #    ?
				:bar_size => :day1, #  IB::BAR_SIZES.key(:hour)?
				:what_to_show => what,
				:use_rth => 0,
				:format_date => 2,
				:keep_up_todate => 0)

			Timeout::timeout(50) do   # max 5 sec.
				sleep 0.1 
				last_time =  recieved.pop # blocks until a message is ready on the queue
				loop do
					sleep 0.1
					break if recieved.empty?  # finish if no more data received
				end
			end
		end # def
	end  # class
end # module

