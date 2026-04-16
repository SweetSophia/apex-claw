import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="agent-presence"
// Subscribes to the "agents" Turbo Stream for real-time agent status updates.
// Expects a parent element with data-agent-presence-user-id-value
export default class extends Controller {
  static values = { userId: String }

  connect() {
    if (!this.userIdValue) return

    // The turbo_stream_from tag in the view already handles subscription.
    // This controller adds visual feedback — flash animation on status change.
    this.element.addEventListener("turbo:before-stream-render", this.onStreamRender.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-stream-render", this.onStreamRender.bind(this))
  }

  onStreamRender(event) {
    const stream = event.detail?.newStream
    if (!stream) return

    // Find the target agent card and flash it
    const targetId = stream.getAttribute("target")
    if (targetId) {
      const card = document.getElementById(targetId)
      if (card) {
        this.flashHighlight(card)
      }
    }
  }

  flashHighlight(element) {
    element.style.transition = "box-shadow 0.3s ease"
    element.style.boxShadow = "0 0 0 2px rgba(52, 211, 153, 0.4)"
    setTimeout(() => {
      element.style.boxShadow = ""
    }, 1500)
  }
}
