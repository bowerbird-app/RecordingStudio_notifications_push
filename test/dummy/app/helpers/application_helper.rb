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

  def dummy_language_selector
    return unless respond_to?(:recording_studio_language_selector)

    recording_studio_language_selector(
      class: "dummy-language-selector flex shrink-0 items-center gap-1.5 [&_label]:sr-only [&_button]:sr-only [&_.flat-pack-input-wrapper]:mb-0 [&_.flat-pack-select]:min-h-8 [&_.flat-pack-select]:min-w-28 [&_.flat-pack-select]:py-1 [&_.flat-pack-select]:text-sm",
      data: {
        turbo: false,
        controller: "dummy-language-selector",
        action: "change->dummy-language-selector#submit"
      }
    )
  end

  def dummy_theme_selector
    render FlatPack::Button::Dropdown::Component.new(
      text: t("dummy.theme.label", default: "Theme"),
      style: :ghost,
      size: :sm,
      placement: :bottom_right,
      icon: "cog",
      class: "dummy-theme-selector"
    ) do |dropdown|
      dropdown.menu_item(
        text: t("dummy.theme.rounded", default: "Rounded"),
        data: {
          action: "click->flat-pack--theme#switch click->flat-pack--button-dropdown#toggle",
          theme_value: "rounded"
        }
      )
      dropdown.menu_item(
        text: t("dummy.theme.system", default: "System"),
        data: {
          action: "click->flat-pack--theme#switch click->flat-pack--button-dropdown#toggle",
          theme_value: "system"
        }
      )
      dropdown.menu_item(
        text: t("dummy.theme.light", default: "Light"),
        data: {
          action: "click->flat-pack--theme#switch click->flat-pack--button-dropdown#toggle",
          theme_value: "light"
        }
      )
      dropdown.menu_item(
        text: t("dummy.theme.dark", default: "Dark"),
        data: {
          action: "click->flat-pack--theme#switch click->flat-pack--button-dropdown#toggle",
          theme_value: "dark"
        }
      )
    end
  end

  def dummy_document_attributes
    attributes = { "data-theme" => "rounded" }
    attributes.merge!(recording_studio_locale_attributes) if respond_to?(:recording_studio_locale_attributes)
    if respond_to?(:flat_pack_copy_data)
      attributes[:data] = (attributes[:data] || {}).merge(flat_pack_copy_data)
    end
    attributes
  end
end
