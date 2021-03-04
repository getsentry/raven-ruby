Rails.application.routes.draw do
  resources :posts
  get '500', :to => 'welcome#report_demo'
  root to: "welcome#index"

  get 'appearance', to: 'welcome#appearance'
  get 'view_error', to: 'welcome#view_error'
  get 'worker_error', to: 'welcome#worker_error'
  get 'job_error', to: 'welcome#job_error'

  require 'sidekiq/web'

  mount Sidekiq::Web => '/sidekiq'
end
