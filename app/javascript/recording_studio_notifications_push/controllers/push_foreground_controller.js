import { Controller } from "@hotwired/stimulus"

// Shows an in-page toast when the push service worker posts rsnp:push.
// Needed when the tab is focused (OS toasts are easy to miss, especially in
// embedded browsers) and when FCM delivers a data-only message.
export default class extends Controller {
  static targets = ["toast"]

  connect() {
    this._onMessage = (event) => {
      const payload = event.data
      if (!payload || payload.type !== "rsnp:push") return
      this.showToast(payload)
    }

    if ("serviceWorker" in navigator) {
      navigator.serviceWorker.addEventListener("message", this._onMessage)
    }
  }

  disconnect() {
    if ("serviceWorker" in navigator && this._onMessage) {
      navigator.serviceWorker.removeEventListener("message", this._onMessage)
    }
  }

  showToast(payload) {
    const title = payload.title || "Notification"
    const body = payload.body || ""
    const url = payload.url || "/"

    if (this.hasToastTarget) {
      this.toastTarget.innerHTML = ""
      const alert = document.createElement("div")
      alert.setAttribute("role", "alert")
      alert.className =
        "mb-4 border border-[var(--alert-info-border-color)] bg-[var(--alert-info-background-color)] " +
        "text-[var(--alert-info-text-color)] rounded-md px-4 py-3"
      alert.innerHTML =
        `<p class="text-sm font-medium"></p>` +
        `<p class="mt-1 text-sm"></p>` +
        `<p class="mt-2 text-xs"><a class="underline" href=""></a></p>`
      alert.querySelector("p:nth-child(1)").textContent = title
      alert.querySelector("p:nth-child(2)").textContent = body
      const link = alert.querySelector("a")
      link.href = url
      link.textContent = "Open"
      this.toastTarget.appendChild(alert)
    }

    // Also try a page-level Notification for environments that surface those.
    if ("Notification" in window && Notification.permission === "granted") {
      try {
        const note = new Notification(title, { body, data: { url } })
        note.onclick = () => {
          window.focus()
          if (url) window.location.href = url
        }
      } catch (_error) {
        // Embedded browsers may reject Notification construction.
      }
    }
  }
}
