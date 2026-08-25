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
    // Bind Enable via event delegation on the controller root. Prefer this over
    // data-action on FlatPack::Button — long namespaced identifiers were a
    // silent no-op in some host layouts even when the controller connected.
    this._onPushEnableClick = (event) => {
      const trigger = event.target.closest("[data-push-enable]")
      if (!trigger || !this.element.contains(trigger)) return
      this.enable(event)
    }
    this.element.addEventListener("click", this._onPushEnableClick)
  }

  disconnect() {
    if (this._onPushEnableClick) {
      this.element.removeEventListener("click", this._onPushEnableClick)
      this._onPushEnableClick = null
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
