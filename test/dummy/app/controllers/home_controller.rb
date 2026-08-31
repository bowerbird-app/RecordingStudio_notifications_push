# frozen_string_literal: true

class HomeController < ApplicationController
  TEST_NOTIFICATION_ICONS = {
    "coral" => "/push-icon-coral.png",
    "teal" => "/push-icon-teal.png"
  }.freeze

  def index
    @recent_inbox_notifications = recent_inbox_notifications
  end

  def create_test_notification
    icon_key = params[:icon].to_s
    icon_path = TEST_NOTIFICATION_ICONS[icon_key]
    title, body = test_notification_copy(icon_key)

    @notification = RecordingStudioNotifications.notify(
      notification_type: :push_demo,
      recipient: current_user,
      title: title,
      body: body,
      url: demo_latest_notification_path,
      actor: current_user,
      metadata: icon_metadata(icon_path)
    )
    @deliveries = @notification.deliveries.reload.order(:channel).to_a
    @recent_inbox_notifications = recent_inbox_notifications
    render_test_notification_success
  rescue ArgumentError => e
    @error_message = friendly_notify_error(e)
    respond_to do |format|
      format.turbo_stream { render :create_test_notification_error, status: :unprocessable_entity }
      format.html { redirect_to root_path, alert: @error_message }
    end
  end

  private

  def icon_metadata(icon_path)
    return {} if icon_path.blank?

    absolute = "#{request.base_url}#{icon_path}"
    { icon: absolute, image: absolute }
  end

  def test_notification_copy(icon_key)
    case icon_key
    when "coral"
      ["Coral icon ping", "OS banner should show the coral thumbnail."]
    when "teal"
      ["Teal icon ping", "OS banner should show the teal thumbnail."]
    else
      [
        "Test ping",
        "Sent with your notification settings — inbox, email, and push as enabled."
      ]
    end
  end

  def recent_inbox_notifications
    RecordingStudioNotifications::Notification
      .for_recipient(current_user)
      .visible_in_inbox
      .order(created_at: :desc)
      .limit(8)
  end

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
