import { Controller } from "@hotwired/stimulus"

// Registers this browser for FCM push, or accepts a manual FID when Firebase
// ENV config is missing (dummy / local demos).
export default class extends Controller {
  static targets = ["manualFid", "enablePanel", "helpDetected", "helpPermission", "helpSiteSteps", "helpOsSteps"]
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
    this.fillNotificationHelp()

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
    const { browser, os } = this.detectClient()
    return `${browser} on ${os}`
  }

  detectClient() {
    const ua = navigator.userAgent || ""
    const platformHint = navigator.userAgentData?.platform || ""

    let browser = "Browser"
    if (/Edg\/|EdgiOS\//.test(ua)) browser = "Edge"
    else if (/OPR\/|OPiOS\//.test(ua)) browser = "Opera"
    else if (/CriOS\/|Chrome\//.test(ua)) browser = "Chrome"
    else if (/FxiOS\/|Firefox\//.test(ua)) browser = "Firefox"
    else if (/Safari\//.test(ua)) browser = "Safari"

    let os = "this device"
    if (/iPad|Macintosh/.test(ua) && navigator.maxTouchPoints > 1) os = "iPad"
    else if (/iPhone|iPod|iOS/.test(ua) || /iPhone|iPad|iOS/i.test(platformHint)) {
      os = /iPad/.test(ua) ? "iPad" : "iPhone"
    } else if (/Mac OS X|Macintosh|macOS/i.test(ua) || /macOS|Mac/i.test(platformHint)) os = "Mac"
    else if (/Windows|Win32|Win64/i.test(ua) || /Windows/i.test(platformHint)) os = "Windows"
    else if (/Android/i.test(ua) || /Android/i.test(platformHint)) os = "Android"
    else if (/Linux/i.test(ua) || /Linux/i.test(platformHint)) os = "Linux"

    return { browser, os }
  }

  fillNotificationHelp() {
    const client = this.detectClient()
    const guide = this.notificationHelpGuide(client)

    if (this.hasHelpDetectedTarget) {
      this.helpDetectedTarget.textContent = `Looks like ${client.browser} on ${client.os}.`
    }

    if (this.hasHelpPermissionTarget) {
      this.helpPermissionTarget.textContent = this.sitePermissionHelp()
    }

    this.replaceStepList(this.hasHelpSiteStepsTarget ? this.helpSiteStepsTarget : null, guide.site)
    this.replaceStepList(this.hasHelpOsStepsTarget ? this.helpOsStepsTarget : null, guide.os)
  }

  sitePermissionHelp() {
    if (!("Notification" in window)) {
      return "This browser does not support web notifications."
    }

    switch (Notification.permission) {
      case "granted":
        return "This site is allowed in the browser. If banners still fail, check system settings below."
      case "denied":
        return "This site is blocked in the browser. Allow it first, then try Enable again."
      default:
        return "This site has not been allowed yet. Tap Enable first, then use these steps if nothing shows up."
    }
  }

  notificationHelpGuide({ browser, os }) {
    const siteByBrowser = {
      Chrome: [
        "Click the lock or tune icon in the address bar",
        "Open Site settings → Notifications",
        "Choose Allow"
      ],
      Edge: [
        "Click the lock icon in the address bar",
        "Open Permissions for this site → Notifications",
        "Choose Allow"
      ],
      Firefox: [
        "Click the lock icon in the address bar",
        "Open Permissions → Notifications",
        "Choose Allow"
      ],
      Safari: [
        "Safari → Settings → Websites → Notifications",
        "Find this site and choose Allow"
      ],
      Opera: [
        "Click the lock icon in the address bar",
        "Open Site settings → Notifications",
        "Choose Allow"
      ]
    }

    const osByBrowser = {
      Mac: {
        Chrome: [
          "Open System Settings → Notifications",
          "Select Google Chrome",
          "Turn notifications on"
        ],
        Edge: [
          "Open System Settings → Notifications",
          "Select Microsoft Edge",
          "Turn notifications on"
        ],
        Firefox: [
          "Open System Settings → Notifications",
          "Select Firefox",
          "Turn notifications on"
        ],
        Safari: [
          "Open System Settings → Notifications",
          "Select Safari",
          "Turn notifications on"
        ],
        Opera: [
          "Open System Settings → Notifications",
          "Select Opera",
          "Turn notifications on"
        ]
      },
      Windows: {
        Chrome: [
          "Open Settings → System → Notifications",
          "Make sure notifications are on",
          "Allow Google Chrome"
        ],
        Edge: [
          "Open Settings → System → Notifications",
          "Make sure notifications are on",
          "Allow Microsoft Edge"
        ],
        Firefox: [
          "Open Settings → System → Notifications",
          "Make sure notifications are on",
          "Allow Firefox"
        ],
        Opera: [
          "Open Settings → System → Notifications",
          "Make sure notifications are on",
          "Allow Opera"
        ]
      },
      iPhone: {
        Safari: [
          "Open Settings → Notifications → Safari",
          "Allow Notifications"
        ],
        Chrome: [
          "Open Settings → Notifications → Chrome",
          "Allow Notifications"
        ],
        Edge: [
          "Open Settings → Notifications → Edge",
          "Allow Notifications"
        ],
        Firefox: [
          "Open Settings → Notifications → Firefox",
          "Allow Notifications"
        ]
      },
      iPad: {
        Safari: [
          "Open Settings → Notifications → Safari",
          "Allow Notifications"
        ],
        Chrome: [
          "Open Settings → Notifications → Chrome",
          "Allow Notifications"
        ],
        Edge: [
          "Open Settings → Notifications → Edge",
          "Allow Notifications"
        ],
        Firefox: [
          "Open Settings → Notifications → Firefox",
          "Allow Notifications"
        ]
      },
      Android: {
        Chrome: [
          "Open Settings → Apps → Chrome → Notifications",
          "Allow notifications"
        ],
        Edge: [
          "Open Settings → Apps → Edge → Notifications",
          "Allow notifications"
        ],
        Firefox: [
          "Open Settings → Apps → Firefox → Notifications",
          "Allow notifications"
        ],
        Opera: [
          "Open Settings → Apps → Opera → Notifications",
          "Allow notifications"
        ]
      },
      Linux: {
        Chrome: [
          "Open your desktop notification settings",
          "Allow Google Chrome (or Chromium)"
        ],
        Firefox: [
          "Open your desktop notification settings",
          "Allow Firefox"
        ],
        Edge: [
          "Open your desktop notification settings",
          "Allow Microsoft Edge"
        ],
        Opera: [
          "Open your desktop notification settings",
          "Allow Opera"
        ]
      }
    }

    const site = siteByBrowser[browser] || [
      "Open this browser’s site settings for notifications",
      "Allow this site"
    ]

    const osSteps =
      osByBrowser[os]?.[browser] ||
      osByBrowser[os]?.Safari ||
      [
        "Open your device notification settings",
        `Allow ${browser}`,
        "Then try a test alert again"
      ]

    return { site, os: osSteps }
  }

  replaceStepList(listElement, steps) {
    if (!listElement) return

    listElement.replaceChildren()
    steps.forEach((step) => {
      const item = document.createElement("li")
      item.textContent = step
      listElement.appendChild(item)
    })
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
