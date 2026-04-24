import { Controller } from "@hotwired/stimulus"

// Dispatches custom DOM events via Stimulus actions (CSP-safe replacement for inline onclick)
//
// Usage:
//   <button data-controller="ui-event"
//           data-ui-event-name-value="command-bar:toggle"
//           data-action="click->ui-event#dispatch">
//     ⌘K
//   </button>

export default class extends Controller {
  static values = { name: String }

  dispatch() {
    const eventName = this.nameValue
    if (eventName) {
      document.dispatchEvent(new CustomEvent(eventName))
    }
  }
}
