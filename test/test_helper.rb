# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "minitest/mock"
require "rails"
require "active_support/time"
require "net/http"
require "json"
Time.zone ||= "UTC"
require "recording_studio_notifications"
require "recording_studio_notifications_push"
require "i18n"

I18n.load_path |= [File.expand_path("../config/locales/en.yml", __dir__)]
I18n.backend.reload!
I18n.available_locales = %i[en]
I18n.default_locale = :en

module HttpResponseDouble
  HttpMessage = Struct.new(:code, :body, :successful)

  def fake_http_message(code:, body:, success:)
    HttpMessage.new(code, body, success)
  end
end
