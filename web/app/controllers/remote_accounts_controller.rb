class RemoteAccountsController < ApplicationController
  # TODO before create and update check that remote account type exists
  before_filter :require_login
  before_action :set_account, only: [:new, :edit, :create, :update, :destroy, :get_credentials, :sync]
  before_action :set_remote_account, only: [:edit, :update, :destroy, :get_credentials, :sync]
  
  def index
    @remote_accounts = current_user.remote_accounts
  end

  def new
    @remote_account = RemoteAccount.new
    @remote_account_types = RemoteAccountType.all
  end

  def edit
    @remote_account = current_user.remote_accounts.find(params[:id])
    @remote_account_types = RemoteAccountType.all
  end

  def create
    @remote_account = RemoteAccount.new(remote_account_params)
    @remote_account.account = @account

    if @remote_account.save
      redirect_to accounts_path, notice: 'Remote Account was successfully created.'
    else
      @remote_account_types = RemoteAccountType.all
      render action: 'new'
    end
  end

  def update
    if @remote_account.update(remote_account_params)
      redirect_to accounts_path, notice: 'Remote Account was successfully updated.'
    else
      render action: 'edit'
    end
  end

  def destroy
    @remote_account.destroy
    redirect_to accounts_path, notice: 'Remote Account was successfully deleted.'
  end

  def get_credentials
    @credentials = ['pin', 'password'] if @remote_account.remote_account_type.title == 'natwest'
    @credentials = ['password'] if @remote_account.remote_account_type.title == 'amex'
  end

  def sync
    credentials = credential_params
    unassigned = current_user.categories.where(name: 'unassigned').first
    
    start_date = Date.today.to_s
    last_synced = @remote_account.transactions.maximum(:remote_date)
    end_date = last_synced.nil? ? @remote_account.sync_from.to_s : [last_synced, @remote_account.sync_from].max.to_s

    # p(@remote_account)
    # p(@remote_account.remote_account_type)
    # p(@remote_account.remote_account_type.title)
    # p(credentials)
    transactions = []

    if @remote_account.remote_account_type.title == 'natwest'
      credentials['customer_number'] = @remote_account.user_credential
      Natwest::Customer.new.tap do |nw|
        nw.login credentials
        transactions = nw.transactions(end_date, start_date, @remote_account.remote_account_identifier).reverse
        #p transactions 
      end
    elsif @remote_account.remote_account_type.title == 'amex'
      credentials['username'] = @remote_account.user_credential
      Amex.new.tap do |am| 
        begin
          # FIXME catch exceptions
          am.login credentials
          transactions = am.transactions(end_date, start_date, @remote_account.remote_account_identifier).reverse
        ensure
          am.close
        end
      end
    end

    #p(transactions)

    transactions.each do |t|
      # puts "#{t[:date]}##{t[:description]}##{t[:amount]}"
      if current_user.transactions.where(remote_identifier: "#{t[:date]}##{t[:description]}##{t[:amount]}").count == 0
        t = Transaction.new(date: t[:date], description: t[:description], amount: t[:amount], account: @account, category: unassigned, remote_identifier: "#{t[:date]}##{t[:description]}##{t[:amount]}")
        if @remote_account.inverse_values
          t.amount = -t.amount
        end
        t.save
        # puts t.errors.inspect
        # TODO did the transaction save successfully? where to pipe errors?
      end
    end
    # TODO check whether sync was successful and return: took x seconds, synced between, saved x transactions successfully, x failed
    redirect_to transactions_path, notice: 'sync complete, not sure if it was successful tho'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
  
    def set_account
      @account = current_user.accounts.find(params[:account_id])
      puts @account.inspect
    end

    def set_remote_account
      @remote_account = current_user.remote_accounts.find(params[:id])
    end

    def credential_params
      params.require(:credentials).permit(:pin, :password)
    end

    def remote_account_params
      params.require(:remote_account).permit(:title, :inverse_values, :user_credential, :remote_account_identifier, :remote_account_type_id, :sync_from)
    end
end