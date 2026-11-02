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
  def fake_http_message(code:, body:, success:)
    response = Object.new
    response.define_singleton_method(:code) { code }
    response.define_singleton_method(:body) { body }
    response.define_singleton_method(:is_a?) { |klass| klass == Net::HTTPSuccess ? success : false }
    response
  end
end

Minitest::Test.include HttpResponseDouble
