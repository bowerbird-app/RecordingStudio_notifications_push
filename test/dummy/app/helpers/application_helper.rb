# frozen_string_literal: true

module ApplicationHelper
  include RecordingStudioNotifications::MenuHelper

  def polymorphic_label(record)
    return if record.nil?

    %i[email name title label].each do |attribute|
      next unless record.respond_to?(attribute)

      value = record.public_send(attribute)
      return value.to_s if value.present?
    end

    "#{record.class.name} ##{record.id}"
  end

  def dummy_language_selector(compact: true)
    return unless respond_to?(:recording_studio_language_selector)

    locales = RecordingStudioInternationalization.configuration.available_locales
    return if locales.count < 2

    render "recording_studio_internationalization/locales/selector",
      locales: locales,
      html_options: dummy_language_form_options,
      compact: compact
  end

  def dummy_theme_selector
    render FlatPack::Button::Dropdown::Component.new(**dummy_theme_dropdown_options) do |dropdown|
      dummy_theme_menu(dropdown)
    end
  end

  # Phones open the drawer from the hamburger. The row uses the same padding
  # and text size as a sidebar item, with a short label above it.
  def dummy_drawer_workspace_switcher
    return unless respond_to?(:recording_studio_root_switch_list_for)

    list = recording_studio_root_switch_list_for
    return if list.blank?

    safe_join([
      render(FlatPack::Sidebar::SectionTitle::Component.new(title: t("dummy.sidebar.workspace"))),
      render(FlatPack::Sidebar::Group::Component.new(title: list.menu_rows.current_label, open: false)) do |group|
        group.items do
          render RecordingStudioRootSwitchable::RootSwitch::RowsComponent.new(menu_rows: list.menu_rows)
        end
      end
    ])
  end

  def dummy_document_attributes
    attributes = { "data-theme" => "rounded" }
    attributes.merge!(recording_studio_locale_attributes) if respond_to?(:recording_studio_locale_attributes)
    if respond_to?(:flat_pack_copy_data)
      attributes[:data] = (attributes[:data] || {}).merge(flat_pack_copy_data)
    end
    attributes
  end

  private

  def dummy_language_form_options
    {
      data: {
        turbo: false,
        controller: "dummy-language-selector",
        action: "change->dummy-language-selector#submit"
      }
    }
  end

  def dummy_theme_dropdown_options
    {
      text: t("dummy.theme.label", default: "Theme"),
      style: :ghost,
      size: :sm,
      placement: :bottom_right,
      icon: "cog",
      icon_only: true,
      class: "dummy-theme-selector"
    }
  end

  def dummy_theme_menu(dropdown)
    dummy_theme_group(dropdown, "dummy.theme.group", %w[system light dark])
    dropdown.menu_divider
    dummy_theme_group(dropdown, "dummy.theme.shape", %w[rounded])
    dropdown.menu_divider
    dropdown.menu_html(dummy_theme_menu_label(t("dummy.theme.language", default: "Language")))
    dropdown.menu_form(class: "md:hidden") { dummy_theme_language_panel }
  end

  def dummy_theme_group(dropdown, label_key, values)
    dropdown.menu_html(dummy_theme_menu_label(t(label_key)))
    values.each { |value| dummy_theme_choice(dropdown, value) }
  end

  def dummy_theme_choice(dropdown, value)
    active = value == "rounded"
    options = {
      text: t("dummy.theme.#{value}", default: value.capitalize),
      data: {
        action: "click->flat-pack--theme#switch click->flat-pack--button-dropdown#toggle",
        theme_value: value
      }
    }
    options[:icon] = "check" if active
    options[:aria] = { current: "true" } if active
    dropdown.menu_item(**options)
  end

  def dummy_theme_menu_label(text)
    render FlatPack::Text::Component.new(
      text: text,
      as: :p,
      size: :xs,
      style: :muted,
      weight: :semibold,
      class: "px-[var(--dropdown-item-padding-x)] pt-2"
    )
  end

  # The dialog focuses its first field on open. A clipped field takes that
  # focus so the language select keeps its resting border.
  def dummy_theme_language_panel
    safe_join([
      tag.input(
        type: "text",
        class: "sr-only",
        tabindex: "0",
        autocomplete: "off",
        aria: { label: t("dummy.theme.label", default: "Theme") },
        data: { dummy_theme_focus_sink: true }
      ),
      dummy_language_selector(compact: false)
    ])
  end
end
