# frozen_string_literal: true

class HomeController < ApplicationController
  def index
  end

  def create_test_notification
    @notification = RecordingStudioNotifications.notify(
      notification_type: :push_demo,
      recipient: current_user,
      title: "Test ping",
      body: "Sent with your notification settings — inbox, email, and push as enabled.",
      url: root_path,
      actor: current_user
    )
    @deliveries = @notification.deliveries.reload.order(:channel).to_a
    render_test_notification_success
  rescue ArgumentError => e
    @error_message = friendly_notify_error(e)
    respond_to do |format|
      format.turbo_stream { render :create_test_notification_error, status: :unprocessable_entity }
      format.html { redirect_to root_path, alert: @error_message }
    end
  end

  private

  def render_test_notification_success
    respond_to do |format|
      format.turbo_stream { render :create_test_notification }
      format.html { redirect_to root_path, notice: "Test notification sent." }
    end
  end

  def friendly_notify_error(error)
    message = error.message.to_s
    if message.include?("at least one channel")
      "Nothing is turned on for Push demo. Open notification settings and enable a channel."
    elsif message.include?("unsafe notification URL")
      "That link could not be used. Try again from the home page."
    else
      message.presence || "Could not send that test notification."
    end
  end
end
