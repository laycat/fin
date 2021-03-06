class Transaction < ActiveRecord::Base
  belongs_to :account, inverse_of: :transactions
  has_one :remote_account, :through => :account
  belongs_to :category
  has_one :user, :through => :account
  has_one :transaction_balance, foreign_key: "transaction_id"
  delegate :balance, :account_balance, to: :transaction_balance
  has_many :reservation_transactions
  has_many :reservations, :through => :reservation_transactions

  # validates :date??
  validates :description, presence: true
  validates :amount, presence: true
  validates :amount, numericality: true, if: "!amount.nil?"
  validates :account, presence: true
  validates :category, presence: true

  before_create :check_budget_date, :generate_order, prepend: true

  # TODO Split transactions
  
  def self.to_csv
    CSV.generate do |csv|
      csv << ["id", "sort", "date", "budget_date","description", "amount", "account_balance", "balance", "account", "category"]
      all.each do |t|
        csv << [t.id, t.sort, t.date, t.budget_date, t.description, t.amount, t.account_balance, t.balance, t.account.name, t.category.name]
      end
    end
  end

  private

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
      self.sort = self.user.transactions.maximum("sort") + 1
    end
  end
end
