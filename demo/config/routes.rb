# frozen_string_literal: true

Rails.application.routes.draw do
  root "dashboard#show"
  get "context_map", to: "context_map#show"
  get "context_map/live", to: "context_map#live"
  get "feed", to: "feed#show"
  post "slow_motion", to: "slow_motion#update"
  get "scenarios", to: "scenarios#index", as: :scenarios
  post "scenarios/:scenario/step", to: "scenarios#step", as: :scenario_step
  post "scenarios/:scenario/run_all", to: "scenarios#run_all", as: :scenario_run_all
  post "scenarios/:scenario/start", to: "scenarios#start", as: :scenario_start
  post "scenarios/:scenario/reset", to: "scenarios#reset", as: :scenario_reset
  post "commands/:context/:command", to: "commands#create", as: :command
  mount RailsEventStore::Browser => "/res"
end
