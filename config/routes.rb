Rails.application.routes.draw do

root to: 'spa#index'

  # Simple API test endpoint used by the dashboard demo
  namespace :api do
    get 'test', to: 'test#index'
    resources :contacts, only: [:index, :create, :update, :destroy]
    resources :password_entries, only: [:index, :create, :destroy]
    resource :personal_profile, only: [:show, :create, :update]
    resource :health_profile, only: [:show, :create, :update]
    resources :companies do
      resources :quotes, only: [:index, :create, :destroy] do
        member do
          patch :accept
          patch :refuse
          get :pdf
        end
      end
      resources :invoices, only: [:index, :create, :destroy] do
        member do
          patch :mark_paid
          get :pdf
        end
        collection do
          post 'from_quote/:quote_id', action: :from_quote, as: :from_quote
        end
      end
    end
    resources :properties do
      member do
        post :add_photos
        delete 'photos/:photo_id', action: :remove_photo, as: :remove_photo
      end
    end
    resources :events, only: [:index, :create, :update, :destroy] do
      collection do
        get :upcoming
      end
    end
    get "calendar.ics", to: "calendars#feed"
    resources :tasks, only: [:index, :create, :update, :destroy]
    resources :notes, only: [:index, :create, :update, :destroy]
    resources :subscriptions, only: [:index, :create, :update, :destroy]
    resources :mail_accounts, only: [:index, :create, :update, :destroy]
    resources :projects, only: [:index, :create, :update, :destroy]
    resources :budget_entries, only: [:index, :create, :update, :destroy] do
      collection do
        get :summary
      end
    end
    resources :languages, only: [:index, :create, :update, :destroy] do
      member do
        post :log_session
        delete :unlog_session
        get :stats
      end
      collection do
        post :sync_langochat
      end
    end
    resources :useful_sites, only: [:index, :create, :update, :destroy] do
      collection do
        post :fetch_meta
      end
    end
    resources :documents, only: [:index, :create, :destroy] do
      member do
        get :download
      end
      collection do
        get :categories
      end
    end
  end

get '*path', to: 'spa#index', constraints: ->(req) { !req.xhr? && req.format.html? }
end
