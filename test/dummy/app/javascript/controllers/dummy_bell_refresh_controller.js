import { Controller } from "@hotwired/stimulus"

// A test ping updates the inbox through Turbo immediately. The bell only
// refreshes on connect and on its poll, so ask it to refresh after a send.
const POLLING = "recording-studio-notifications--notification-polling"

export default class extends Controller {
  connect() {
    this.boundRefresh = (event) => this.refreshBell(event)
    this.element.addEventListener("turbo:submit-end", this.boundRefresh)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.boundRefresh)
  }

  refreshBell(event) {
    if (!event.detail?.success) return

    const bell = document.querySelector(`[data-controller~="${POLLING}"]`)
    if (!bell) return

    this.application.getControllerForElementAndIdentifier(bell, POLLING)?.refresh()
  }
}
