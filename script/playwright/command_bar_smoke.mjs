import { pathToFileURL } from 'node:url'

const playwrightModulePath = process.env.CLAWDECK_PLAYWRIGHT_MODULE || '/home/niya/playwright/node_modules/playwright/index.js'
const playwrightPkg = await import(pathToFileURL(playwrightModulePath).href)
const { chromium } = playwrightPkg.default

const baseUrl = (process.env.CLAWDECK_BASE_URL || 'http://127.0.0.1:3000').replace(/\/$/, '')
const email = process.env.CLAWDECK_EMAIL || 'one@example.com'
const password = process.env.CLAWDECK_PASSWORD || 'password123'
const configuredBoardId = process.env.CLAWDECK_BOARD_ID || ''
const headless = !['0', 'false', 'no'].includes(String(process.env.CLAWDECK_HEADLESS || 'true').toLowerCase())

const selectors = {
  commandBarToggle: 'button[onclick*="command-bar:toggle"]',
  commandBarDialog: '[data-controller="command-bar"] [role="dialog"]',
  commandBarResult: '[data-command-bar-result-index]',
  inlineAddTextarea: '[data-inline-add-target="form"] textarea',
  newTaskTitleInput: 'input[name="task[name]"]',
}

function parseBoardId(url) {
  const match = url.match(/\/boards\/(\d+)/)
  return match?.[1] || null
}

function fail(message, details = {}) {
  return { ok: false, error: message, ...details }
}

async function login(page) {
  await page.goto(`${baseUrl}/session/new`, { waitUntil: 'networkidle' })

  const csrfToken = await page.evaluate(() => document.querySelector('meta[name="csrf-token"]')?.content)
  if (!csrfToken) {
    throw new Error('Missing CSRF token on sign-in page')
  }

  const response = await page.request.post(`${baseUrl}/session`, {
    form: {
      authenticity_token: csrfToken,
      email_address: email,
      password,
    },
    maxRedirects: 5,
  })

  if (!response.ok()) {
    throw new Error(`Login failed with HTTP ${response.status()}`)
  }

  return response.url()
}

async function detectBoardId(page, loginUrl) {
  if (configuredBoardId) return configuredBoardId

  const fromLogin = parseBoardId(loginUrl)
  if (fromLogin) return fromLogin

  await page.goto(`${baseUrl}/boards`, { waitUntil: 'networkidle' })
  const fromBoards = parseBoardId(page.url())
  if (fromBoards) return fromBoards

  throw new Error(`Could not determine board id from login URL (${loginUrl}) or /boards redirect (${page.url()})`)
}

async function openCommandBar(page) {
  const toggle = page.locator(selectors.commandBarToggle).first()
  await toggle.waitFor({ state: 'visible', timeout: 5000 })
  await toggle.click()

  const dialog = page.locator(selectors.commandBarDialog).first()
  await dialog.waitFor({ state: 'visible', timeout: 5000 })
}

async function chooseNewTask(page) {
  const result = page.locator(selectors.commandBarResult).filter({ hasText: /New task/i }).first()
  await result.waitFor({ state: 'visible', timeout: 5000 })
  await result.click()
}

async function run() {
  const browser = await chromium.launch({ headless })
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } })

  try {
    const loginUrl = await login(page)
    const boardId = await detectBoardId(page, loginUrl)
    const boardUrl = `${baseUrl}/boards/${boardId}`
    const homeUrl = `${baseUrl}/home`

    await page.goto(boardUrl, { waitUntil: 'networkidle' })
    const boardUrlBefore = page.url()
    await openCommandBar(page)
    await chooseNewTask(page)
    await page.waitForTimeout(600)

    const boardUrlAfter = page.url()
    const inlineAddVisible = await page.locator(selectors.inlineAddTextarea).first().isVisible().catch(() => false)

    await page.goto(homeUrl, { waitUntil: 'networkidle' })
    await openCommandBar(page)
    await chooseNewTask(page)
    await page.waitForLoadState('networkidle')
    await page.waitForURL(new RegExp(`/boards/${boardId}\\?new_task=1`), { timeout: 10000 })

    const homeNavigateUrl = page.url()
    const modalVisible = await page.locator(selectors.newTaskTitleInput).first().isVisible().catch(() => false)

    const result = {
      ok: boardUrlAfter === boardUrlBefore && inlineAddVisible && modalVisible,
      baseUrl,
      boardId,
      checks: {
        boardInlineAddStayedOnBoardUrl: boardUrlAfter === boardUrlBefore,
        boardInlineAddVisible: inlineAddVisible,
        homeNewTaskNavigatedToModalUrl: new RegExp(`/boards/${boardId}\\?new_task=1`).test(homeNavigateUrl),
        homeNewTaskModalVisible: modalVisible,
      },
      urls: {
        loginRedirect: loginUrl,
        boardInline: boardUrlAfter,
        homeNavigate: homeNavigateUrl,
      },
    }

    console.log(JSON.stringify(result, null, 2))
    await browser.close()
    process.exit(result.ok ? 0 : 1)
  } catch (error) {
    console.log(JSON.stringify(fail(String(error)), null, 2))
    await browser.close()
    process.exit(1)
  }
}

await run()
