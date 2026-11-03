import { Controller } from "@hotwired/stimulus"

// Compact top-nav wrapper around recording_studio_language_selector.
// Changing the locale select submits the engine form (full page load).
//
// The cog menu is a dialog, so opening it focuses the first field. That
// paints the language select's focus ring before anyone tabs to it. Hand
// that programmatic focus to the panel. A tab or a press still focuses
// the select.
export default class extends Controller {
  connect() {
    this.menu = this.element.closest("[data-flat-pack--button-dropdown-target='menu']")
    if (!this.menu) return

    this.userAimedAtSelect = false
    this.onPointerDown = (event) => {
      if (event.target.closest("select")) this.userAimedAtSelect = true
    }
    this.onKeyDown = (event) => {
      if (event.key === "Tab") this.userAimedAtSelect = true
    }
    this.onFocusIn = (event) => this.keepSelectAtRest(event)

    this.menu.addEventListener("pointerdown", this.onPointerDown, true)
    this.menu.addEventListener("keydown", this.onKeyDown, true)
    this.menu.addEventListener("focusin", this.onFocusIn)
  }

  disconnect() {
    if (!this.menu) return

    this.menu.removeEventListener("pointerdown", this.onPointerDown, true)
    this.menu.removeEventListener("keydown", this.onKeyDown, true)
    this.menu.removeEventListener("focusin", this.onFocusIn)
  }

  keepSelectAtRest(event) {
    const aimed = this.userAimedAtSelect
    this.userAimedAtSelect = false

    const select = event.target.closest?.("select")
    if (!select || !this.element.contains(select) || aimed) return

    this.menu.tabIndex = -1
    this.menu.focus({ preventScroll: true })
  }

  submit() {
    this.element.requestSubmit()
  }
}
