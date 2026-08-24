# frozen_string_literal: true

module RecordingStudioNotificationsPush
  class InstallationsController < ApplicationController
    def create
      installation = upsert_installation!
      render json: installation_json(installation), status: :created
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def destroy
      installation = Installation.active.for_recipient(current_push_actor).find(params[:id])
      installation.disable!(reason: "unregistered")
      head :no_content
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    def upsert_installation!
      Installation.upsert!(
        recipient: current_push_actor,
        firebase_installation_id: installation_params[:firebase_installation_id],
        legacy_fcm_token: installation_params[:legacy_fcm_token],
        user_agent: installation_params[:user_agent].presence || request.user_agent,
        platform: installation_params[:platform],
        label: installation_params[:label]
      )
    end

    def installation_params
      params.require(:installation).permit(
        :firebase_installation_id,
        :legacy_fcm_token,
        :user_agent,
        :platform,
        :label
      )
    end

    def installation_json(installation)
      {
        id: installation.id,
        firebase_installation_id: installation.firebase_installation_id,
        platform: installation.platform,
        label: installation.label,
        last_seen_at: installation.last_seen_at,
        disabled_at: installation.disabled_at
      }
    end
  end
end
