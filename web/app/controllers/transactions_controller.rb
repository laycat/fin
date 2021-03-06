class TransactionsController < ApplicationController
  before_filter :require_login
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]
  before_action :set_transactions, only: [:index, :filter]
  before_action :set_accounts_and_categories, only: [:index, :filter]

  # FIXME prevent viewing transactions that aren't yours
  # FIXME prevent editing transactions that aren't yours
  # FIXME prevent deleting transactions that aren't yours

  def index
    respond_to do |format|
      @transaction_filter = transaction_filter_params
      @transactions = filter_transactions(current_user.transactions.includes(:transaction_balance, :account).order(date: :desc, id: :desc), @transaction_filter)
      format.json { render json: @transactions }
      format.html {
        #@transactions = @transactions.where(date: (Date.today-1.month..Date.today))
        @transactions = @transactions.limit(150).offset(@transaction_filter[:offset])
        @new_transaction = Transaction.new(category: current_user.categories.where(name: "unassigned").first)
        #@category_breakdown = set_category_breakdown(@transactions)
        #@total_income, @total_expenditure, @balance_diff = set_metrics(@transactions)
      }
      format.csv {
        send_data @transactions.to_csv, filename: "transactions-#{Time.now.strftime("%Y%m%dT%H%M")}.csv"
      }
    end
  end

  def show
    respond_to do |format|
      format.json{ render json: @transaction.to_json(methods: [:balance, :account_balance]) }
      format.html{ render html: nil }
    end
  end

  def edit
  end

  def create
    @new_transaction = Transaction.new(transaction_params)
    if @new_transaction.save
      # mark transaction and any after to be updated
      # for each, mark reservations that need to be updated
      # trigger balance updater
      redirect_to transactions_path, notice: 'Transaction was successfully created.'
    else
      @transaction_filter = {description: nil}
      @transactions = current_user.transactions.order(:sort) # TODO need to be set? order(:order)?
      render action: 'index'
    end
  end

  def update
    if @transaction.update(transaction_params) 
      respond_to do |format|
        format.html { redirect_to transactions_path, notice: 'Transaction was successfully updated.' }
        format.json { render json: @transaction }
      end
    else
      respond_to do |format|
        format.html { render action: 'edit' }
        format.json { render json: @transaction.errors.full_messages, status: 422 } 
      end
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_path
  end

  def import
  end

  #def load_import
  #  # change to a method in an import controller?
  #  @@import_errors = [] # FIXME move import errors from class var to session
  #  successful = 0
  #  errors = 0
  #  min_sort_transaction = nil
  #  accounts_to_update = []

  #  if params[:file].blank?
  #    flash[:alert] = "No file selected!"
  #    redirect_to transactions_import_path
  #  else
  #    CSV.foreach(params[:file].path,headers: true) do |row|
  #      user_txs = current_user.transactions
  #      t = user_txs.find_by_id(row["id"]) || Transaction.new
  #      t.attributes = row.to_hash.slice("sort", "date", "budget_date", "description", "amount")
  #      t.account = Account.where(name: row["account"], user: current_user).first || Account.create(name: row["account"], user: current_user)
  #      if row["category"].nil?
  #        t.category = Category.where(name: "unassigned", user: current_user).first
  #      else
  #        t.category = Category.where(name: row["category"], user: current_user).first || Category.create(name: row["category"], user: current_user)
  #      end
  #      t.update_balance = false
  #      if t.save
  #        min_sort_transaction = t if min_sort_transaction.nil? || min_sort_transaction.sort > t.sort
  #        accounts_to_update << t.account_id unless accounts_to_update.include?(t.account_id)
  #        successful += 1
  #      else
  #        @@import_errors << [row.to_hash, t.errors.full_messages]
  #        errors += 1
  #      end
  #    end
  #    min_sort_transaction.update_balance = true
  #    logger.debug { 'transactions_controller.rb : load_import loop done' }
  #    logger.debug { "accounts_to_update: #{accounts_to_update.inspect}" }
  #    min_sort_transaction.update_transaction_balances(accounts_to_update)
  #    notice = "Import complete: #{successful.to_s} successfully imported"
  #    if errors > 0
  #      notice += ", #{errors.to_s} skipped through errors (#{view_context.link_to("Download errors as CSV", transactions_import_errors_path(format: "csv"))})"
  #    end
  #    flash[:notice] = notice.html_safe
  #    redirect_to transactions_path
  #  end
  #end

  #def import_errors
  #  respond_to do |format|
  #    format.csv {
  #      file = CSV.generate do |csv|
  #        keys = @@import_errors[0][0].keys
  #        keys << "error"
  #        csv << keys
  #        puts @@import_errors.inspect
  #        @@import_errors.each do |e|
  #          row = []
  #          e[0].values.each do |val|
  #            row << val
  #          end
  #          row << e[1][0]
  #          csv << row
  #        end
  #      end
  #      send_data file
  #    }
  #  end
  #end

  private
    def set_transaction
      @transaction = current_user.transactions.find(params[:id])
    end

    def set_transactions
      @transactions = current_user.transactions.includes(:account, :category, :transaction_balance).order(date: :desc, description: :asc, id: :asc)
    end

    def set_accounts_and_categories
      @accounts = current_user.accounts.order(name: :asc)
      @categories = current_user.categories.order(name: :asc)
    end

    def transaction_params
      # JSON accept data?
      params.require(:transaction).permit(:sort, :date, :budget_date, :description, :amount, :account_id, :category_id)
    end

    def transaction_filter_params
      params.permit(:date_from, :date_to, :budget_date_from, :budget_date_to, :description, :account, :category, :offset)
    end

    def filter_transactions(transactions, transaction_filter) # FIXME category and account selected don't persist
      # TODO add offset
      if transaction_filter[:date_from].present? && transaction_filter[:date_to].present?
        transactions = transactions.where(date: (transaction_filter[:date_from]..transaction_filter[:date_to]))
      end
      if transaction_filter[:budget_date_from].present? && transaction_filter[:budget_date_to].present?
        transactions = transactions.where(budget_date: (transaction_filter[:budget_date_from]..transaction_filter[:budget_date_to]))
      end
      if transaction_filter[:description].present?
        transactions = transactions.where("description ILIKE :search", search: "%#{transaction_filter[:description]}%")
      end
      if transaction_filter[:category].present?
        category = current_user.categories.where(name: transaction_filter[:category]).first
        transactions = transactions.where(category: category)
      end
      if transaction_filter[:account].present?
        account = current_user.accounts.where(name: transaction_filter[:account]).first
        transactions = transactions.where(account: account)
      end
      return transactions
    end

    def set_category_breakdown(transactions)
      category_breakdown = Hash.new
      current_user.categories.each do |category|
        category_transactions = transactions.where(category: category)
        if category_transactions.present?
          category_breakdown[category.name] = category_transactions.sum('amount')
        end
      end
      category_breakdown = Hash[category_breakdown.sort_by{|key, val| val}.reverse]
      return category_breakdown
    end

    def set_metrics(transactions)
      total_income = transactions.where('amount > 0').sum('amount') # TODO Is this useful? Transfers skew this
      total_expenditure = transactions.where('amount < 0').sum('amount')
      balance_diff = total_income + total_expenditure
      return [total_income, total_expenditure, balance_diff]
    end
end
