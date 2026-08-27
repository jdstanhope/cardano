Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]

  # The list of games is the dashboard; there is no separate dashboard concept.
  resources :games, only: %i[ index new create show edit update ] do
    resource :duplicate, only: :create, controller: "game_duplicates"
    resources :symbols, only: %i[ create update destroy ], controller: "game_symbols"
    resources :symbol_groups, only: %i[ create update destroy ]
    resources :paylines, only: %i[ create destroy ] do
      # Applying a set replaces every payline, which is not what creating one means.
      collection { post :apply_set }
    end

    resources :variations, only: %i[ show create ] do
      resource :reel_strips, only: %i[ update ]
      resource :paytable, only: %i[ update ]
      resources :combinations, only: %i[ create update destroy ], controller: "paytable_combinations"
      resources :calculations, only: %i[ create destroy ]
    end
  end
  # Copying a sample creates a game, so it is a POST to the sample rather than a GET.
  post "/samples/:key", to: "samples#create", as: :sample

  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
