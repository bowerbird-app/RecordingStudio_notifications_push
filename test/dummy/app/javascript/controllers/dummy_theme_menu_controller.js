import { Controller } from "@hotwired/stimulus"

// Moves the Theme check to the saved choice. System is the choice when
// nothing is saved, matching flat-pack--theme. Shape is not a menu group.
const STORAGE_KEY = "flatpack-theme"
const CHOICES = ["system", "light", "dark"]

export default class extends Controller {
  connect() {
    const sample = this.element.querySelector("[data-theme-value] svg")
    this.checkIcon = sample ? sample.cloneNode(true) : null
    this.boundSync = (event) => this.sync(event?.detail?.theme)
    window.addEventListener("flat-pack:theme-changed", this.boundSync)
    this.sync(window.localStorage.getItem(STORAGE_KEY))
  }

  disconnect() {
    window.removeEventListener("flat-pack:theme-changed", this.boundSync)
  }

  sync(saved) {
    const active = CHOICES.includes(saved) ? saved : "system"
    this.element.querySelectorAll("[data-theme-value]").forEach((item) => {
      const on = item.dataset.themeValue === active
      item.setAttribute("role", "menuitemradio")
      item.setAttribute("aria-checked", on ? "true" : "false")
      this.placeCheck(item, on)
    })
  }

  placeCheck(item, on) {
    const icon = item.querySelector("svg")
    if (on) {
      if (!icon && this.checkIcon) item.prepend(this.checkIcon.cloneNode(true))
      return
    }

    icon?.remove()
  }
}
