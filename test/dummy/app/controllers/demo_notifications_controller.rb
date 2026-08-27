# frozen_string_literal: true

# Dummy-host landing page for push click-throughs. Not part of the push gem —
# it exists so the demo can show a full notification dump after a browser alert.
class DemoNotificationsController < ApplicationController
  before_action :set_notification

  def show
    @notification.mark_read! if @notification.unread?
    @deliveries = @notification.deliveries.order(:channel).to_a
    @installations = push_installations_for(@notification.recipient)
  end

  private

  def set_notification
    @notification = RecordingStudioNotifications::Notification
      .for_recipient(current_user)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "We could not find that notification."
  end

  def push_installations_for(recipient)
    return [] unless defined?(RecordingStudioNotificationsPush::Installation)

    RecordingStudioNotificationsPush::Installation
      .for_recipient(recipient)
      .order(Arel.sql("disabled_at NULLS FIRST"), last_seen_at: :desc)
      .limit(20)
      .to_a
  end
end
