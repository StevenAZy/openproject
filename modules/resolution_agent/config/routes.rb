# frozen_string_literal: true

Rails.application.routes.draw do
  resource :resolution_agent_settings,
           only: %i[show update],
           controller: "resolution_agent/settings" do
    post :test_connection
  end

  resources :resolution_agent_project_repositories,
            only: %i[create destroy],
            controller: "resolution_agent/project_repositories"

  post "resolution_agent/gitea/webhook",
       to: "resolution_agent/gitea_webhooks#create",
       as: :resolution_agent_gitea_webhook

  resources :projects, only: [] do
    resources :work_packages, only: [] do
      resource :resolution_agent, only: [:show], controller: "resolution_agent/panels" do
        get :status
        get :branches
        post :message
        post :cancel
        post :decision
        post "fix_attempts/:attempt_id/confirm", action: :confirm, as: :confirm_fix_attempt
      end
    end
  end
end
