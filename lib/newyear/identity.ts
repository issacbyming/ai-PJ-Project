/* 沒有登入機制，所以每個瀏覽器自己產生一個代號，記在 localStorage：
   用來記「我按過哪些表情」「哪些留言是我寫的」，以及上次留言用的名字。 */

const CLIENT_KEY = 'newyear-client-id'
const NAME_KEY = 'newyear-name'

export function newId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
    return crypto.randomUUID()
  }
  // 舊瀏覽器或非 https 環境的備援
  return '10000000-1000-4000-8000-100000000000'.replace(/[018]/g, c => {
    const n = Number(c)
    return (n ^ ((Math.random() * 16) >> (n / 4))).toString(16)
  })
}

let fallbackClientId: string | null = null

export function getClientId(): string {
  try {
    const saved = window.localStorage.getItem(CLIENT_KEY)
    if (saved) return saved
    const created = newId()
    window.localStorage.setItem(CLIENT_KEY, created)
    return created
  } catch {
    // 瀏覽器不讓網站存資料時，這次開著的期間用同一個代號
    fallbackClientId = fallbackClientId ?? newId()
    return fallbackClientId
  }
}

export function getSavedName(): string {
  try {
    return window.localStorage.getItem(NAME_KEY) ?? ''
  } catch {
    return ''
  }
}

export function saveName(name: string) {
  try {
    window.localStorage.setItem(NAME_KEY, name)
  } catch {
    // 存不了就下次再打一次名字
  }
}
