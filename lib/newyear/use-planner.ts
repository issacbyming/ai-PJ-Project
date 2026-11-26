'use client'

import * as React from 'react'
import { getBackend } from './backend'
import type {
  Backend,
  DayId,
  Item,
  Kind,
  PlannerData,
  RemoteEvent,
  Slot
} from './types'

export interface ItemDraft {
  title: string
  kind: Kind
  who: string
  slotId: string | null
}

function newId(): string {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) {
    return crypto.randomUUID()
  }
  // 舊瀏覽器或非 https 環境的備援
  return '10000000-1000-4000-8000-100000000000'.replace(/[018]/g, c => {
    const n = Number(c)
    return (n ^ ((Math.random() * 16) >> (n / 4))).toString(16)
  })
}

const upsert = <T extends { id: string }>(list: T[], next: T) =>
  list.some(entry => entry.id === next.id)
    ? list.map(entry => (entry.id === next.id ? next : entry))
    : [...list, next]

function applyEvent(data: PlannerData, event: RemoteEvent): PlannerData {
  switch (event.type) {
    case 'item-upsert':
      return { ...data, items: upsert(data.items, event.item) }
    case 'item-delete':
      return { ...data, items: data.items.filter(i => i.id !== event.id) }
    case 'slot-upsert':
      return { ...data, slots: upsert(data.slots, event.slot) }
    case 'slot-delete':
      return {
        slots: data.slots.filter(s => s.id !== event.id),
        items: data.items.map(i =>
          i.slotId === event.id ? { ...i, slotId: null } : i
        )
      }
    default:
      return data
  }
}

const bySort = (a: { sort: number }, b: { sort: number }) => a.sort - b.sort

export function usePlanner() {
  const backendRef = React.useRef<Backend | null>(null)
  const [data, setData] = React.useState<PlannerData>({ slots: [], items: [] })
  const [ready, setReady] = React.useState(false)
  const [mode, setMode] = React.useState<'cloud' | 'local'>('cloud')
  const [error, setError] = React.useState<string | null>(null)

  const reload = React.useCallback(async () => {
    const backend = backendRef.current
    if (!backend) return
    try {
      setData(await backend.load())
      setReady(true)
    } catch {
      setError('讀不到資料，請檢查網路後重新整理')
    }
  }, [])

  React.useEffect(() => {
    const backend = getBackend()
    backendRef.current = backend
    setMode(backend.mode)
    reload()
    const unsubscribe = backend.subscribe(event => {
      if (event.type === 'reload') reload()
      else setData(current => applyEvent(current, event))
    })
    // 手機切回這個分頁時補抓一次
    const onVisible = () => {
      if (document.visibilityState === 'visible') reload()
    }
    document.addEventListener('visibilitychange', onVisible)
    return () => {
      unsubscribe()
      document.removeEventListener('visibilitychange', onVisible)
    }
  }, [reload])

  /** 先改畫面，再存；存失敗就提示並還原成伺服器上的樣子 */
  const commit = React.useCallback(
    (event: RemoteEvent, save: (backend: Backend) => Promise<void>) => {
      const backend = backendRef.current
      if (!backend) return
      setError(null)
      setData(current => applyEvent(current, event))
      save(backend).catch(() => {
        setError('剛剛那筆沒存成功，請再試一次')
        reload()
      })
    },
    [reload]
  )

  const addItem = React.useCallback(
    (draft: ItemDraft) => {
      const item: Item = { id: newId(), sort: Date.now(), ...draft }
      commit({ type: 'item-upsert', item }, b => b.saveItem(item))
    },
    [commit]
  )

  const updateItem = React.useCallback(
    (item: Item) => {
      commit({ type: 'item-upsert', item }, b => b.saveItem(item))
    },
    [commit]
  )

  const removeItem = React.useCallback(
    (id: string) => {
      commit({ type: 'item-delete', id }, b => b.removeItem(id))
    },
    [commit]
  )

  const addSlot = React.useCallback(
    (day: DayId, name: string) => {
      const last = data.slots
        .filter(slot => slot.day === day)
        .reduce((max, slot) => Math.max(max, slot.sort), 0)
      const slot: Slot = { id: newId(), day, name, sort: last + 1 }
      commit({ type: 'slot-upsert', slot }, b => b.saveSlots([slot]))
    },
    [commit, data.slots]
  )

  const renameSlot = React.useCallback(
    (slot: Slot, name: string) => {
      const next = { ...slot, name }
      commit({ type: 'slot-upsert', slot: next }, b => b.saveSlots([next]))
    },
    [commit]
  )

  /** 跟同一天的前一個／後一個時段交換位置 */
  const moveSlot = React.useCallback(
    (slot: Slot, direction: -1 | 1) => {
      const siblings = data.slots
        .filter(entry => entry.day === slot.day)
        .sort(bySort)
      const index = siblings.findIndex(entry => entry.id === slot.id)
      const other = siblings[index + direction]
      if (index < 0 || !other) return
      const a = { ...slot, sort: other.sort }
      const b = { ...other, sort: slot.sort }
      setError(null)
      setData(current =>
        applyEvent(applyEvent(current, { type: 'slot-upsert', slot: a }), {
          type: 'slot-upsert',
          slot: b
        })
      )
      backendRef.current?.saveSlots([a, b]).catch(() => {
        setError('剛剛那筆沒存成功，請再試一次')
        reload()
      })
    },
    [data.slots, reload]
  )

  const removeSlot = React.useCallback(
    (id: string) => {
      commit({ type: 'slot-delete', id }, b => b.removeSlot(id))
    },
    [commit]
  )

  const slotsByDay = React.useMemo(() => {
    const sorted = [...data.slots].sort(bySort)
    return {
      1: sorted.filter(slot => slot.day === 1),
      2: sorted.filter(slot => slot.day === 2)
    } as Record<DayId, Slot[]>
  }, [data.slots])

  const itemsBySlot = React.useMemo(() => {
    const map = new Map<string | null, Item[]>()
    const known = new Set(data.slots.map(slot => slot.id))
    for (const item of [...data.items].sort(bySort)) {
      // 時段被刪掉但項目還指著它時，當作在口袋裡
      const key = item.slotId && known.has(item.slotId) ? item.slotId : null
      map.set(key, [...(map.get(key) ?? []), item])
    }
    return map
  }, [data.items, data.slots])

  return {
    ready,
    mode,
    error,
    dismissError: () => setError(null),
    slotsByDay,
    itemsBySlot,
    addItem,
    updateItem,
    removeItem,
    addSlot,
    renameSlot,
    moveSlot,
    removeSlot
  }
}

export type Planner = ReturnType<typeof usePlanner>
