# frozen_string_literal: true

Rails.application.routes.draw do
  get "demo/sandboxes/:surface", to: "demo#status"
  post "demo/sessions", to: "demo#session"
  get "demo/permissions", to: "demo_permissions#show"
  get "up" => "rails/health#show", as: :rails_health_check

  # GraphQL (decision 13): the web app and agents. REST stays under /v1.
  post "graphql", to: "graphql#execute"

  namespace :v1 do
    resources :oauth_identities, only: %i[index create] do
      member { post :revoke }
    end
    get "health", to: "health#show"
    post "sessions", to: "sessions#create"
    post "sessions/exchange", to: "sessions#exchange"
    get "sessions/current", to: "sessions#current"
    get "sessions/demo_memberships", to: "sessions#demo_memberships"
    delete "sessions/current", to: "sessions#destroy"
    resources :agents, only: %i[index show create] do
      member do
        post :pause
        post :resume
        post :revoke
        post :credentials, action: :create_credential
      end
    end
    resources :custom_fields, only: %i[index show create update] do
      member do
        post :archive
        post :restore
        post :type_change
      end
    end
    put "custom_field_values", to: "custom_field_values#upsert"

    # Compliance: data-subject requests, consents, access export, legal holds
    get "data_requests", to: "compliance#data_requests"
    post "data_requests", to: "compliance#create_data_request"
    post "data_requests/:id/complete", to: "compliance#complete_data_request"
    post "data_requests/:id/reject", to: "compliance#reject_data_request"
    get "people/:id/access_packet", to: "compliance#access_packet"
    get "people/:id/consents", to: "compliance#consents"
    post "people/:id/consents", to: "compliance#record_consent"
    get "legal_holds", to: "compliance#legal_holds"
    post "legal_holds", to: "compliance#create_legal_hold"
    post "legal_holds/:id/release", to: "compliance#release_legal_hold"
    resources :credentials, only: %i[index create] do
      member do
        post :revoke
      end
    end
    namespace :oauth do
      get "google", to: "google#start"
      get "google/callback", to: "google#callback"
      get "google/status", to: "google#status"
    end
    resources :organizations, only: %i[create update]
    resources :people, only: %i[index create show update] do
      get :feed, on: :member
      post :preview_message, on: :member
      resources :documents, only: %i[index show create]
      collection do
        post :bulk
      end
      member do
        get :timeline
        get :communications, action: :list_communications
        post :communications, action: :create_communication
        post :erase
      end
    end
    resources :saved_searches, only: %i[index create update destroy] do
      get :people, on: :member
    end
    resources :jobs, only: %i[index create show update] do
      collection do
        get :form_options
      end
      member do
        get :rediscovery
        post "hiring_team/members", action: :add_team_member
        patch "hiring_team/members/:member_id", action: :update_team_member
        post "hiring_team/members/:member_id/remove", action: :remove_team_member
        patch :pipeline, action: :update_pipeline
      end
    end
    get "jobs/:job_id/rediscovery/criteria", to: "rediscovery#criteria"
    put "jobs/:job_id/rediscovery/criteria", to: "rediscovery#update_criteria"
    post "jobs/:job_id/rediscovery/run", to: "rediscovery#run"
    get "jobs/:job_id/rediscovery/queue", to: "rediscovery#queue"
    post "rediscovery_candidates/:id/review", to: "rediscovery#review"
    post "jobs/:job_id/sourcing_agent/run", to: "sourcing_agent#run"
    get "agent_proposals", to: "agent_proposals#index"
    post "agent_proposals/bulk_approve", to: "agent_proposals#bulk_approve"
    post "agent_proposals/:id/approve", to: "agent_proposals#approve"
    post "agent_proposals/:id/reject", to: "agent_proposals#reject"
    resources :requisitions, only: %i[index create show] do
      member do
        post :open, action: :open_req
        post :close
      end
    end
    resources :referrals, only: %i[index create show]
    resources :dnc_companies, only: %i[index create destroy]
    resources :sourcing_tasks, only: %i[index] do
      member do
        post :complete
      end
    end
    get "analytics/funnel", to: "analytics#funnel"
    get "analytics/sourcing", to: "analytics#sourcing"
    get "analytics/outreach", to: "analytics#outreach"
    get "analytics/outreach_snapshots", to: "analytics#outreach_snapshots"
    resources :communications, only: %i[update]
    resources :projects, only: %i[index create show update] do
      member do
        get :members
        post :members, action: :create_member
        post :people, action: :add_people
        post :from_job, action: :add_from_job
        post :transitions, action: :bulk_transition
      end
    end
    resources :project_members, only: %i[index show update] do
      member do
        get :transitions
        post :transitions, action: :create_transition
        post :convert
      end
    end
    resources :sequences, only: %i[index create show update] do
      member do
        get :preview
        get :stats
        get :enrollments
        post :enrollments, action: :create_enrollment
        post :bulk_enroll
        post :enrollment_plan
        post :enroll_planned
      end
    end
    resources :enrollments, only: %i[index show] do
      member do
        post :stop
      end
    end
    resources :mailboxes, only: %i[index create update] do
      member do
        post :inbound
        get :messages
        post :simulate
      end
    end
    resources :tasks, only: %i[index create update] do
      member do
        post :complete
        post :cancel
      end
    end
    resources :tags, only: %i[index create update] do
      post :merge, on: :member
    end
    get "people/:person_id/tags", to: "tags#person_index"
    post "people/:person_id/tags", to: "tags#person_add"
    delete "people/:person_id/tags/:id", to: "tags#person_remove"
    get "people/:person_id/notes", to: "notes#index"
    post "people/:person_id/notes", to: "notes#create"
    resources :notes, only: %i[update destroy]
    resources :scorecards, only: %i[index create update]
    resources :companies, only: %i[index create show]
    resources :affiliations, only: %i[index create]
    resources :compliance_policies, only: %i[index show]
    resources :webhooks, only: %i[index create update] do
      post :rotate_secret, on: :member
      collection do
        post :drain
      end
    end
    get "events", to: "events#index"
    get "sync/people", to: "events#sync_people"
    get "config/plans", to: "config#plans"
    post "config/plans", to: "config#plan"
    post "config/apply", to: "config#apply"
    resources :imports, only: %i[index create show]
    resources :applications, only: %i[index create show] do
      member do
        get :transitions
        post :transitions, action: :create_transition
        post :offers, action: :create_offer
        get :interviews
        get :missing_feedback
        post :scheduling_links, action: :create_scheduling_link
        post :bookings, action: :create_booking
        post :booking_options
      end
    end
    resources :offers, only: %i[index show] do
      member do
        post :submit
        post :approve
        post :send_letter, path: "send", action: :send_letter
        post :resend
        post :record_response
        patch :checklist, action: :update_checklist
        post :rescind
      end
    end
    resources :message_templates, only: %i[index create update] do
      member do
        post :archive
      end
    end
    get "application_form", to: "application_form#show"
    patch "application_form", to: "application_form#update"
    get "today", to: "today#show"
    resources :calendar_connections, only: %i[index create]
    resources :scorecard_rubrics, only: %i[index create update]
    get "interviews/awaiting_schedule", to: "interviews#awaiting_schedule"
    get "team", to: "team#index"
    resources :interviews, only: %i[index show] do
      member do
        post :cancel
        post :reschedule
      end
    end
    get "jobs/:job_id/postings", to: "postings#index"
    post "jobs/:job_id/postings", to: "postings#create"
    patch "postings/:id", to: "postings#update"
    get "application_question_templates", to: "application_question_templates#index"
    post "application_question_templates", to: "application_question_templates#create"
    patch "application_question_templates/:id", to: "application_question_templates#update"
    get "internal/careers", to: "careers#internal_show"
    post "internal/careers/apply/:posting_id", to: "careers#internal_apply"
    get "public/careers/:slug", to: "careers#public_show"
    post "public/careers/:slug/apply/:posting_id", to: "careers#public_apply"
    get "public/offers/:token", to: "offers#public_show"
    post "public/offers/:token/accept", to: "offers#public_accept"
    post "public/offers/:token/decline", to: "offers#public_decline"
    get "public/scheduling/:token", to: "scheduling#public_show"
    post "public/scheduling/:token/book", to: "scheduling#public_book"
    get "public/unsubscribe/:token", to: "unsubscribe#show"
    post "public/unsubscribe/:token", to: "unsubscribe#create"
  end
end
