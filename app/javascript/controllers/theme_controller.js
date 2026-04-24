import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "apex-claw-theme"
const THEMES = ["dark", "light"]

export default class extends Controller {
  static targets = ["label", "darkIcon", "lightIcon"]

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
    // Async server sync — localStorage is already updated, UI is already applied
    fetch("/settings", {
      method: "PATCH",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
      },
      body: new URLSearchParams({ "user[theme_preference]": theme })
    }).catch(() => {
      // Silently fail — localStorage is source of truth for next page load
    })
  }
}
