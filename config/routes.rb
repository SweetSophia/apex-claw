Rails.application.routes.draw do
  # API routes
  namespace :api do
    namespace :v1 do
      resource :settings, only: [ :show, :update ]

      resources :agents, only: [ :index, :show, :update ] do
        collection do
          post :register
        end

        member do
          post :heartbeat
          post :rotate_token
          post :revoke_token
          post :commands, to: "agent_commands#enqueue"
          post :archive
          post :restore
          get :tasks
        end

        resource :rate_limit, only: [ :show, :update ], controller: "agent_rate_limits"
      end

      resources :agent_commands, only: [] do
        collection do
          get :next, to: "agent_commands#next"
        end

        member do
          patch :ack, to: "agent_commands#ack"
          patch :complete, to: "agent_commands#complete"
        end
      end

      resources :boards, only: [ :index, :show, :create, :update, :destroy ]
      resources :audit_logs, only: [ :index ]

      get "events", to: "events#index"

      resources :task_handoffs, only: [ :index ] do
        member do
          patch :accept
          patch :reject
        end
      end

      resources :tasks, only: [ :index, :show, :create, :update, :destroy ] do
        collection do
          get :next
          get :pending_attention
        end
        member do
          patch :complete
          patch :claim
          patch :unclaim
          patch :assign
          patch :unassign
          post :handoff, to: "task_handoffs#create"
        end

        resources :artifacts, only: [ :index, :create, :show ], controller: "task_artifacts", param: :artifact_id
      end
    end
  end

  namespace :admin do
    root to: "dashboard#index"
    resources :users, only: [ :index ]
    resources :audit_logs, only: [ :index ]
  end

  resources :agents, only: [ :index, :show ] do
    member do
      patch :update_instructions
      patch :update_config
      patch :update_settings
      patch :archive
      patch :restore
    end
    resources :commands, only: [ :create ], controller: "agent_commands"
  end

  resource :session, only: [:new, :create, :destroy]
  resource :registration, only: [:new, :create]
  get "/auth/:provider/callback", to: "omniauth_callbacks#github", as: :omniauth_callback
  get "/auth/failure", to: "omniauth_callbacks#failure"
  resources :passwords, param: :token
  resource :settings, only: [ :show, :update ], controller: "profiles" do
    post :regenerate_api_token
    post :generate_join_token
  end

  # Boards (multi-board kanban views)
  resources :boards, only: [ :index, :show, :create, :update, :destroy ] do
    patch :update_task_status, on: :member
    resources :tasks, only: [ :show, :new, :create, :edit, :update, :destroy ], controller: "boards/tasks" do
      member do
        patch :assign
        patch :unassign
      end
      resources :subtasks, only: [ :create, :update, :destroy ], controller: "boards/subtasks"
    end
  end

  # Redirect root board path to first board
  get "board", to: redirect { |params, request|
    # This will be handled by the controller for proper user scoping
    "/boards"
  }
  # Agent chat endpoint
  post "agent/chat", to: "agent#chat"

  # Home dashboard (authenticated users)
  get "home", to: "home#show", as: :home

  get "pages/home"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root: landing page for visitors, dashboard for logged-in users
  root "pages#home"
end
