import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="task-board"
// Adds flash animation to task cards when they are updated via Turbo Streams.
// The turbo_stream_from in the board view handles subscription.
export default class extends Controller {
  connect() {
    this.boundHandler = this.onStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.boundHandler)
  }

  onStreamRender(event) {
    const stream = event.detail?.newStream
    if (!stream) return

    const targetId = stream.getAttribute("target")
    if (!targetId || !targetId.startsWith("task_")) return

    // Only flash for replace actions (updates)
    const action = stream.getAttribute("action")
    if (action === "replace") {
      // Use requestAnimationFrame to ensure the DOM is updated
      requestAnimationFrame(() => {
        const card = document.getElementById(targetId)
        if (card) {
          this.flashCard(card)
        }
      })
    }
  }

  flashCard(element) {
    element.classList.add("task-flash")
    setTimeout(() => {
      element.classList.remove("task-flash")
    }, 1200)
  }
}
