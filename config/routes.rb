Rails.application.routes.draw do
  match "/", to: "tunnel_websocket#forward", via: :all, constraints: ->(req) {
    req.host.end_with?(".localhost") || req.host.end_with?(".mfakhriddin.uz")
  }

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"
  resources :tunnels, only: %i[ index show create destroy ]
  get "/ws", to: "tunnel_websocket#connect"
  match "*path", to: "tunnel_websocket#forward", via: :all, constraints: ->(req) {
    req.host.end_with?(".localhost") || req.host.end_with?(".mfakhriddin.uz")
  }
  devise_for :users
  get '/my-cv', to: 'pages#my_cv', as: :my_cv
end
