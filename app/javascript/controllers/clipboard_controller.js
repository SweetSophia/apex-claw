import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "label"]

  async copy() {
    const text = this.sourceTarget.textContent || this.sourceTarget.value || ""
    const originalText = this.hasLabelTarget ? this.labelTarget.textContent : null

    try {
      await this.writeText(text)
      this.setLabel("Copied!", originalText)
    } catch (err) {
      console.error("Failed to copy:", err)
      this.setLabel("Press Ctrl/Cmd+C", originalText)
      this.selectSource()
    }
  }

  async writeText(text) {
    if (navigator.clipboard?.writeText && window.isSecureContext) {
      await navigator.clipboard.writeText(text)
      return
    }

    this.selectSource()

    const successful = document.execCommand("copy")
    if (!successful) {
      throw new Error("execCommand copy failed")
    }
  }

  selectSource() {
    const element = this.sourceTarget

    if (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement) {
      element.focus()
      element.select()
      return
    }

    const selection = window.getSelection()
    const range = document.createRange()
    range.selectNodeContents(element)

    selection.removeAllRanges()
    selection.addRange(range)
  }

  setLabel(message, originalText) {
    if (!this.hasLabelTarget) return

    this.labelTarget.textContent = message

    setTimeout(() => {
      this.labelTarget.textContent = originalText || "Copy"
    }, 2000)
  }
}
