#
require 'ib/gateway/account-infos'
require 'ib/gateway/order-handling'
require_relative 'alerts/gateway-alerts'
require_relative 'alerts/order-alerts'
require 'active_support/core_ext/module/attribute_accessors'   # provides m_accessor
#module GWSupport
# provide  AR4- ActiveRelation-like-methods to Array-Class
#refine  Array do
class Array 
  # returns the item (in case of first) or the hole array (in case of create)
  def first_or_create item, *condition, &b
    int_array = if condition.empty? 
	       [ find_all{ |x| x == item } ] if !block_given?
	     else
	       condition.map{ |c| find_all{|x| x[ c ] == item[ c ] }}
	     end || []
    if block_given?
      relation = yield
      part_2 = find_all{ |x| x.send( relation ) == item.send( relation ) }
      int_array <<  part_2 unless part_2.empty?
    end
    # reduce performs a logical "&" between the array-elements
    # we are only interested in the first entry
    r= int_array.reduce( :& )
    r.present? ? r.first : self.push( item ) 
  end
  def update_or_create item, *condition, &b
    member = first_or_create( item, *condition, &b) 
    self[ index( member ) ] = item  unless member.is_a?(Array)
    self  # always returns the array 
  end

  # performs [ [ array ] & [ array ] & [..] ].first
  def intercept
    a = self.dup
    s = a.pop
    while a.present?
      s = s & a.pop
    end
    s.first unless s.nil?  # return_value (or nil)
  end
end # refine / class
#end # module

module IB

=begin
The  Gateway-Class defines anything which has to be done before a connection can be established.
The Default Skeleton can easily be substituted by customized actions

The IB::Gateway can be used in three modes
(1) IB::Gateway.new( connect:true, --other arguments-- ) do | gateway |
	** subscribe to Messages and define the response  **
	# This block is executed before a connect-attempt is made 
		end
(2) gw = IB:Gateway.new
		** subscribe to Messages **
		gw.connect
(3) IB::Gateway.new connect:true, host: 'localhost' ....

Independently IB::Alert.alert_#{nnn} should be defined for a proper response to warnings, error-
and system-messages. 


The Connection to the TWS is realized throught IB::Connection. Additional to __IB::Connection.current__
IB::Gateway.tws points to the active Connection.

To support asynchronic access, the :recieved-Array of the Connection-Class is not active.
The Array is easily confused, if used in production mode with a FA-Account and has limits.
Thus IB::Conncetion.wait_for(message) is not available until the programm is called with
IB::Gateway.new  serial_array: true (, ...)



=end

  class Gateway

    include IB::Logging # provides default_logger
    include AccountInfos     # provides Handling of Account-Data provided by the tws
    include OrderHandling

    # include GWSupport   # introduces update_or_create, first_or_create and intercept to the Array-Class

    # from active-support. Add Logging at Class + Instance-Level
    # similar to the Connection-Class: current represents the active instance of Gateway
    mattr_accessor :current
    mattr_accessor :tws



		def initialize  port: 4002, # 7497,
			host: '127.0.0.1',   # 'localhost:4001' is also accepted
			client_id:  random_id,
			subscribe_managed_accounts: true,
			subscribe_alerts: true,
			subscribe_order_messages: true,
			connect: true,
			get_account_data: false,
			serial_array: false,
      logger: nil, 
			watchlists: [] ,  # array of watchlists (IB::Symbols::{watchlist}) containing descriptions for complex positions
			**other_agruments_which_are_ignored,
			&b

			host, port = (host+':'+port.to_s).split(':')

      self.class.configure_logger logger

      self.logger.info { '-' * 20 +' initialize ' + '-' * 20 }

			@connection_parameter = { received: serial_array, port: port, host: host, connect: false, logger: logger, client_id: client_id }

			@account_lock = Mutex.new
      @watchlists = watchlists.map{ |b| IB::Symbols.allocate_collection b }
			@gateway_parameter = { s_m_a: subscribe_managed_accounts,
													s_a: subscribe_alerts,
													s_o_m: subscribe_order_messages,
													g_a_d: get_account_data }


			Thread.report_on_exception = true
			# https://blog.bigbinary.com/2018/04/18/ruby-2-5-enables-thread-report_on_exception-by-default.html
			Gateway.current = self
			# initialise Connection without connecting
			prepare_connection &b
			# finally connect to the tws
			connect =  true if get_account_data

			if connect
				i = 0
				begin
					i+=1
					if connect(100)  # tries to connect for about 2h
						get_account_data()
						#    request_open_orders() if request_open_orders || get_account_data
					else
						@accounts = []   # definitivley reset @accounts
					end
				rescue IB::Error => e
					disconnect
					logger.fatal e.message
					if e.message =~ /NextLocalId is not initialized/
						Kernel.exit
					elsif i < 5
						retry
					else
						raise "could not get account data"
					end
				end
			end

		end

		def active_watchlists
			@watchlists
		end
    def add_watchlist watchlist
     new_watchlist = IB::Symbols.allocate_collection( watchlist ) 
     @watchlists <<  new_watchlist unless @watchlists.include?( new_watchlist )
    end

		def get_host
			"#{@connection_parameter[:host]}: #{@connection_parameter[:port] }"
		end

		def update_local_order order
			# @local_orders is initialized by #PrepareConnection
			@local_orders.update_or_create order, :local_id
		end


		## ------------------------------------- connect ---------------------------------------------##
=begin
Zentrale Methode
Es wird ein Connection-Objekt (IB::Connection.current) angelegt.
Sollte keine TWS vorhanden sein, wird ein entsprechende Meldung ausgegeben und der Verbindungsversuch
wiederholt.
Weiterhin meldet sich die Anwendung zur Auswertung von Messages der TWS an.

=end
		def connect maximal_count_of_retry=100

			i= -1
			begin
				tws.connect
			rescue  Errno::ECONNREFUSED => e
				i+=1
				if i < maximal_count_of_retry
					if i.zero?
						logger.info 'No TWS!'
					else
						logger.info {"No TWS        Retry #{i}/ #{maximal_count_of_retry} " }
					end
					sleep i<50 ? 10 : 60   # Die ersten 50 Versuche im 10 Sekunden Abstand, danach 1 Min.
					retry
				else
					logger.info { "Giving up!!" }
					return false
				end
			rescue Errno::EHOSTUNREACH => e
				error "Cannot connect to specified host  #{e}", :reader, true
				return false
			rescue SocketError => e
				error 'Wrong Adress, connection not possible', :reader, true
				return false
      rescue IB::Error => e
        logger.info e
			end

			# initialize @accounts (incl. aliases)
			tws.send_message( :RequestFA, fa_data_type: 3) if fa?
			logger.debug { "Communications successfully established" }
      # update open orders
      request_open_orders if @gateway_parameter[:s_o_m] || @gateway_parameter[:g_a_d]
      true #  return gatway object
		end	# def





		def reconnect
			if tws.present?
				disconnect
        sleep 0.1
			end
			logger.info "trying to reconnect ..."
			connect
		end

		def disconnect

			tws.disconnect if tws.present?
			@accounts = [] # each{|y| y.update_attribute :connected,  false }
			logger.info "Connection closed"
		end


=begin
Proxy for Connection#SendMessage
allows reconnection if a socket_error occurs

checks the connection before sending a message.

=end

		def send_message what, *args
			begin
				if	check_connection
					tws.send_message what, *args
				else
					error( "Connection lost. Could not send message  #{what}" )
				end
			end
		end

=begin
Cancels one or multible orders

Argument is either an order-object or a local_id

=end

		def cancel_order *orders


			orders.compact.each do |o|
				local_id = if o.is_a? (IB::Order)
										 logger.info{ "Cancelling #{o.to_human}" }
										 o.local_id
									 else
										 o
									 end
				send_message :CancelOrder, :local_id => local_id.to_i
			end

		end

=begin
clients returns a list of Account-Objects

If only one Account is present,  Client and Advisor are identical.

=end
		def  clients
			@accounts.find_all &:user?
		end

# is the account a financial advisor
   def fa?
     !(advisor == clients.first)
	 end


=begin
The Advisor is always the first account
=end
		def advisor
			@accounts.first
		end

=begin
account_data provides a thread-safe access to linked content of accounts

(AccountValues, Portfolio-Values, Contracts and Orders)

It returns an Array of the return-values of the block

If called without a parameter, all clients are accessed

Example

```
g = IB::Gateway.current
# thread safe access
g.account_data &:portfolio_values

g.account_data &:account_values

# primitive access
g.clients.map &:portfolio_values
g.clients.map &:account_values

```
=end

		def account_data account_or_id=nil

			safe = ->(account) do
				@account_lock.synchronize do
          yield account
				end
			end

			if block_given?
				if account_or_id.present?
					sa = account_or_id.is_a?(IB::Account) ? account_or_id :  @accounts.detect{|x| x.account == account_or_id }
					safe[sa] if sa.is_a? IB::Account
				else
					clients.map{|s| safe[s]}
				end
			end
		end




		def prepare_connection &b
			tws.disconnect if tws.is_a? IB::Connection
      self.tws = IB::Connection.new  **@connection_parameter.merge( logger: self.logger )
			@accounts = @local_orders = Array.new

			# prepare Advisor-User hierachy
			initialize_managed_accounts if @gateway_parameter[:s_m_a]
			initialize_alerts if @gateway_parameter[:s_a]
      initialize_order_handling if @gateway_parameter[:s_o_m] || @gateway_parameter[:g_a_d]
			## apply other initialisations which should apper before the connection as block
			## i.e. after connection order-state events are fired if an open-order is pending
			## a possible response is best defined before the connect-attempt is done
			# ##  Attention
			# ##  @accounts are not initialized yet (empty array)
      yield  self if block_given?


		end

=begin
InitializeManagedAccounts
defines the Message-Handler for :ManagedAccounts
Its always active.
=end

		def initialize_managed_accounts
			rec_id = tws.subscribe( :ReceiveFA )  do |msg|
				msg.accounts.each do |a|
					account_data( a.account ){| the_account | the_account.update_attribute :alias, a.alias } unless a.alias.blank?
				end
				logger.info { "Accounts initialized \n #{@accounts.map( &:to_human  ).join " \n " }" }
			end

			man_id = tws.subscribe( :ManagedAccounts ) do |msg| 
				if @accounts.empty?
					# just validate the message and put all together into an array
					@accounts =  msg.accounts_list.split(',').map do |a| 
						account = IB::Account.new( account: a.upcase ,  connected: true )
					end
				else
					logger.info {"already #{@accounts.size} accounts initialized "}
					@accounts.each{|x| x.update_attribute :connected ,  true }
				end # if
			end # subscribe do
		end # def


		def initialize_alerts

			tws.subscribe(  :AccountUpdateTime  ){| msg | logger.debug{ msg.to_human }}
			tws.subscribe(:Alert) do |msg|
				logger.debug " ----------------#{msg.code}-----"
				# delegate anything to IB::Alert
				IB::Alert.send("alert_#{msg.code}", msg )
			end
		end


		# Handy method to ensure that a connection is established and active.
		#
		# The connection is reset on the IB-side at least once a day. Then the
		# IB-Ruby-Connection has to be reestablished, too.
		#
		# check_connection reconnects if necessary and returns false if the connection is lost.
		#
		# It delays the process by 6 ms (150 MBit Cable connection)
		#
		#  a =  Time.now; G.check_connection; b= Time.now ;b-a
		#   => 0.00066005
		#
		def check_connection
      q =  Queue.new 
      count = 0
      result = nil
      z= tws.subscribe( :CurrentTime ) { q.push true }
			loop do
				begin
					tws.send_message(:RequestCurrentTime)												# 10 ms  ##
          th = Thread.new{ sleep 1 ; q.push nil }
          result =  q.pop 
          count+=1
          break if result || count > 10
				rescue IOError, Errno::ECONNREFUSED   # connection lost
					count +=1 
          retry
				rescue IB::Error # not connected
					reconnect 
					count = 0
					retry
				end
			end
			tws.unsubscribe z
			result #  return value
		end
	private

	def random_id
		rand 99999
	end

	end  # class

end # module

