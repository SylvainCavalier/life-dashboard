Rails.application.routes.draw do
  # Connexion uniquement : pas d'inscription publique, pas de reinitialisation
  # de mot de passe par mail (aucun mailer n'est configure en production).
  # Le compte proprietaire se gere via `rails owner:create` / `owner:reset_password`.
  devise_for :users, skip: [:registrations, :passwords], controllers: {
    sessions: 'users/sessions'
  }

  # Changement de mot de passe par le proprietaire, une fois connecte.
  get   "account/password", to: "users/password_changes#edit",   as: :account_password
  patch "account/password", to: "users/password_changes#update"

  # Sonde de disponibilite (Heroku, monitoring externe). Herite de
  # ActionController::Base, donc hors du perimetre de authenticate_user!.
  get "up", to: "rails/health#show", as: :rails_health_check

  root to: 'spa#index'

  # Simple API test endpoint used by the dashboard demo
  namespace :api do
    get 'test', to: 'test#index'
    resources :contacts, only: [:index, :create, :update, :destroy]
    resources :crm_profiles, only: [:index, :create, :update, :destroy]
    resources :password_entries, only: [:index, :create, :destroy] do
      member { get :reveal }
    end
    resource :personal_profile, only: [:show, :create, :update]
    resource :health_profile, only: [:show, :create, :update]
    resources :companies do
      member do
        get :budget
      end
      resources :clients, only: [:index, :create, :update, :destroy]
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
    # Flux ICS : ?token=... pour les clients calendrier, session Devise sinon.
    get "calendar.ics", to: "calendars#feed"
    resources :tasks, only: [:index, :create, :update, :destroy]
    resources :notes, only: [:index, :create, :update, :destroy]
    resources :subscriptions, only: [:index, :create, :update, :destroy]
    resources :mail_accounts, only: [:index, :create, :update, :destroy]
    # Module Projets : competences a apprendre et liens imbriques ; la to-do list et les
    # documents d'un projet passent par /tasks et /documents avec ?project_id=
    resources :projects, only: [:index, :show, :create, :update, :destroy] do
      collection { get :categories }
      resources :project_skills, only: [:create, :update, :destroy]
      resources :project_links, only: [:create, :update, :destroy]
    end
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
    resources :documents, only: [:index, :create, :update, :destroy] do
      member do
        get :download
      end
      collection do
        get :categories
      end
    end

    resources :file_transfers, only: [:index, :create, :destroy]

    # Module Downloader : telechargements yt-dlp (GET /availability = binaires presents ?,
    # GET /:id/file = fichier local ou redirection vers l'URL pre-signee OVH)
    resources :video_folders, only: [:index, :show, :create, :update, :destroy]
    resources :video_downloads, only: [:index, :show, :create, :destroy] do
      collection { get :availability }
      member { get :file }
    end

    # Module Voyages : rapport IA (POST /plan, asynchrone) et planning jour par jour
    resources :trips do
      member { post :plan }
      resources :trip_items, only: [:create, :update, :destroy]
    end

    # CV module
    resources :cv_experiences, only: [:index, :create, :update, :destroy]
    resources :cv_formations, only: [:index, :create, :update, :destroy]
    resources :cv_skills, only: [:index, :create, :update, :destroy]
    resources :cv_interests, only: [:index, :create, :update, :destroy]
    resource :cv_setting, only: [:show, :update] do
      delete :photo, action: :destroy_photo
    end
    get  "cv/data",        to: "cvs#data"
    post "cv/export_pdf",  to: "cvs#export_pdf"
  end

  # Liens publics de partage de fichiers (WeTransfer perso)
  get 't/:token', to: 'transfers#show', as: :transfer
  get 't/:token/download', to: 'transfers#download', as: :download_transfer

get '*path', to: 'spa#index', constraints: ->(req) { !req.xhr? && req.format.html? }
end
