import { Controller } from "@hotwired/stimulus"

// Registers this browser for FCM push, or accepts a manual FID when Firebase
// ENV config is missing (dummy / local demos).
export default class extends Controller {
  static targets = ["status", "manualFid"]
  static values = {
    registerUrl: String,
    unregisterUrlTemplate: String,
    vapidKey: String,
    firebaseConfig: Object,
    firebaseReady: Boolean,
    serviceWorkerPath: String
  }

  connect() {
    this.setStatus("")
  }

  async enable(event) {
    event?.preventDefault?.()
    this.setStatus("Asking for permission…")

    try {
      const permission = await Notification.requestPermission()
      if (permission !== "granted") {
        this.setStatus("Notifications stay off until you allow them.")
        return
      }

      const token = await this.fetchFirebaseToken()
      if (!token) {
        this.setStatus("Could not get a Firebase token. Check the Firebase importmap pins.")
        return
      }

      await this.registerInstallation(token)
      this.setStatus("This browser is ready for push.")
      window.location.reload()
    } catch (error) {
      console.error(error)
      this.setStatus(error.message || "Could not enable push on this browser.")
    }
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
      this.setStatus(error.message || "Could not register that id.")
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
      return window.RecordingStudioPwa.serviceWorkerReady
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

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  setStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }
}
