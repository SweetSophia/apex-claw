import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "apex-claw-theme"
const THEMES = ["dark", "light"]

export default class extends Controller {
  static targets = ["label", "darkIcon", "lightIcon"]
  static values = {
    settingsPath: String
  }

  connect() {
    this.applyTheme(this.currentTheme())
  }

  toggle() {
    const nextTheme = this.currentTheme() === "dark" ? "light" : "dark"
    window.localStorage.setItem(STORAGE_KEY, nextTheme)
    this.applyTheme(nextTheme)
    this.syncTheme(nextTheme)
  }

  currentTheme() {
    const theme = document.documentElement.dataset.theme

    if (THEMES.includes(theme)) return theme

    return "dark"
  }

  applyTheme(theme) {
    document.documentElement.dataset.theme = theme
    this.updateMetaThemeColor(theme)
    this.updateToggle(theme)
  }

  updateMetaThemeColor(theme) {
    const meta = document.getElementById("theme-color-meta")
    if (!meta) return

    meta.setAttribute("content", theme === "light" ? "#f8fafc" : "#161619")
  }

  updateToggle(theme) {
    const isLight = theme === "light"

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = isLight ? "Dark" : "Light"
    }

    if (this.hasDarkIconTarget) {
      this.darkIconTarget.classList.toggle("hidden", !isLight)
    }

    if (this.hasLightIconTarget) {
      this.lightIconTarget.classList.toggle("hidden", isLight)
    }
  }

  syncTheme(theme) {
    // Settings path provided via data-theme-settings-path-value on <body>
    const settingsPath = this.settingsPathValue
    if (!settingsPath) return

    // Sync only when Rails exposes a mounted settings path and CSRF token.
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (!csrfToken) return

    // Use XMLHttpRequest instead of fetch to avoid Turbo intercepting the response
    // and triggering a full page navigation (which caused duplicate request floods).
    const xhr = new XMLHttpRequest()
    xhr.open("PATCH", settingsPath, true)
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
    xhr.setRequestHeader("X-CSRF-Token", csrfToken)
    xhr.setRequestHeader("Accept", "application/json")
    xhr.send(new URLSearchParams({ "user[theme_preference]": theme }).toString())
  }
}
