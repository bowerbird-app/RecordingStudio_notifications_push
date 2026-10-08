import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["enablePanel", "status"]
  static values = {
    registerUrl: String,
    unregisterUrlTemplate: String,
    vapidKey: String,
    firebaseConfig: Object,
    firebaseReady: Boolean,
    serviceWorkerPath: String,
    installations: Array,
    copy: Object
  }

  connect() {
    this.currentInstallation = null
    this.updateEnableLabel()
    this.showEnable()

    this._onPushClick = (event) => {
      const enable = event.target.closest("[data-push-enable]")
      if (enable && this.element.contains(enable)) {
        this.enable(event)
      }
    }
    this.element.addEventListener("click", this._onPushClick)

    this.detectCurrentBrowser()
  }

  disconnect() {
    if (this._onPushClick) {
      this.element.removeEventListener("click", this._onPushClick)
      this._onPushClick = null
    }
  }

  copy(key, vars = {}) {
    const template = (this.copyValue || {})[key]
    if (template == null || template === "") return ""

    return String(template).replace(/%\{(\w+)\}/g, (_, name) => {
      const value = vars[name]
      return value == null ? "" : String(value)
    })
  }

  showStatus(message) {
    if (!this.hasStatusTarget) return

    const text = (message || "").toString().trim()
    this.statusTarget.textContent = text
    this.statusTarget.classList.toggle("hidden", text.length === 0)
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
      this.hideEnablePanel()
      this.markCurrentInstallation(match.id)
    } catch (error) {
      console.warn("[push-devices] could not detect this browser", error)
    }
  }

  async enable(event) {
    event?.preventDefault?.()
    event?.stopPropagation?.()
    this.showStatus("")

    try {
      if (!("Notification" in window)) {
        this.showStatus(this.copy("unsupported_notifications"))
        return
      }

      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        this.showStatus(this.copy("permission_denied"))
        return
      }

      const token = await this.fetchFirebaseToken()
      if (!token) {
        this.showStatus(this.copy("token_failed"))
        return
      }

      await this.registerInstallation(token)
      window.location.reload()
    } catch (error) {
      console.error("[push-devices] enable failed", error)
      this.showStatus(error?.message || this.copy("registration_failed"))
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
      throw new Error(this.copy("unsupported_messaging"))
    }

    const app = initializeApp(config)
    const messaging = getMessaging(app)
    const registration = await this.resolveServiceWorkerRegistration()

    return getToken(messaging, {
      vapidKey: this.vapidKeyValue,
      serviceWorkerRegistration: registration
    })
  }

  async resolveServiceWorkerRegistration() {
    if (window.RecordingStudioPwa?.serviceWorkerReady) {
      try {
        return await window.RecordingStudioPwa.serviceWorkerReady
      } catch (error) {
        if (!String(error?.message || "").includes("not mounted")) {
          throw error
        }
      }
    }

    if (!("serviceWorker" in navigator)) {
      throw new Error(this.copy("unsupported_service_worker"))
    }

    const existing = await navigator.serviceWorker.getRegistration()
    if (existing) return existing

    const path = this.hasServiceWorkerPathValue ? this.serviceWorkerPathValue : "/service-worker.js"
    await navigator.serviceWorker.register(path)
    return navigator.serviceWorker.ready
  }

  installedApp() {
    if (window.navigator.standalone === true) return true
    if (window.matchMedia("(display-mode: standalone)").matches) return true
    if (window.matchMedia("(display-mode: fullscreen)").matches) return true

    return false
  }

  updateEnableLabel() {
    if (!this.hasEnablePanelTarget) return

    const button = this.enablePanelTarget.querySelector("button")
    if (!button) return

    button.textContent = this.installedApp()
      ? this.copy("enable_device")
      : this.copy("enable_browser")
  }

  browserLabel() {
    const { browser, os } = this.detectClient()
    return this.copy("label_on", { browser, os })
  }

  detectClient() {
    const ua = navigator.userAgent || ""
    const platformHint = navigator.userAgentData?.platform || ""

    let browserKey = "browser"
    if (/Edg\/|EdgiOS\//.test(ua)) browserKey = "edge"
    else if (/OPR\/|OPiOS\//.test(ua)) browserKey = "opera"
    else if (/CriOS\/|Chrome\//.test(ua)) browserKey = "chrome"
    else if (/FxiOS\/|Firefox\//.test(ua)) browserKey = "firefox"
    else if (/Safari\//.test(ua)) browserKey = "safari"

    let osKey = "this_device"
    if (/iPad|Macintosh/.test(ua) && navigator.maxTouchPoints > 1) osKey = "ipad"
    else if (/iPhone|iPod|iOS/.test(ua) || /iPhone|iPad|iOS/i.test(platformHint)) {
      osKey = /iPad/.test(ua) ? "ipad" : "iphone"
    } else if (/Mac OS X|Macintosh|macOS/i.test(ua) || /macOS|Mac/i.test(platformHint)) osKey = "mac"
    else if (/Windows|Win32|Win64/i.test(ua) || /Windows/i.test(platformHint)) osKey = "windows"
    else if (/Android/i.test(ua) || /Android/i.test(platformHint)) osKey = "android"
    else if (/Linux/i.test(ua) || /Linux/i.test(platformHint)) osKey = "linux"

    return {
      browser: this.copy(`browsers.${browserKey}`) || this.copy("browser"),
      os: this.copy(`os.${osKey}`) || this.copy("this_device")
    }
  }

  async registerInstallation(firebaseInstallationId, legacyFcmToken = null) {
    const body = {
      installation: {
        firebase_installation_id: firebaseInstallationId,
        legacy_fcm_token: legacyFcmToken,
        platform: this.installedApp() ? "pwa" : "web",
        label: this.browserLabel(),
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
      let message = this.copy("registration_failed")
      try {
        const payload = await response.json()
        message = payload.error || message
      } catch (_error) {
      }
      throw new Error(message)
    }

    return response.json()
  }

  showEnable() {
    if (this.hasEnablePanelTarget) this.enablePanelTarget.classList.remove("hidden")
  }

  hideEnablePanel() {
    if (this.hasEnablePanelTarget) this.enablePanelTarget.classList.add("hidden")
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
}
