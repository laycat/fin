Fin::Application.routes.draw do

  root :to => 'transactions#index'

  resources :users, except: [:index, :show]
  resources :user_sessions
  resources :accounts, except: :show
  resources :categories, except: :show
  resources :transactions, except: [:show, :new]
  resources :budgets do
    resources :reservations
  end

  get '/transactions/filter' => 'transactions#filter', :as => :transactions_filter
  get '/transactions/import' => 'transactions#import', :as => :transactions_import
  post '/transactions/import' => 'transactions#load_import', :as => :transactions_load_import
  get '/transactions/import/errors' => 'transactions#import_errors', :as => :transactions_import_errors
  get '/budgets/latest' => 'budgets#show', :as => :latest_budget

  get 'login' => 'user_sessions#new', :as => :login
  post 'logout' => 'user_sessions#destroy', :as => :logout
end
