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

    def self.upsert!(recipient:, firebase_installation_id:, legacy_fcm_token: nil,
                     user_agent: nil, platform: nil, label: nil)
      raise ArgumentError, "recipient is required" if recipient.nil?

      fid = firebase_installation_id.to_s.strip
      raise ArgumentError, "firebase_installation_id is required" if fid.blank?

      record = find_or_initialize_by(
        recipient_type: recipient.class.base_class.name,
        recipient_id: recipient.id,
        firebase_installation_id: fid
      )

      record.recipient = recipient
      record.legacy_fcm_token = legacy_fcm_token.to_s.presence if !legacy_fcm_token.nil?
      record.user_agent = user_agent.to_s.presence if !user_agent.nil?
      record.platform = platform.to_s.presence if !platform.nil?
      record.label = label.to_s.presence if !label.nil?
      record.disabled_at = nil
      record.last_seen_at = Time.current
      record.save!
      record
    end

    def delivery_token
      firebase_installation_id.to_s.presence || legacy_fcm_token.to_s.presence
    end

    def active?
      disabled_at.nil?
    end

    def disable!(reason: nil)
      return self if disabled_at.present?

      update!(disabled_at: Time.current)
      self
    end

    def touch_seen!
      update_columns(last_seen_at: Time.current, updated_at: Time.current)
    end
  end
end
