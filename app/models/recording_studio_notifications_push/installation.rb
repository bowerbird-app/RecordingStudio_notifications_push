# frozen_string_literal: true

module RecordingStudioNotificationsPush
  # Browser / device registration for FCM. This is a normal ActiveRecord table,
  # not a Recording Studio recordable.
  class Installation < ApplicationRecord
    self.table_name = "recording_studio_notifications_push_installations"

    belongs_to :recipient, polymorphic: true

    validates :firebase_installation_id, presence: true
    validates :firebase_installation_id,
              uniqueness: { scope: %i[recipient_type recipient_id], case_sensitive: true }

    scope :active, -> { where(disabled_at: nil) }
    scope :for_recipient, lambda { |recipient|
      where(recipient_type: recipient.class.base_class.name, recipient_id: recipient.id)
    }

    def self.upsert!(recipient:, firebase_installation_id:, **registration)
      raise ArgumentError, "recipient is required" if recipient.nil?
      reject_unknown_registration!(registration)

      record = find_for_registration(recipient, firebase_installation_id)
      apply_registration!(record, recipient, registration)
      record.save!
      record
    end

    REGISTRATION_ATTRIBUTES = %i[legacy_fcm_token user_agent platform label].freeze
    private_constant :REGISTRATION_ATTRIBUTES

    def self.find_for_registration(recipient, firebase_installation_id)
      fid = firebase_installation_id.to_s.strip
      raise ArgumentError, "firebase_installation_id is required" if fid.blank?

      find_or_initialize_by(
        recipient_type: recipient.class.base_class.name,
        recipient_id: recipient.id,
        firebase_installation_id: fid
      )
    end
    private_class_method :find_for_registration

    def self.reject_unknown_registration!(registration)
      unknown = registration.keys - REGISTRATION_ATTRIBUTES
      raise ArgumentError, "unknown registration attribute: #{unknown.join(', ')}" if unknown.any?
    end
    private_class_method :reject_unknown_registration!

    def self.apply_registration!(record, recipient, registration)
      reject_unknown_registration!(registration)

      record.recipient = recipient
      REGISTRATION_ATTRIBUTES.each do |attribute|
        assign_optional_string!(record, attribute, registration[attribute]) if registration.key?(attribute)
      end
      record.disabled_at = nil
      record.last_seen_at = Time.current
    end
    private_class_method :apply_registration!

    def self.assign_optional_string!(record, attribute, value)
      record.public_send("#{attribute}=", value.to_s.presence) unless value.nil?
    end
    private_class_method :assign_optional_string!

    def delivery_token
      firebase_installation_id.to_s.presence || legacy_fcm_token.to_s.presence
    end

    def active?
      disabled_at.nil?
    end

    # +reason+ is the caller's explanation (removed, missing token, FCM error).
    # It is not stored. Keep passing it so a later audit row can record it
    # without a call-site change.
    def disable!(reason: nil)
      _ = reason
      return self if disabled_at.present?

      update!(disabled_at: Time.current)
      self
    end

    def touch_seen!
      update_columns(last_seen_at: Time.current, updated_at: Time.current)
    end

    def display_label
      candidate = label.to_s.strip
      return candidate if candidate.present? && !self.class.user_agent_like?(candidate)

      self.class.label_from_user_agent(user_agent) || platform.presence || Copy.t("labels.browser")
    end

    def mobile?
      self.class.mobile_device?(user_agent: user_agent, platform: platform, label: label)
    end

    def list_icon
      mobile? ? :device_phone_mobile : :computer_desktop
    end

    def self.user_agent_like?(value)
      UserAgent.user_agent_like?(value)
    end

    def self.label_from_user_agent(user_agent)
      UserAgent.label(user_agent)
    end

    def self.mobile_device?(user_agent: nil, platform: nil, label: nil)
      UserAgent.mobile?(user_agent: user_agent, platform: platform, label: label)
    end

    def self.browser_name_from_user_agent(user_agent)
      UserAgent.browser_name(user_agent)
    end

    def self.os_name_from_user_agent(user_agent)
      UserAgent.os_name(user_agent)
    end
  end
end
