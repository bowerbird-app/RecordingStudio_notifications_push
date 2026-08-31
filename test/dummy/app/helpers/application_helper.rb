# frozen_string_literal: true

module ApplicationHelper
  def polymorphic_label(record)
    return if record.nil?

    %i[email name title label].each do |attribute|
      next unless record.respond_to?(attribute)

      value = record.public_send(attribute)
      return value.to_s if value.present?
    end

    "#{record.class.name} ##{record.id}"
  end
end
