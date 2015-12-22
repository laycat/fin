class Transaction < ActiveRecord::Base
  belongs_to :account
  has_one :remote_account, :through => :account
  belongs_to :category
  has_one :user, :through => :account
  has_one :transaction_with_balance, foreign_key: "transaction_id"
  delegate :balance, :account_balance, to: :transaction_with_balance

  validates :description, presence: true
  validates :amount, presence: true
  validates :amount, numericality: true, if: "!amount.nil?"
  validates :account, presence: true
  validates :category, presence: true

  before_create :check_budget_date, :generate_order, prepend: true
  #after_create :update_transaction_balances, :update_budget_balances
  #after_update :update_transaction_balances, :update_budget_balances
  #after_destroy :update_transaction_balances, :update_budget_balances

  # TODO Split transactions
  
  #def self.to_csv
  #  CSV.generate do |csv|
  #    csv << ["id", "sort", "date", "budget_date","description", "amount", "account_balance", "balance", "account", "category"]
  #    all.each do |t|
  #      csv << [t.id, t.sort, t.date, t.budget_date, t.description, t.amount, t.account_balance, t.balance, t.account.name, t.category.name]
  #    end
  #  end
  #end

  def check_budget_date
    if self.budget_date.blank?
      self.budget_date = self.date
    end
  end

  def generate_order
    # TODO Surley this could look a bit nicer? a = b? c : d
    if self.user.transactions.empty?
      self.sort = 1
    else
      self.sort = self.user.transactions.order(sort: :desc).first.sort + 1
    end
  end

  # FIXME What?!
  #def tx_logger
  #  @@tx_logger ||= Logger.new("#{Rails.root}/log/tx.log")
  #end

  #def update_transaction_balances(*args) # It's a bit obscure, but args[0] = accounts_to_update is used in csv import

  #  if !self.destroyed? && self.update_balance == false
  #    self.update_balance = nil
  #    # logger.debug { 'transaction.rb : update_transaction_balances Caught update_balance = false, returning' }
  #    return
  #  end

  #  logger.debug { "Updating tx #{self.id}: New? #{self.id_was.nil?} Destroyed? #{self.destroyed?} Changes #{self.changed}" }

  #  recalculate_balance = true
  #  if self.update_balance == true
  #    sort_min = self.sort
  #    accounts_to_update = args[0]
  #    #logger.debug { "accounts_to_update: #{accounts_to_update.inspect}" }
  #    account_to_update_balances = {}
  #    accounts_to_update.each do |account_id|
  #      account_to_update_balances[account_id] = 0
  #    end
  #    to_update = self.user.transactions.where("sort >= ?", sort_min).order(sort: :asc)
  #  elsif self.id_was.nil? || self.destroyed? 
  #    sort_min = self.sort
  #    account_to_update_balances = {self.account_id => 0}
  #    to_update = self.user.transactions.where("sort >= ?", sort_min).order(sort: :asc)
  #  elsif (["amount", "account_id", "sort"] - self.changed).empty?
  #    sort_min = [self.sort, self.sort_was].min
  #    account_to_update_balances = {self.account_id => 0, self.account_id_was => 0}
  #    to_update = self.user.transactions.where("sort >= ?", sort_min).order(sort: :asc)
  #  elsif (["amount", "sort"] - self.changed).empty?
  #    sort_min = [self.sort, self.sort_was].min
  #    account_to_update_balances = {self.account_id => 0}
  #    to_update = self.user.transactions.where("sort >= ?", sort_min).order(sort: :asc)
  #  elsif (["amount", "account_id"] - self.changed).empty?
  #    sort_min = self.sort
  #    account_to_update_balances = {self.account_id => 0, self.account_id_was => 0}
  #    to_update = self.user.transactions.where("sort >= ?", sort_min).order(sort: :asc)
  #  elsif (["account_id", "sort"] - self.changed).empty?
  #    sort_min = [self.sort, self.sort_was].min
  #    sort_max = [self.sort, self.sort_was].max
  #    account_to_update_balances = {self.account_id => 0, self.account_id_was => 0}
  #    to_update = self.user.transactions.where(sort: sort_min..sort_max).order(sort: :asc)
  #  elsif (["amount"] - self.changed).empty?
  #    sort_min = self.sort
  #    account_to_update_balances = {self.account_id => 0}
  #    to_update = self.user.transactions.where("sort >= ?", sort_min).order(sort: :asc)
  #  elsif (["account_id"] - self.changed).empty?
  #    sort_min = self.sort
  #    account_to_update_balances = {self.account_id => 0, self.account_id_was => 0}
  #    to_update = self.user.transactions.where("sort >= ?", sort_min).order(sort: :asc)
  #    recalculate_balance = false
  #  elsif (["sort"] - self.changed).empty?
  #    sort_min = [self.sort, self.sort_was].min
  #    sort_max = [self.sort, self.sort_was].max
  #    account_to_update_balances = {self.account_id => 0}
  #    to_update = self.user.transactions.where(sort: sort_min..sort_max).order(sort: :asc)
  #  end

  #  logger.debug { "Gonna update #{to_update.count}" }

  #  if to_update.present?

  #    if recalculate_balance
  #      last_tx = self.user.transactions.where("sort < ?", sort_min).order(sort: :desc).first
  #      balance = last_tx.nil? ? 0 : last_tx.balance
  #    end

  #    account_to_update_balances.keys.each do |account_id|
  #      last_account_tx = self.user.transactions.where("sort < ?", sort_min).where(account_id: account_id).order(sort: :desc).first
  #      account_to_update_balances[account_id] = last_account_tx.nil? ? 0 : last_account_tx.account_balance
  #    end

  #    ActiveRecord::Base.transaction do
  #      to_update.each do |tx|
  #        if recalculate_balance
  #          balance += tx.amount
  #          tx.update_columns(balance: balance)
  #        end

  #        if account_to_update_balances.include?(tx.account_id)
  #          account_to_update_balances[tx.account_id] += tx.amount
  #          tx.update_columns(account_balance: account_to_update_balances[tx.account_id])
  #        end
  #      end
  #    end

  #  end

  #end

  #def update_budget_balances
  #  # logger.debug { 'transaction.rb : update_budget_balances' }    
  #  # OPTIMIZE: deltas!

  #  if self.id_was.nil? || self.destroyed?
  #    budgets = self.user.budgets.where('start_date <= :budget_date and end_date >= :budget_date', { budget_date: self.budget_date })
  #    reservations = self.user.reservations.where(budget_id: budgets.collect{|b| b.id}, category_id: [nil, self.category_id])
  #  elsif (["category_id", "budget_date"] - self.changed).empty?
  #    budgets = self.user.budgets.where('(start_date <= :budget_date AND end_date >= :budget_date) OR \
  #      (start_date <= :budget_date_was AND end_date >= :budget_date_was)', { budget_date: self.budget_date, budget_date_was: self.budget_date_was })
  #    reservations = self.user.reservations.where(budget_id: budgets.collect{|b| b.id}, category_id: [nil, self.category_id, self.category_id_was])
  #  elsif (["budget_date"] - self.changed).empty?
  #    budgets = self.user.budgets.where('(start_date <= :budget_date AND end_date >= :budget_date) OR \
  #      (start_date <= :budget_date_was AND end_date >= :budget_date_was)', { budget_date: self.budget_date, budget_date_was: self.budget_date_was })
  #    reservations = self.user.reservations.where(budget_id: budgets.collect{|b| b.id}, category_id: [nil, self.category_id])
  #  elsif (["category_id"] - self.changed).empty?
  #    budgets = self.user.budgets.where('start_date <= :budget_date and end_date >= :budget_date', { budget_date: self.budget_date })
  #    reservations = self.user.reservations.where(budget_id: budgets.collect{|b| b.id}, category_id: [nil, self.category_id, self.category_id_was])
  #  elsif (["amount"] - self.changed).empty?      
  #    budgets = self.user.budgets.where('start_date <= :budget_date and end_date >= :budget_date', { budget_date: self.budget_date })
  #    reservations = self.user.reservations.where(budget_id: budgets.collect{|b| b.id}, category_id: [nil, self.category_id])
  #  end

  #  if !reservations.nil?
  #    reservations.each do |reservation|
  #      reservation.update_reservation_balance
  #    end
  #  end

  #  if !budgets.nil?
  #    budgets.each do |budget|
  #      budget.update_budget_balance
  #    end
  #  end
  #end

end
