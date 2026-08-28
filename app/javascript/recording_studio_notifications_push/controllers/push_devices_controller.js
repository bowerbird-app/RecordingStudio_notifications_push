import { Controller } from "@hotwired/stimulus"

// Registers this browser for FCM push, or accepts a manual FID when Firebase
// ENV config is missing (dummy / local demos).
export default class extends Controller {
  static targets = ["manualFid", "enablePanel"]
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

    try {
      if (!("Notification" in window)) {
        throw new Error("This browser does not support notifications.")
      }

      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        return
      }

      const token = await this.fetchFirebaseToken()
      if (!token) {
        throw new Error("Could not get a Firebase token. Check the Firebase importmap pins.")
      }

      await this.registerInstallation(token)
      window.location.reload()
    } catch (error) {
      console.error("[push-devices] enable failed", error)
    }
  }

  async registerManualFid(event) {
    event?.preventDefault?.()
    const fid = this.hasManualFidTarget ? this.manualFidTarget.value.trim() : ""
    if (!fid) return

    try {
      await this.registerInstallation(fid)
      window.location.reload()
    } catch (error) {
      console.error("[push-devices] manual registration failed", error)
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
      throw new Error("This browser does not support service workers.")
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
      ? "Enable on this device"
      : "Enable on this browser"
  }

  browserLabel() {
    const ua = navigator.userAgent || ""

    let browser = "Browser"
    if (/Edg\//.test(ua)) browser = "Edge"
    else if (/Chrome\//.test(ua)) browser = "Chrome"
    else if (/Firefox\//.test(ua)) browser = "Firefox"
    else if (/Safari\//.test(ua)) browser = "Safari"

    let os = "device"
    if (/iPad/.test(ua)) os = "iPad"
    else if (/iPhone|iPod/.test(ua)) os = "iPhone"
    else if (/Mac OS X|Macintosh/.test(ua)) os = "Mac"
    else if (/Windows/.test(ua)) os = "Windows"
    else if (/Android/.test(ua)) os = "Android"
    else if (/Linux/.test(ua)) os = "Linux"

    return `${browser} on ${os}`
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
