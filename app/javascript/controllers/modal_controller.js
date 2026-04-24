import { Controller } from "@hotwired/stimulus"

// Generic modal controller — show/hide via Stimulus actions (CSP-safe, no inline onclick)
//
// Usage:
//   <div data-controller="modal" data-modal-id-value="my-modal">
//     <button data-action="modal#show">Open</button>
//   </div>
//
//   <!-- Or target a modal by id from anywhere -->
//   <button data-action="click->modal#show" data-modal-id-param="board-settings-modal">Settings</button>
//
// On the modal element itself:
//   <div id="board-settings-modal" class="hidden ...">
//     <div data-action="click->modal#hide" data-modal-id-param="board-settings-modal">Backdrop</div>
//     <button data-action="click->modal#hide" data-modal-id-param="board-settings-modal">Close</button>
//   </div>

export default class extends Controller {
  static values = { id: String }

  show(event) {
    const modalId = event?.params?.id || this.idValue
    if (!modalId) return
    const modal = document.getElementById(modalId)
    if (modal) modal.classList.remove("hidden")
  }

  hide(event) {
    const modalId = event?.params?.id || this.idValue
    if (!modalId) return
    const modal = document.getElementById(modalId)
    if (modal) modal.classList.add("hidden")
  }
}
