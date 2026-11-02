import { Controller } from "@hotwired/stimulus"

// Moves the Theme check to the saved choice. System is the choice when
// nothing is saved, matching flat-pack--theme. Arrow keys and Space select
// a radio without closing the dialog.
const STORAGE_KEY = "flatpack-theme"
const CHOICES = ["system", "light", "dark"]

export default class extends Controller {
  connect() {
    this.boundSync = (event) => this.sync(event?.detail?.theme)
    window.addEventListener("flat-pack:theme-changed", this.boundSync)
    this.sync(window.localStorage.getItem(STORAGE_KEY))
  }

  disconnect() {
    window.removeEventListener("flat-pack:theme-changed", this.boundSync)
  }

  keydown(event) {
    const items = this.radios()
    const index = items.indexOf(event.currentTarget)
    if (index < 0) return

    if (event.key === " " || event.key === "Spacebar") {
      event.preventDefault()
      this.choose(items[index])
      return
    }

    const forward = event.key === "ArrowDown" || event.key === "ArrowRight"
    const backward = event.key === "ArrowUp" || event.key === "ArrowLeft"
    if (!forward && !backward) return

    event.preventDefault()
    const delta = forward ? 1 : -1
    const next = items[(index + delta + items.length) % items.length]
    this.choose(next)
    next.focus()
  }

  sync(saved) {
    const active = CHOICES.includes(saved) ? saved : "system"
    this.radios().forEach((item) => {
      const on = item.dataset.themeValue === active
      item.setAttribute("role", "radio")
      item.setAttribute("aria-checked", on ? "true" : "false")
      item.tabIndex = on ? 0 : -1
    })
  }

  choose(item) {
    this.application.getControllerForElementAndIdentifier(this.element, "flat-pack--theme")
      ?.switch({ currentTarget: item })
  }

  radios() {
    return [...this.element.querySelectorAll("[role='radiogroup'] [data-theme-value]")]
  }
}
