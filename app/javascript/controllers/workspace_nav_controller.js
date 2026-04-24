import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "drawer"]

  connect() {
    this.openHandler = () => this.open()
    this.closeHandler = () => this.close()
    this.toggleHandler = () => this.toggle()

    document.addEventListener("workspace-nav:open", this.openHandler)
    document.addEventListener("workspace-nav:close", this.closeHandler)
    document.addEventListener("workspace-nav:toggle", this.toggleHandler)

    // Close on escape key
    this.escapeHandler = (e) => {
      if (e.key === "Escape" && !this.drawerTarget.classList.contains("-translate-x-full")) {
        this.close()
      }
    }
    document.addEventListener("keydown", this.escapeHandler)
  }

  disconnect() {
    document.removeEventListener("workspace-nav:open", this.openHandler)
    document.removeEventListener("workspace-nav:close", this.closeHandler)
    document.removeEventListener("workspace-nav:toggle", this.toggleHandler)
    document.removeEventListener("keydown", this.escapeHandler)
  }

  open() {
    this.overlayTarget.classList.remove("hidden")
    this.drawerTarget.classList.remove("-translate-x-full")
    document.body.style.overflow = "hidden"
    // Focus the close button for accessibility
    const closeBtn = this.drawerTarget.querySelector('button[aria-label="Close navigation"]')
    closeBtn?.focus()
  }

  close() {
    this.overlayTarget.classList.add("hidden")
    this.drawerTarget.classList.add("-translate-x-full")
    document.body.style.overflow = ""
  }

  toggle() {
    if (this.drawerTarget.classList.contains("-translate-x-full")) {
      this.open()
    } else {
      this.close()
    }
  }
}