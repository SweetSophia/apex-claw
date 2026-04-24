import { Controller } from "@hotwired/stimulus"

// Handles icon selection in board modals (CSP-safe replacement for inline selectBoardIcon/selectEditBoardIcon)
//
// Supports two modals via params:
//   - New board: target-param="board-icon-field", group-param="icon-group"
//   - Edit board: target-param="edit-board-icon-field", group-param="edit-icon-group"
//
// Usage:
//   <button data-controller="board-icon-picker"
//           data-action="click->board-icon-picker#select"
//           data-board-icon-picker-icon-value="📋"
//           data-board-icon-picker-target-param="board-icon-field"
//           data-board-icon-picker-group-param="icon-group">

export default class extends Controller {
  static values = { icon: String }
  static classes = ["selected"]

  select() {
    // Determine which field and group to target based on params
    const fieldId = this.element.dataset.boardIconPickerTargetParam || "edit-board-icon-field"
    const groupId = this.element.dataset.boardIconPickerGroupParam || "edit-icon-group"

    const field = document.getElementById(fieldId)
    if (field) field.value = this.iconValue

    // Update visual selection state
    const group = document.getElementById(groupId)
    if (group) {
      group.querySelectorAll("button").forEach(btn => {
        btn.classList.remove("ring-2", "ring-accent")
      })
    }
    this.element.classList.add("ring-2", "ring-accent")
  }
}
