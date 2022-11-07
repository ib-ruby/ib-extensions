require 'ib/alerts/base-alert'
require 'ib/models/account'

module IB
	class Alert
		class << self
			def alert_2101 msg
        IB::Connection.logger.error {msg.message}
				@status_2101 = msg.dup	
			end

			def status_2101 account # resets status and raises IB::TransmissionError
				error account.account + ": " +@status_2101.message, :reader unless @status_2101.nil?
				@status_2101 = nil  # always returns nil 
			end
		end
	end 
end #  module

module AccountInfos

=begin
Queries the tws for Account- and PortfolioValues
The parameter can either be the account_id, the IB::Account-Object or 
an Array of account_id and IB::Account-Objects.

Resets Account#portfolio_values and -account_values

Raises an IB::TransmissionError if the account-data are not transmitted in time (1 sec)

Raises an IB::Error if less then 100 items are received.
=end
  def get_account_data  *accounts, **compatibily_argument


		subscription = subscribe_account_updates( continuously: false )
    download_end = nil  # declare variable

		accounts = clients if accounts.empty?
    IB::Connection.logger.warn{ "No active account present. AccountData are NOT requested" } if accounts.empty?
		# Account-infos have to be requested sequentially. 
		# subsequent (parallel) calls kill the former on the tws-server-side
		# In addition, there is no need to cancel the subscription of an request, as a new
		# one overwrites the active one.
		accounts.each do | ac |
			account =  ac.is_a?( IB::Account ) ?  ac  : clients.find{|x| x.account == ac } 
			error( "No Account detected " )  unless account.is_a? IB::Account
			# don't repeat the query until 170 sec. have passed since the previous update
			if account.last_updated.nil?  || ( Time.now - account.last_updated ) > 170 # sec   
        IB::Connection.logger.debug{ "#{account.account} :: Requesting AccountData " }
        q =  Queue.new
        download_end = tws.subscribe( :AccountDownloadEnd )  do | msg |
          q.push true if msg.account_name == account.account
        end
				# reset account and portfolio-values
				account.portfolio_values = []
				account.account_values = []
        # Data are gathered asynchron through the active subscription through `subscribe_account_updates`
				send_message :RequestAccountData, subscribe: true, account_code: account.account

        th =  Thread.new{   sleep 10 ; q.close  }
        q.pop

        error "No AccountData received", :reader  if q.closed?
        tws.unsubscribe download_end  

        account.organize_portfolio_positions  unless IB::Gateway.current.active_watchlists.empty?
			else
        IB::Connection.logger.info{ "#{account.account} :: Using stored AccountData " }
			end
		end
    tws.send_message :RequestAccountData, subscribe: false  ## do this only once
    tws.unsubscribe subscription
  rescue IB::TransmissionError => e
        tws.unsubscribe download_end unless download_end.nil?
        tws.unsubscribe subscription
        raise
	end


  def all_contracts
		clients.map(&:contracts).flat_map(&:itself).uniq(&:con_id)
  end


	private

	# The subscription method should called only once per session.
	# It places subscribers to AccountValue and PortfolioValue Messages, which should remain
	# active through the session.
  #
  # The method returns the subscription-number.
  #
  # thus
  #    subscription =  subscribe_account_updates
  #    #  some code
  #    IB::Connection.current.unsubscribe subscription
  #
  # clears the subscription
	#
	
	def subscribe_account_updates continuously: true
		tws.subscribe( :AccountValue, :PortfolioValue,:AccountDownloadEnd )  do | msg |
			account_data( msg.account_name ) do | account |   # enter mutex controlled zone
				case msg
				when IB::Messages::Incoming::AccountValue
					account.account_values << msg.account_value
					account.update_attribute :last_updated, Time.now
          IB::Connection.logger.debug { "#{account.account} :: #{msg.account_value.to_human }"}
				when IB::Messages::Incoming::AccountDownloadEnd 
					if account.account_values.size > 10
							# simply don't cancel the subscription if continuously is specified
							# the connected flag is set in any case, indicating that valid data are present
  #          tws.send_message :RequestAccountData, subscribe: false, account_code: account.account unless continuously
						account.update_attribute :connected, true   ## flag: Account is completely initialized
            IB::Connection.logger.info { "#{account.account} => Count of AccountValues: #{account.account_values.size}"  }
					else # unreasonable account_data received -  request is still active
						error  "#{account.account} => Count of AccountValues too small: #{account.account_values.size}" , :reader 
					end
				when IB::Messages::Incoming::PortfolioValue
          account.contracts << msg.contract unless account.contracts.detect{|y| y.con_id == msg.contract.con_id }
          account.portfolio_values << msg.portfolio_value 
#						msg.portfolio_value.account = account
#           # link contract -> portfolio value
#						account.contracts.find{ |x| x.con_id == msg.contract.con_id }
#								.portfolio_values
#								.update_or_create( msg.portfolio_value ) { :account } 
          IB::Connectiom.logger.debug { "#{ account.account } :: #{ msg.contract.to_human }" }
        end # case
			end # account_data 
		end # subscribe
	end  # def 


end # module
