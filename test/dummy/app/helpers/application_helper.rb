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

  def delivery_badge_style(status)
    case status.to_s
    when "delivered" then :success
    when "failed" then :danger
    else :default
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
    dropdown.menu_html(dummy_theme_menu_label(t("dummy.theme.group")))
    dropdown.menu_html(dummy_theme_radios)
    dropdown.menu_form(class: "md:hidden") { dummy_theme_language_panel }
  end

  # Radios, not menuitemradio: the cog is a dialog once it contains the
  # language form, and a menu item role is not allowed in there.
  def dummy_theme_radios
    tag.div(role: "radiogroup", aria: { label: t("dummy.theme.group", default: "Theme") }) do
      safe_join(%w[system light dark].map { |value| dummy_theme_radio(value) })
    end
  end

  # System is the theme controller's choice when nothing is saved. Every row
  # keeps the check icon so the labels share one gutter. The dummy stylesheet
  # hides the icon when aria-checked is false.
  def dummy_theme_radio(value)
    active = value == "system"
    item = FlatPack::Button::DropdownItem::Component.new(
      text: t("dummy.theme.#{value}", default: value.capitalize),
      icon: "check",
      role: "radio",
      aria: { checked: active.to_s },
      data: {
        action: "click->flat-pack--theme#switch click->flat-pack--button-dropdown#toggle keydown->dummy-theme-menu#keydown",
        theme_value: value
      }
    )
    item.plain_actions = true
    render(item)
  end

  def dummy_theme_menu_label(text)
    render FlatPack::Text::Component.new(
      text: text,
      as: :p,
      size: :xs,
      style: :muted,
      weight: :semibold
    )
  end

  def dummy_theme_language_panel
    safe_join([
      dummy_theme_menu_label(t("dummy.theme.language", default: "Language")),
      dummy_language_selector(compact: false)
    ])
  end
end
