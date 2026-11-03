# frozen_string_literal: true

require "test_helper"

class ApiAccessTest < Minitest::Test
  ViewContext = Struct.new(:access_grant)
  Grant = Struct.new(:actor)

  def test_can_view_is_false_without_admin_or_actor
    refute RecordingStudioNotificationsPush::Api::Access.can_view?(nil)
    refute RecordingStudioNotificationsPush::Api::Access.can_view?(view_context(Object.new))
  end

  def test_admin_root_recording_is_nil_without_admin
    refute RecordingStudioNotificationsPush::Api::Access.admin_loaded?
    assert_nil RecordingStudioNotificationsPush::Api::Access.admin_root_recording
  end

  def test_admin_root_prefers_the_site_resolver
    site_recording = Object.new
    access_called = false
    access_resolver = lambda { |_resolver_context|
      access_called = true
      Object.new
    }

    with_admin_resolvers(site: ->(_resolver_context) { site_recording }, access: access_resolver) do
      assert_same site_recording, RecordingStudioNotificationsPush::Api::Access.admin_root_recording
      refute access_called
    end
  end

  def test_admin_root_falls_back_to_the_access_resolver
    access_recording = Object.new

    with_admin_resolvers(access: ->(_resolver_context) { access_recording }) do
      assert_same access_recording, RecordingStudioNotificationsPush::Api::Access.admin_root_recording
    end
  end

  def test_can_view_is_false_when_the_resolver_returns_nil
    with_admin_resolvers(access: ->(_resolver_context) {}) do
      assert_nil RecordingStudioNotificationsPush::Api::Access.admin_root_recording
      refute RecordingStudioNotificationsPush::Api::Access.can_view?(view_context(Object.new))
    end
  end

  def test_can_view_is_false_when_the_resolver_raises
    resolver = ->(resolver_context) { resolver_context.controller.request }

    with_admin_resolvers(access: resolver) do
      refute RecordingStudioNotificationsPush::Api::Access.can_view?(view_context(Object.new))
    end

    refute RecordingStudioNotificationsPush::Api::Access.admin_loaded?
  end

  private

  def view_context(actor)
    ViewContext.new(Grant.new(actor))
  end

  def with_admin_resolvers(access: nil, site: nil, &block)
    configuration = Struct.new(:site_admin_recording_resolver, :access_recording_resolver).new(site, access)
    access_api = RecordingStudioNotificationsPush::Api::Access
    access_api.stub(:admin_loaded?, true) do
      access_api.stub(:admin_configuration, configuration, &block)
    end
  end
end
