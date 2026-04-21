import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "input", "body", "searchResults", "actionsPanel", "agentPanel", "agentMessages", "modeIcon", "backButton"]
  static values = {
    mode: { type: String, default: "search" },
    open: { type: Boolean, default: false },
    currentBoardId: Number,
    searchItems: Array,
  }

  connect() {
    this.boundKeydown = this.globalKeydown.bind(this)
    this.boundToggle = this.toggle.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
    document.addEventListener("command-bar:toggle", this.boundToggle)

    this.messages = []
    this.typing = false
    this.results = []
    this.activeIndex = -1
    this.previousFocus = null

    this.inputTarget.setAttribute('role', 'combobox')
    this.inputTarget.setAttribute('aria-autocomplete', 'list')
    this.inputTarget.setAttribute('aria-expanded', 'false')
    this.inputTarget.setAttribute('aria-haspopup', 'listbox')

    // Link input to results container for assistive tech
    this.searchResultsTarget.id = 'command-bar-results'
    this.inputTarget.setAttribute('aria-controls', 'command-bar-results')
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    document.removeEventListener("command-bar:toggle", this.boundToggle)
  }

  globalKeydown(e) {
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
      e.preventDefault()
      this.toggle()
      return
    }

    if (!this.openValue) return

    if (e.key === "Escape") {
      e.preventDefault()
      if (this.modeValue === "agent" && this.messages.length > 0) {
        this.switchToSearch()
      } else {
        this.close()
      }
    }
  }

  toggle() {
    this.openValue ? this.close() : this.open()
  }

  open() {
    this.previousFocus = document.activeElement
    this.openValue = true
    this.modeValue = "search"
    this.messages = []
    this.typing = false
    this.dialogTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    this.showSearchMode()

    requestAnimationFrame(() => {
      this.inputTarget.value = ""
      this.inputTarget.focus()
      this.inputTarget.setAttribute('aria-expanded', 'true')
    })
  }

  close() {
    this.openValue = false
    this.dialogTarget.classList.add("hidden")
    this.backdropTarget.classList.add("hidden")
    this.inputTarget.value = ""
    this.messages = []
    this.typing = false
    this.results = []
    this.activeIndex = -1
    this.modeValue = "search"

    this.inputTarget.setAttribute('aria-expanded', 'false')

    if (this.previousFocus && typeof this.previousFocus.focus === "function") {
      this.previousFocus.focus()
    }
  }

  onInputKeydown(e) {
    if (this.modeValue === "agent") {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.sendMessage()
      }
      return
    }

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this.moveSelection(1)
      return
    }

    if (e.key === "ArrowUp") {
      e.preventDefault()
      this.moveSelection(-1)
      return
    }

    if (e.key === "Enter") {
      e.preventDefault()
      this.activateCurrentResult()
    }
  }

  onInput() {
    if (this.modeValue === "search") {
      this.search()
    }
  }

  showSearchMode() {
    this.modeValue = "search"
    this.agentPanelTarget.classList.add("hidden")
    this.searchResultsTarget.classList.add("hidden")
    this.actionsPanelTarget.classList.remove("hidden")
    this.updateModeIcon()
    this.updateInputPlaceholder()

    if (this.hasBackButtonTarget) {
      this.backButtonTarget.classList.add("hidden")
    }

    this.renderDefaultState()
  }

  search() {
    const query = this.inputTarget.value.trim().toLowerCase()

    if (!query) {
      this.renderDefaultState()
      return
    }

    const matches = this.searchItemsValue
      .map(item => ({ item, score: this.scoreItem(item, query) }))
      .filter(result => result.score > 0)
      .sort((a, b) => b.score - a.score || this.kindRank(a.item.kind) - this.kindRank(b.item.kind))
      .slice(0, 12)
      .map(result => result.item)

    this.results = matches
    this.actionsPanelTarget.classList.add("hidden")
    this.searchResultsTarget.classList.remove("hidden")

    if (matches.length === 0) {
      this.activeIndex = -1
      this.searchResultsTarget.innerHTML = ""
      const noResults = document.createElement("div")
      noResults.className = "px-4 py-8 text-center"
      noResults.appendChild(this.createElement("div", "No results", { class: "text-sm font-semibold text-[#888]" }))
      noResults.appendChild(this.createElement("div", 'Try a task name, board, or command like "focus" or "settings".', { class: "mt-1 text-xs text-[#555]" }))
      this.searchResultsTarget.appendChild(noResults)
      return
    }

    this.renderSearchResults(this.groupItems(matches))
    this.setActiveIndex(0)
  }

  renderSearchResults(sections) {
    this.searchResultsTarget.innerHTML = ""
    const fragment = document.createDocumentFragment()

    sections.forEach(section => {
      const sectionEl = document.createElement("section")
      sectionEl.className = "px-2 py-1"

      const labelEl = document.createElement("div")
      labelEl.className = "px-2.5 py-1.5 text-[10px] font-bold uppercase tracking-[0.06em] text-[#444]"
      labelEl.textContent = section.label
      sectionEl.appendChild(labelEl)

      const itemsContainer = document.createElement("div")
      itemsContainer.className = "flex flex-col gap-1"

      section.items.forEach((item, idx) => {
        const currentIndex = this.results.indexOf(item)
        const button = this.createSearchResultButton(item, currentIndex)
        itemsContainer.appendChild(button)
      })

      sectionEl.appendChild(itemsContainer)
      fragment.appendChild(sectionEl)
    })

    this.searchResultsTarget.appendChild(fragment)
  }

  createSearchResultButton(item, index) {
    const button = document.createElement("button")
    button.type = "button"
    button.dataset.commandBarResultIndex = index
    button.dataset.action = "click->command-bar#clickResult mouseenter->command-bar#hoverResult"
    button.className = "command-bar-result flex items-center gap-3 w-full rounded-lg border border-transparent bg-transparent px-2.5 py-[9px] text-left transition-colors hover:bg-white/[0.04] focus:outline-none"
    button.setAttribute("aria-selected", "false")

    const icon = document.createElement("div")
    icon.className = "flex h-8 w-8 items-center justify-center rounded-lg border border-white/[0.05] bg-white/[0.04] text-[13px] flex-shrink-0"
    icon.textContent = item.icon || "•"
    button.appendChild(icon)

    const content = document.createElement("div")
    content.className = "min-w-0 flex-1"

    const title = document.createElement("div")
    title.className = "truncate text-[13px] font-semibold text-[#ddd]"
    title.textContent = item.title || ""
    content.appendChild(title)

    if (item.subtitle) {
      const subtitle = document.createElement("div")
      subtitle.className = "truncate text-[11px] font-medium text-[#555]"
      subtitle.textContent = item.subtitle
      content.appendChild(subtitle)
    }
    button.appendChild(content)

    const kind = document.createElement("div")
    kind.className = "text-[10px] font-medium uppercase tracking-[0.06em] text-[#444]"
    kind.textContent = item.kind || ""
    button.appendChild(kind)

    return button
  }

  renderDefaultState() {
    const featuredActions = this.searchItemsValue.filter(item => item.kind === "action" && item.featured)
    const navigation = this.searchItemsValue.filter(item => item.kind === "nav").slice(0, 4)
    const boards = this.searchItemsValue.filter(item => item.kind === "board").slice(0, 5)
    const recentTasks = this.searchItemsValue.filter(item => item.kind === "task").slice(0, 5)

    this.results = [...featuredActions, ...navigation, ...boards, ...recentTasks]
    this.activeIndex = -1
    this.searchResultsTarget.classList.add("hidden")
    this.actionsPanelTarget.classList.remove("hidden")
    this.renderActionsPanel([
      { label: "Actions", items: featuredActions },
      { label: "Jump to", items: navigation },
      { label: "Boards", items: boards },
      { label: "Recent tasks", items: recentTasks },
    ])

    if (this.results.length > 0) {
      this.setActiveIndex(0)
    }
  }

  renderActionsPanel(sections) {
    this.actionsPanelTarget.innerHTML = ""
    const fragment = document.createDocumentFragment()

    sections.forEach(section => {
      const sectionEl = document.createElement("section")
      sectionEl.className = "px-2 py-1"

      const labelEl = document.createElement("div")
      labelEl.className = "px-2.5 py-1.5 text-[10px] font-bold uppercase tracking-[0.06em] text-[#444]"
      labelEl.textContent = section.label
      sectionEl.appendChild(labelEl)

      const itemsContainer = document.createElement("div")
      itemsContainer.className = "flex flex-col gap-1"

      section.items.forEach(item => {
        const currentIndex = this.results.indexOf(item)
        const button = this.createSearchResultButton(item, currentIndex)
        itemsContainer.appendChild(button)
      })

      sectionEl.appendChild(itemsContainer)
      fragment.appendChild(sectionEl)
    })

    const footer = document.createElement("div")
    footer.className = "px-4 pt-3 pb-4 text-[10px] font-medium text-[#444] border-t border-white/[0.05] mt-2 flex items-center justify-between"
    footer.appendChild(document.createElement("span")).textContent = "Use ↑ ↓ to move, ↵ to open"
    footer.appendChild(document.createElement("span")).textContent = "Esc to close"
    fragment.appendChild(footer)

    this.actionsPanelTarget.appendChild(fragment)
  }

  groupItems(items) {
    return [
      { label: "Actions", items: items.filter(item => item.kind === "action") },
      { label: "Navigation", items: items.filter(item => item.kind === "nav") },
      { label: "Boards", items: items.filter(item => item.kind === "board") },
      { label: "Tasks", items: items.filter(item => item.kind === "task") },
    ].filter(section => section.items.length > 0)
  }

  renderSections(sections, { emptyState }) {
    let index = 0

    const content = sections.map(section => {
      const itemsHtml = section.items.map(item => {
        const currentIndex = index
        index += 1
        return this.renderItem(item, currentIndex)
      }).join("")

      return `
        <section class="px-2 py-1">
          <div class="px-2.5 py-1.5 text-[10px] font-bold uppercase tracking-[0.06em] text-[#444]">${this.escapeHtml(section.label)}</div>
          <div class="flex flex-col gap-1">${itemsHtml}</div>
        </section>`
    }).join("")

    if (emptyState) {
      return `${content}
        <div class="px-4 pt-3 pb-4 text-[10px] font-medium text-[#444] border-t border-white/[0.05] mt-2 flex items-center justify-between">
          <span>Use ↑ ↓ to move, ↵ to open</span>
          <span>Esc to close</span>
        </div>`
    }

    return content
  }

  renderItem(item, index) {
    return `
      <button type="button"
              data-command-bar-result-index="${index}"
              data-action="click->command-bar#clickResult mouseenter->command-bar#hoverResult"
              class="command-bar-result flex items-center gap-3 w-full rounded-lg border border-transparent bg-transparent px-2.5 py-[9px] text-left transition-colors hover:bg-white/[0.04] focus:outline-none"
              aria-selected="false">
        <div class="flex h-8 w-8 items-center justify-center rounded-lg border border-white/[0.05] bg-white/[0.04] text-[13px] flex-shrink-0">${this.escapeHtml(item.icon || "•")}</div>
        <div class="min-w-0 flex-1">
          <div class="truncate text-[13px] font-semibold text-[#ddd]">${this.escapeHtml(item.title)}</div>
          <div class="truncate text-[11px] font-medium text-[#555]">${this.escapeHtml(item.subtitle || "")}</div>
        </div>
        <div class="text-[10px] font-medium uppercase tracking-[0.06em] text-[#444]">${this.escapeHtml(item.kind)}</div>
      </button>`
  }

  clickResult(e) {
    const index = Number.parseInt(e.currentTarget.dataset.commandBarResultIndex, 10)
    this.selectResult(index)
  }

  hoverResult(e) {
    const index = Number.parseInt(e.currentTarget.dataset.commandBarResultIndex, 10)
    this.setActiveIndex(index)
  }

  moveSelection(direction) {
    const elements = this.visibleResultElements()
    if (elements.length === 0) return

    if (this.activeIndex === -1) {
      this.setActiveIndex(direction > 0 ? 0 : elements.length - 1)
      return
    }

    const nextIndex = (this.activeIndex + direction + elements.length) % elements.length
    this.setActiveIndex(nextIndex)
  }

  setActiveIndex(index) {
    const elements = this.visibleResultElements()
    if (elements.length === 0) {
      this.activeIndex = -1
      return
    }

    this.activeIndex = Math.max(0, Math.min(index, elements.length - 1))

    elements.forEach((element, currentIndex) => {
      const isActive = currentIndex === this.activeIndex
      element.classList.toggle("bg-white/[0.06]", isActive)
      element.classList.toggle("border-white/[0.08]", isActive)
      element.setAttribute("aria-selected", isActive ? "true" : "false")
    })

    const activeElement = elements[this.activeIndex]
    if (activeElement) {
      activeElement.scrollIntoView({ block: "nearest" })
    }
  }

  activateCurrentResult() {
    if (this.activeIndex === -1 && this.results.length > 0) {
      this.setActiveIndex(0)
    }

    if (this.activeIndex >= 0) {
      this.selectResult(this.activeIndex)
    }
  }

  visibleResultElements() {
    return Array.from(this.element.querySelectorAll("[data-command-bar-result-index]"))
  }

  selectResult(index) {
    const item = this.results[index]
    if (!item) return

    if (item.actionType === "new_task" && this.openInlineAdd(item)) {
      return
    }

    if (item.actionType === "agent") {
      this.switchToAgent()
      return
    }

    if (item.agentPrompt) {
      this.switchToAgent()
      this.sendAgentMessage(item.agentPrompt)
      return
    }

    if (item.href) {
      this.navigate(item.href)
    }
  }

  navigate(href) {
    this.close()
    if (window.Turbo?.visit) {
      window.Turbo.visit(href)
    } else {
      window.location.assign(href)
    }
  }

  openInlineAdd(item) {
    const boardId = Number(item.boardId || 0)
    if (!boardId || !this.hasCurrentBoardIdValue || boardId !== this.currentBoardIdValue) {
      return false
    }

    const addButton = document.querySelector("[data-controller~='inline-add'] [data-action='click->inline-add#show']")
    if (!addButton) {
      return false
    }

    this.close()
    addButton.click()
    return true
  }

  switchToAgent(e) {
    const prompt = e?.currentTarget?.dataset?.prompt || ""
    this.modeValue = "agent"
    this.messages = []
    this.typing = false
    this.results = []
    this.activeIndex = -1
    this.searchResultsTarget.classList.add("hidden")
    this.actionsPanelTarget.classList.add("hidden")
    this.agentPanelTarget.classList.remove("hidden")
    this.updateModeIcon()
    this.updateInputPlaceholder()

    if (this.hasBackButtonTarget) {
      this.backButtonTarget.classList.remove("hidden")
    }

    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.renderAgentPanel()

    if (prompt) {
      this.sendAgentMessage(prompt)
    }
  }

  switchToSearch() {
    this.inputTarget.value = ""
    this.showSearchMode()
    this.inputTarget.focus()
  }

  sendMessage() {
    const text = this.inputTarget.value.trim()
    if (!text) return

    this.inputTarget.value = ""
    this.sendAgentMessage(text)
  }

  sendAgentMessage(text) {
    this.messages.push({ type: "user", text })
    this.typing = true
    this.renderAgentPanel()
    this.scrollAgentToBottom()

    const messageType = this.detectMessageType(text)
    const body = messageType === "ask_agent"
      ? { message: text, message_type: "ask_agent" }
      : { message_type: messageType }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch("/agent/chat", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
      },
      body: JSON.stringify(body),
    })
      .then(res => {
        if (!res.ok) throw new Error("Request failed")
        return res.json()
      })
      .then(data => {
        this.typing = false
        this.messages.push({ type: "agent", text: data.response })
        this.renderAgentPanel()
        this.scrollAgentToBottom()
      })
      .catch(() => {
        this.typing = false
        this.messages.push({ type: "agent", text: "Something went wrong. Please try again." })
        this.renderAgentPanel()
        this.scrollAgentToBottom()
      })
  }

  detectMessageType(text) {
    const normalized = text.toLowerCase()
    if (normalized.includes("focus") || normalized === "what should i focus on?" || normalized === "what should i focus on today?") return "focus"
    if (normalized.includes("weekly recap") || normalized === "give me a weekly recap") return "weekly_recap"
    return "ask_agent"
  }

  renderAgentPanel() {
    if (!this.hasAgentMessagesTarget) return

    if (this.messages.length === 0 && !this.typing) {
      this.agentMessagesTarget.innerHTML = ""

      const container = document.createElement("div")
      container.className = "py-5 text-center"

      const emoji = document.createElement("div")
      emoji.className = "text-[28px] mb-2.5"
      emoji.textContent = "⌨️"
      container.appendChild(emoji)

      const title = document.createElement("div")
      title.className = "text-[13px] font-semibold text-[#666]"
      title.textContent = "Query your tasks"
      container.appendChild(title)

      const subtitle = document.createElement("div")
      subtitle.className = "text-[11px] font-medium text-[#444] mt-1"
      subtitle.textContent = "Ask about what is overdue, in progress, blocked, or get a summary."
      container.appendChild(subtitle)

      const chipContainer = document.createElement("div")
      chipContainer.className = "flex gap-[5px] justify-center mt-4 flex-wrap"

      const prompts = ["What should I focus on?", "Weekly recap"]
      prompts.forEach(q => {
        const button = document.createElement("button")
        button.dataset.action = "click->command-bar#chipSend"
        button.dataset.prompt = q
        button.className = "text-[11px] font-medium py-[5px] px-[11px] rounded-[7px] cursor-pointer text-[#999]"
        button.style.cssText = "background:rgba(251,191,36,0.06);border:1px solid rgba(251,191,36,0.10)"
        button.textContent = q
        chipContainer.appendChild(button)
      })

      container.appendChild(chipContainer)
      this.agentMessagesTarget.appendChild(container)
      return
    }

    this.agentMessagesTarget.innerHTML = ""
    const fragment = document.createDocumentFragment()

    this.messages.forEach(message => {
      const msgDiv = document.createElement("div")
      msgDiv.className = message.type === "user"
        ? "self-end max-w-[88%] whitespace-pre-wrap"
        : "self-start max-w-[88%] whitespace-pre-wrap"
      msgDiv.style.cssText = message.type === "user"
        ? "padding:9px 13px;border-radius:12px 12px 3px 12px;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.08);color:#ddd;font-size:12.5px;line-height:1.55"
        : "padding:9px 13px;border-radius:12px 12px 12px 3px;background:rgba(251,191,36,0.05);border:1px solid rgba(251,191,36,0.08);color:#bbb;font-size:12.5px;line-height:1.55"
      msgDiv.textContent = message.text
      fragment.appendChild(msgDiv)
    })

    if (this.typing) {
      const typingDiv = document.createElement("div")
      typingDiv.className = "self-start"
      typingDiv.style.cssText = "padding:9px 13px;border-radius:12px 12px 12px 3px;background:rgba(251,191,36,0.05);border:1px solid rgba(251,191,36,0.08);display:flex;align-items:center;gap:6px"

      const dotsContainer = document.createElement("div")
      dotsContainer.style.cssText = "display:flex;gap:3px"

      for (let i = 0; i < 3; i++) {
        const dot = document.createElement("div")
        dot.className = "cmd-dot"
        dot.style.cssText = `animation-delay:${i * 0.15}s`
        dotsContainer.appendChild(dot)
      }

      typingDiv.appendChild(dotsContainer)
      fragment.appendChild(typingDiv)
    }

    const anchor = document.createElement("div")
    anchor.dataset.commandBarTarget = "scrollAnchor"
    fragment.appendChild(anchor)

    this.agentMessagesTarget.appendChild(fragment)
  }

  chipSend(e) {
    const prompt = e.currentTarget.dataset.prompt
    if (prompt) this.sendAgentMessage(prompt)
  }

  scrollAgentToBottom() {
    requestAnimationFrame(() => {
      const anchor = this.agentMessagesTarget.querySelector("[data-command-bar-target='scrollAnchor']")
      if (anchor) anchor.scrollIntoView({ behavior: "smooth" })
    })
  }

  updateModeIcon() {
    if (!this.hasModeIconTarget) return

    if (this.modeValue === "agent") {
      this.modeIconTarget.innerHTML = `<span class="text-base">🤖</span>`
    } else {
      this.modeIconTarget.innerHTML = `<svg width="16" height="16" viewBox="0 0 16 16" fill="none" style="opacity:0.3"><circle cx="7" cy="7" r="5" stroke="#888" stroke-width="1.5"/><path d="M11 11L14 14" stroke="#888" stroke-width="1.5" stroke-linecap="round"/></svg>`
    }
  }

  updateInputPlaceholder() {
    this.inputTarget.placeholder = this.modeValue === "agent"
      ? "Ask about your tasks..."
      : "Jump to a task, board, or command..."
  }

  scoreItem(item, query) {
    const haystack = [item.title, item.subtitle, ...(item.keywords || [])].join(" ").toLowerCase()
    const title = (item.title || "").toLowerCase()

    if (title === query) return 120
    if (title.startsWith(query)) return 90
    if (haystack.includes(query)) return 60

    const terms = query.split(/\s+/).filter(Boolean)
    if (terms.length === 0) return 0

    const matchedTerms = terms.filter(term => haystack.includes(term)).length
    if (matchedTerms === terms.length) return 45 + matchedTerms
    if (matchedTerms > 0) return 20 + matchedTerms

    return 0
  }

  kindRank(kind) {
    return { action: 0, nav: 1, board: 2, task: 3 }[kind] ?? 99
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text || ""
    return div.innerHTML
  }

  createElement(tag, text, attributes = {}) {
    const el = document.createElement(tag)
    if (text) el.textContent = text
    for (const [key, value] of Object.entries(attributes)) {
      el.setAttribute(key, value)
    }
    return el
  }

  clearAndAppend(target, element) {
    target.innerHTML = ""
    target.appendChild(element)
  }
}
