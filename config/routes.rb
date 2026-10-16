Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    resource :session, only: %i[show create destroy]
    resources :employees, only: %i[index show] do
      resources :salary_revisions, only: %i[create]
      resource :termination, only: %i[create]
    end
    resource :filter_options, only: %i[show]
  end

  # Defines the root path route ("/")
  root "frontend#show"
  get "*path", to: "frontend#show",
    constraints: ->(request) { !request.path.match?(%r{\A/api(/|\z)}) && request.format.html? }
end
