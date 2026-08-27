import { Controller } from "@hotwired/stimulus"

// Registers this browser for FCM push, or accepts a manual FID when Firebase
// ENV config is missing (dummy / local demos).
export default class extends Controller {
  static targets = ["status", "manualFid", "enablePanel", "disablePanel", "diagnostics"]
  static values = {
    registerUrl: String,
    unregisterUrlTemplate: String,
    testPushUrlTemplate: String,
    vapidKey: String,
    firebaseConfig: Object,
    firebaseReady: Boolean,
    serviceWorkerPath: String,
    installations: Array
  }

  connect() {
    this.setStatus("")
    this.currentInstallation = null
    this.showEnable()

    this._onPushClick = (event) => {
      const enable = event.target.closest("[data-push-enable]")
      if (enable && this.element.contains(enable)) {
        this.enable(event)
        return
      }

      const disable = event.target.closest("[data-push-disable]")
      if (disable && this.element.contains(disable)) {
        this.disable(event)
        return
      }

      const localTest = event.target.closest("[data-push-local-test]")
      if (localTest && this.element.contains(localTest)) {
        this.showLocalNotification(event)
        return
      }

      const serverTest = event.target.closest("[data-push-server-test]")
      if (serverTest && this.element.contains(serverTest)) {
        this.sendTestPush(event)
      }
    }
    this.element.addEventListener("click", this._onPushClick)
    this.detectCurrentBrowser()
    this.renderDiagnostics()
  }

  disconnect() {
    if (this._onPushClick) {
      this.element.removeEventListener("click", this._onPushClick)
      this._onPushClick = null
    }
  }

  async detectCurrentBrowser() {
    if (!this.firebaseReadyValue) return
    if (!("Notification" in window) || Notification.permission !== "granted") return

    try {
      const token = await this.fetchFirebaseToken()
      if (!token) return

      const match = (this.installationsValue || []).find(
        (row) => row.firebase_installation_id === token
      )
      if (!match) return

      this.currentInstallation = match
      this.showDisable()
      this.markCurrentInstallation(match.id)
    } catch (error) {
      // Keep Enable visible when token lookup fails (e.g. push service down).
      console.warn("[push-devices] could not detect this browser", error)
    }
  }

  async enable(event) {
    event?.preventDefault?.()
    event?.stopPropagation?.()
    this.setStatus("Asking for permission…")

    try {
      if (!("Notification" in window)) {
        this.setStatus("This browser does not support notifications.")
        return
      }

      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        this.setStatus("Notifications stay off until you allow them.")
        return
      }

      this.setStatus("Getting a Firebase token…")
      const token = await this.fetchFirebaseToken()
      if (!token) {
        this.setStatus("Could not get a Firebase token. Check the Firebase importmap pins.")
        return
      }

      this.setStatus("Saving this browser…")
      await this.registerInstallation(token)
      this.setStatus("This browser is ready for push.")
      window.location.reload()
    } catch (error) {
      console.error("[push-devices] enable failed", error)
      this.setStatus(this.friendlyError(error) || "Could not enable push on this browser.")
    }
  }

  async disable(event) {
    event?.preventDefault?.()
    event?.stopPropagation?.()

    const installation = this.currentInstallation
    if (!installation?.id) {
      this.setStatus("This browser is not registered yet.")
      this.showEnable()
      return
    }

    this.setStatus("Turning off push on this browser…")

    try {
      await this.unregisterInstallation(installation.id)
      await this.deleteFirebaseToken().catch(() => null)
      this.setStatus("This browser will stay quiet now.")
      window.location.reload()
    } catch (error) {
      console.error("[push-devices] disable failed", error)
      this.setStatus(this.friendlyError(error) || "Could not disable push on this browser.")
    }
  }

  // Asks the service worker to show a notification with no FCM involved. If
  // nothing appears here, the block is browser or OS notification settings.
  async showLocalNotification(event) {
    event?.preventDefault?.()
    event?.stopPropagation?.()

    try {
      if (!("Notification" in window)) {
        this.setStatus("This browser does not support notifications.")
        return
      }

      if (Notification.permission !== "granted") {
        const permission = await Notification.requestPermission()
        if (permission !== "granted") {
          this.setStatus("Notifications stay off until you allow them.")
          return
        }
      }

      const registration = await this.resolveServiceWorkerRegistration()
      await registration.showNotification("Local test", {
        body: "Shown by the service worker without FCM.",
        icon: "/icon.png",
        data: { url: "/" }
      })
      this.setStatus(
        "Asked the service worker to show a notification. Nothing on screen means your browser or OS is hiding it (macOS: System Settings → Notifications → Chrome)."
      )
    } catch (error) {
      console.error("[push-devices] local notification failed", error)
      this.setStatus(this.friendlyError(error) || "Could not show a local notification.")
    } finally {
      this.renderDiagnostics()
    }
  }

  // Sends a real FCM message to this installation and reports the response, so
  // an accepted send with no visible notification is easy to tell apart.
  async sendTestPush(event) {
    event?.preventDefault?.()
    event?.stopPropagation?.()

    const installation = this.currentInstallation
    if (!installation?.id) {
      this.setStatus("Enable this browser first, then send a test push.")
      return
    }

    const template = this.testPushUrlTemplateValue || ""
    if (!template) {
      this.setStatus("Test push is not available on this screen.")
      return
    }

    this.setStatus("Asking FCM to push this browser…")

    try {
      const response = await fetch(template.replace(":id", installation.id), {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        credentials: "same-origin"
      })
      const payload = await response.json().catch(() => ({}))

      if (payload.accepted) {
        this.setStatus(
          "FCM accepted the push (HTTP " +
            (payload.status || 200) +
            "). If no notification appears, the browser or OS is hiding it — not the server."
        )
      } else {
        this.setStatus("FCM refused this device: " + (payload.error || "unknown error"))
      }
    } catch (error) {
      console.error("[push-devices] test push failed", error)
      this.setStatus(this.friendlyError(error) || "Could not send a test push.")
    }
  }

  async renderDiagnostics() {
    if (!this.hasDiagnosticsTarget) return

    const rows = []
    rows.push(["Page origin", window.location.origin])
    rows.push([
      "Notification permission",
      "Notification" in window ? Notification.permission : "unsupported"
    ])

    if (!("serviceWorker" in navigator)) {
      rows.push(["Service worker", "unsupported"])
    } else {
      try {
        const registration = await navigator.serviceWorker.getRegistration()
        if (!registration) {
          rows.push(["Service worker", "not registered on this origin"])
        } else {
          const state = registration.active
            ? "active"
            : registration.waiting
              ? "waiting to activate"
              : "installing"
          rows.push(["Service worker", state + " (scope " + registration.scope + ")"])

          const subscription = await registration.pushManager?.getSubscription?.()
          rows.push([
            "Push subscription",
            subscription ? new URL(subscription.endpoint).host : "none"
          ])
        }
      } catch (error) {
        rows.push(["Service worker", "could not be read: " + (error?.message || error)])
      }
    }

    this.diagnosticsTarget.innerHTML = ""
    rows.forEach(([label, value]) => {
      const row = document.createElement("p")
      row.className = "text-xs text-(--surface-content-color)"
      const strong = document.createElement("strong")
      strong.textContent = label + ": "
      row.appendChild(strong)
      row.appendChild(document.createTextNode(String(value)))
      this.diagnosticsTarget.appendChild(row)
    })
  }

  async registerManualFid(event) {
    event?.preventDefault?.()
    const fid = this.hasManualFidTarget ? this.manualFidTarget.value.trim() : ""
    if (!fid) {
      this.setStatus("Paste a Firebase installation id first.")
      return
    }

    try {
      await this.registerInstallation(fid)
      this.setStatus("Registered.")
      window.location.reload()
    } catch (error) {
      console.error(error)
      this.setStatus(this.friendlyError(error) || "Could not register that id.")
    }
  }

  async fetchFirebaseToken() {
    if (this.hasFirebaseReadyValue && !this.firebaseReadyValue) {
      return null
    }

    const config = this.firebaseConfigValue || {}
    const { initializeApp } = await import("firebase/app")
    const { getMessaging, getToken, isSupported } = await import("firebase/messaging")

    if (!(await isSupported())) {
      throw new Error("This browser does not support Firebase messaging.")
    }

    const app = initializeApp(config)
    const messaging = getMessaging(app)
    const registration = await this.resolveServiceWorkerRegistration()

    return getToken(messaging, {
      vapidKey: this.vapidKeyValue,
      serviceWorkerRegistration: registration
    })
  }

  async deleteFirebaseToken() {
    if (this.hasFirebaseReadyValue && !this.firebaseReadyValue) return

    const config = this.firebaseConfigValue || {}
    const { initializeApp } = await import("firebase/app")
    const { getMessaging, deleteToken, isSupported } = await import("firebase/messaging")

    if (!(await isSupported())) return

    const app = initializeApp(config)
    const messaging = getMessaging(app)
    await deleteToken(messaging)
  }

  async resolveServiceWorkerRegistration() {
    if (window.RecordingStudioPwa?.serviceWorkerReady) {
      try {
        return await window.RecordingStudioPwa.serviceWorkerReady
      } catch (error) {
        // Host head may reject when rendered from a mounted engine without
        // main_app helpers. Fall through to an explicit register() below.
        if (!String(error?.message || "").includes("not mounted")) {
          throw error
        }
      }
    }

    if (!("serviceWorker" in navigator)) {
      throw new Error("This browser does not support service workers.")
    }

    const existing = await navigator.serviceWorker.getRegistration()
    if (existing) return existing

    const path = this.hasServiceWorkerPathValue ? this.serviceWorkerPathValue : "/service-worker.js"
    await navigator.serviceWorker.register(path)
    return navigator.serviceWorker.ready
  }

  async registerInstallation(firebaseInstallationId, legacyFcmToken = null) {
    const body = {
      installation: {
        firebase_installation_id: firebaseInstallationId,
        legacy_fcm_token: legacyFcmToken,
        platform: "web",
        label: navigator.userAgent?.slice(0, 120) || "Browser",
        user_agent: navigator.userAgent
      }
    }

    const response = await fetch(this.registerUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify(body),
      credentials: "same-origin"
    })

    if (!response.ok) {
      let message = "Registration failed"
      try {
        const payload = await response.json()
        message = payload.error || message
      } catch (_error) {
        // ignore
      }
      throw new Error(message)
    }

    return response.json()
  }

  async unregisterInstallation(id) {
    const template = this.unregisterUrlTemplateValue || ""
    const url = template.includes(":id") ? template.replace(":id", id) : `${template.replace(/\/$/, "")}/${id}`

    const response = await fetch(url, {
      method: "DELETE",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin"
    })

    if (!response.ok && response.status !== 204) {
      throw new Error("Could not remove this browser.")
    }
  }

  showEnable() {
    if (this.hasEnablePanelTarget) this.enablePanelTarget.classList.remove("hidden")
    if (this.hasDisablePanelTarget) this.disablePanelTarget.classList.add("hidden")
  }

  showDisable() {
    if (this.hasEnablePanelTarget) this.enablePanelTarget.classList.add("hidden")
    if (this.hasDisablePanelTarget) this.disablePanelTarget.classList.remove("hidden")
  }

  markCurrentInstallation(id) {
    const row = this.element.querySelector(`[data-installation-id="${id}"]`)
    if (!row) return

    const label = row.querySelector("[data-installation-current-label]")
    if (label) label.classList.remove("hidden")
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  friendlyError(error) {
    const message = String(error?.message || error || "")
    const name = String(error?.name || "")

    if (name === "NotAllowedError" || /permission|not allowed/i.test(message)) {
      return "Notifications stay off until you allow them in the browser."
    }

    if (/push service not available|push service error/i.test(message) || name === "AbortError") {
      return "This browser could not reach Chrome's push service. Try Google Chrome (not Brave/ungoogled), enable Google push services, or check network/VPN blocks to Google."
    }

    return message || null
  }

  setStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }
}
