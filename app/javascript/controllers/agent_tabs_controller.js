import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="agent-tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]

  switch(event) {
    event.preventDefault()
    const tab = event.currentTarget
    const panelId = tab.dataset.panel

    // Update tab active states
    this.tabTargets.forEach(t => {
      t.classList.remove('border-amber-400', 'text-amber-400')
      t.classList.add('border-transparent', 'text-[#666]')
    })
    tab.classList.remove('border-transparent', 'text-[#666]')
    tab.classList.add('border-amber-400', 'text-amber-400')

    // Show selected panel, hide others
    this.panelTargets.forEach(p => {
      if (p.id === panelId) {
        p.classList.remove('hidden')
      } else {
        p.classList.add('hidden')
      }
    })
  }
}
