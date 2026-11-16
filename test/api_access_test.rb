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

  def test_admin_root_prefers_accessible_admin_root
    admin_root = Object.new
    access_called = false
    access_resolver = lambda { |_resolver_context|
      access_called = true
      Object.new
    }

    with_admin_resolvers(access: access_resolver) do
      with_accessible_admin_root(admin_root) do
        assert_same admin_root, RecordingStudioNotificationsPush::Api::Access.admin_root_recording
        refute access_called
      end
    end
  end

  def test_admin_root_uses_nil_when_the_accessible_resolver_returns_nil
    access_called = false

    with_admin_resolvers(access: lambda { |_resolver_context|
      access_called = true
      Object.new
    }) do
      with_accessible_admin_root(nil) do
        assert_nil RecordingStudioNotificationsPush::Api::Access.admin_root_recording
        refute access_called
      end
    end
  end

  def test_admin_root_falls_back_to_the_access_resolver
    access_recording = Object.new

    with_admin_resolvers(access: ->(_resolver_context) { access_recording }) do
      with_accessible_admin_root(nil, configured: false) do
        assert_same access_recording, RecordingStudioNotificationsPush::Api::Access.admin_root_recording
      end
    end
  end

  def test_admin_root_never_calls_site_admin_recording_resolver
    recording = Object.new
    configuration = Object.new
    configuration.define_singleton_method(:access_recording_resolver) { ->(_resolver_context) { recording } }
    configuration.define_singleton_method(:site_admin_recording_resolver) do
      raise "site_admin_recording_resolver was called"
    end

    with_admin_configuration(configuration) do
      assert_same recording, RecordingStudioNotificationsPush::Api::Access.admin_root_recording
    end
  end

  def test_admin_root_reads_a_configuration_without_site_admin_recording_resolver
    recording = Object.new
    configuration = Struct.new(:access_recording_resolver).new(->(_resolver_context) { recording })
    refute configuration.respond_to?(:site_admin_recording_resolver)

    with_admin_configuration(configuration) do
      assert_same recording, RecordingStudioNotificationsPush::Api::Access.admin_root_recording
    end
  end

  def test_can_view_is_false_when_the_resolver_returns_nil
    with_admin_resolvers(access: ->(_resolver_context) {}) do
      assert_nil RecordingStudioNotificationsPush::Api::Access.admin_root_recording
      refute RecordingStudioNotificationsPush::Api::Access.can_view?(view_context(Object.new))
    end
  end

  def test_can_view_lets_resolver_errors_propagate
    resolver = ->(resolver_context) { resolver_context.controller.request }

    with_admin_resolvers(access: resolver) do
      assert_raises(NoMethodError) do
        RecordingStudioNotificationsPush::Api::Access.can_view?(view_context(Object.new))
      end
    end
  end

  def test_admin_root_comes_from_the_loaded_admin_configuration
    recording = Object.new
    configuration = Struct.new(:access_recording_resolver).new(->(_resolver_context) { recording })
    admin = Module.new
    admin.define_singleton_method(:configuration) { configuration }

    with_constant(:RecordingStudioAdmin, admin) do
      assert RecordingStudioNotificationsPush::Api::Access.admin_loaded?
      assert_same recording, RecordingStudioNotificationsPush::Api::Access.admin_root_recording
    end
  end

  def test_can_view_follows_an_accessible_grant_on_the_admin_root
    recording = Object.new
    actor = Object.new
    context = view_context(actor)
    seen = nil

    with_admin_resolvers(access: ->(_resolver_context) { recording }) do
      without_constant(:RecordingStudioAccessible) do
        refute RecordingStudioNotificationsPush::Api::Access.can_view?(context)
      end

      allow = lambda { |actor:, recording:, role:|
        seen = [actor, recording, role]
        true
      }
      with_constant(:RecordingStudioAccessible, accessible_module(allow)) do
        assert RecordingStudioNotificationsPush::Api::Access.can_view?(context)
      end
      assert_equal [actor, recording, :view], seen

      with_constant(:RecordingStudioAccessible, accessible_module(->(**) { false })) do
        refute RecordingStudioNotificationsPush::Api::Access.can_view?(context)
      end
    end
  end

  def test_can_view_lets_name_error_propagate
    access_api = RecordingStudioNotificationsPush::Api::Access
    configuration = -> { raise NameError, "RecordingStudioAdmin is not loaded" }

    access_api.stub(:admin_loaded?, true) do
      access_api.stub(:admin_configuration, configuration) do
        assert_raises(NameError) { access_api.can_view?(view_context(Object.new)) }
      end
    end
  end

  private

  def view_context(actor)
    ViewContext.new(Grant.new(actor))
  end

  def accessible_module(decision)
    mod = Module.new
    mod.define_singleton_method(:authorized?, &decision)
    mod
  end

  def with_constant(name, value)
    had = Object.const_defined?(name, false)
    saved = Object.send(:remove_const, name) if had
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, saved) if had
  end

  def without_constant(name)
    had = Object.const_defined?(name, false)
    saved = Object.send(:remove_const, name) if had
    yield
  ensure
    Object.const_set(name, saved) if had && !Object.const_defined?(name, false)
  end

  def with_admin_resolvers(access: nil, &)
    configuration = Struct.new(:access_recording_resolver).new(access)
    with_admin_configuration(configuration, &)
  end

  def with_admin_configuration(configuration, &)
    access_api = RecordingStudioNotificationsPush::Api::Access
    access_api.stub(:admin_loaded?, true) do
      access_api.stub(:admin_configuration, configuration, &)
    end
  end

  def with_accessible_admin_root(recording, configured: true, &)
    configuration = Struct.new(:admin_root_resolver).new(configured ? -> { recording } : nil)
    accessible = Module.new
    accessible.define_singleton_method(:configuration) { configuration }
    accessible.define_singleton_method(:admin_root) { |**| recording }
    with_constant(:RecordingStudioAccessible, accessible, &)
  end
end
