# frozen_string_literal: true

module RecordingStudioNotificationsPush
  parent_controller = defined?(::ApplicationController) ? ::ApplicationController : ActionController::Base

  class ApplicationController < parent_controller
    include ::RecordingStudio::UsesDefaultLayout if defined?(::RecordingStudio::UsesDefaultLayout)

    protect_from_forgery with: :exception

    before_action :require_push_actor!

    helper_method :current_push_actor

    private

    def current_push_actor
      @current_push_actor ||= begin
        actor = current_user if respond_to?(:current_user, true)
        actor ||= Current.actor if defined?(Current) && Current.respond_to?(:actor)
        actor
      end
    end

    def require_push_actor!
      return if current_push_actor

      if respond_to?(:authenticate_user!, true)
        authenticate_user!
      else
        head :unauthorized
      end
    end
  end
end
