# frozen_string_literal: true

Rails.application.routes.draw do
  resource :resolution_agent_settings,
           only: %i[show update],
           controller: "resolution_agent/settings"

  resources :projects, only: [] do
    resources :work_packages, only: [] do
      resource :resolution_agent, only: [:show], controller: "resolution_agent/panels" do
        post :message
        post :decision
      end
    end
  end
end
