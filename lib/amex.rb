require 'watir'
require 'date'

class Amex
  def initialize
    @ua = Watir::Browser.start("https://www.americanexpress.com/uk")
  end

  def close
    @ua.close
  end
  
  def login(credentials)
    @ua.text_field(name: "UserID").set(credentials[:username])
    @ua.text_field(name: "Password").set(credentials[:password])
    @ua.form(id: 'ssoform').submit
  end

  def transactions(start_date, end_date, account)
    @ua.link(text: "Your Statement").click
    @ua.link(id: "date-layer-link").click
    @ua.link(text: "Date range").click
    #puts "from: #{start_date}"
    @ua.div(id: "from-datepicker").select_list(class: "ui-datepicker-year").select(Date.parse(start_date).strftime("%Y"))
    @ua.div(id: "from-datepicker").select_list(class: "ui-datepicker-month").select_value(Date.parse(start_date).strftime("%-m").to_i - 1)
    @ua.div(id: "from-datepicker").link(text: Date.parse(start_date).strftime("%-d")).click
    #puts "to: #{end_date}"
    @ua.div(id: "to-datepicker").select_list(class: "ui-datepicker-year").select(Date.parse(end_date).strftime("%Y"))
    @ua.div(id: "to-datepicker").select_list(class: "ui-datepicker-month").select_value(Date.parse(end_date).strftime("%-m").to_i - 1)
    @ua.div(id: "to-datepicker").link(text: Date.parse(end_date).strftime("%-d")).click

    @ua.link(id: "date-go-button").click

    cp = @ua.div(id: "statement-data-table_info").text
    prev_cp = ''
    text = []

    until prev_cp == cp
      text += @ua.table(id: "statement-data-table").tbody.text.split(/\n/)
      #ap @ua.link(id: "statement-data-table_next").methods
      if @ua.link(id: "statement-data-table_next").visible?
        @ua.link(id: "statement-data-table_next").click
      end
      prev_cp = cp
      cp = @ua.div(id: "statement-data-table_info").text
    end

    i = 0
    transactions = []
    while i*3 < text.size do
      transaction = {}
      transaction[:date] = Date.parse(text[i*3])
      transaction[:description] = text[i*3 + 1]
      # TODO parse different currencies
      transaction[:amount] = text[i*3 + 2].split(/ /).last.tr('£','').to_f
      transactions << transaction
      i = i + 1
    end

    return transactions
  end
end
