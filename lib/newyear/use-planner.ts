'use client'

import * as React from 'react'
import { getBackend } from './backend'
import { REACTIONS } from './config'
import { getClientId, newId } from './identity'
import type {
  Backend,
  Comment,
  DayId,
  Item,
  Kind,
  PlannerData,
  Reaction,
  ReactionKey,
  RemoteEvent,
  Slot
} from './types'

export interface ItemDraft {
  title: string
  kind: Kind
  who: string
  slotId: string | null
}

/** 一張卡片的某個表情：幾個人按、我有沒有按 */
export interface ReactionSummary {
  key: ReactionKey
  emoji: string
  label: string
  count: number
  mine: boolean
}

const upsert = <T extends { id: string }>(list: T[], next: T) =>
  list.some(entry => entry.id === next.id)
    ? list.map(entry => (entry.id === next.id ? next : entry))
    : [...list, next]

const sameReaction = (a: Reaction, b: Reaction) =>
  a.itemId === b.itemId &&
  a.reaction === b.reaction &&
  a.clientId === b.clientId

function applyEvent(data: PlannerData, event: RemoteEvent): PlannerData {
  switch (event.type) {
    case 'item-upsert':
      return { ...data, items: upsert(data.items, event.item) }
    case 'item-delete':
      // 資料庫會把底下的留言與表情一起刪，畫面上也一起拿掉
      return {
        ...data,
        items: data.items.filter(i => i.id !== event.id),
        comments: data.comments.filter(c => c.itemId !== event.id),
        reactions: data.reactions.filter(r => r.itemId !== event.id)
      }
    case 'slot-upsert':
      return { ...data, slots: upsert(data.slots, event.slot) }
    case 'slot-delete':
      return {
        ...data,
        slots: data.slots.filter(s => s.id !== event.id),
        items: data.items.map(i =>
          i.slotId === event.id ? { ...i, slotId: null } : i
        )
      }
    case 'comment-upsert':
      return { ...data, comments: upsert(data.comments, event.comment) }
    case 'comment-delete':
      return {
        ...data,
        comments: data.comments.filter(c => c.id !== event.id)
      }
    case 'reaction-add':
      return data.reactions.some(r => sameReaction(r, event.reaction))
        ? data
        : { ...data, reactions: [...data.reactions, event.reaction] }
    case 'reaction-remove':
      return {
        ...data,
        reactions: data.reactions.filter(r => !sameReaction(r, event.reaction))
      }
    default:
      return data
  }
}

const bySort = (a: { sort: number }, b: { sort: number }) => a.sort - b.sort

export function usePlanner() {
  const backendRef = React.useRef<Backend | null>(null)
  const [data, setData] = React.useState<PlannerData>({
    slots: [],
    items: [],
    comments: [],
    reactions: []
  })
  const [ready, setReady] = React.useState(false)
  const [mode, setMode] = React.useState<'cloud' | 'local'>('cloud')
  const [error, setError] = React.useState<string | null>(null)
  const [clientId, setClientId] = React.useState('')

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
    setClientId(getClientId())
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

  /** 按一下加上表情，再按一下收回 */
  const toggleReaction = React.useCallback(
    (itemId: string, key: ReactionKey) => {
      if (!clientId) return
      const reaction: Reaction = { itemId, reaction: key, clientId }
      const already = data.reactions.some(r => sameReaction(r, reaction))
      if (already) {
        commit({ type: 'reaction-remove', reaction }, b =>
          b.removeReaction(reaction)
        )
      } else {
        commit({ type: 'reaction-add', reaction }, b => b.addReaction(reaction))
      }
    },
    [clientId, commit, data.reactions]
  )

  const addComment = React.useCallback(
    (itemId: string, who: string, body: string) => {
      if (!clientId) return
      const comment: Comment = {
        id: newId(),
        itemId,
        who,
        body,
        clientId,
        createdAt: new Date().toISOString()
      }
      commit({ type: 'comment-upsert', comment }, b => b.addComment(comment))
    },
    [clientId, commit]
  )

  const removeComment = React.useCallback(
    (id: string) => {
      commit({ type: 'comment-delete', id }, b => b.removeComment(id))
    },
    [commit]
  )

  /** 「復原」剛刪掉的留言：原封不動放回去 */
  const restoreComment = React.useCallback(
    (comment: Comment) => {
      commit({ type: 'comment-upsert', comment }, b => b.addComment(comment))
    },
    [commit]
  )

  const commentsByItem = React.useMemo(() => {
    const map = new Map<string, Comment[]>()
    const sorted = [...data.comments].sort((a, b) =>
      a.createdAt.localeCompare(b.createdAt)
    )
    for (const comment of sorted) {
      map.set(comment.itemId, [...(map.get(comment.itemId) ?? []), comment])
    }
    return map
  }, [data.comments])

  /** 每張卡片五種表情各自的人數；沒人按的也列出來，方便畫按鈕 */
  const reactionsByItem = React.useMemo(() => {
    const map = new Map<string, ReactionSummary[]>()
    for (const r of data.reactions) {
      const list =
        map.get(r.itemId) ??
        REACTIONS.map(entry => ({ ...entry, count: 0, mine: false }))
      const target = list.find(entry => entry.key === r.reaction)
      if (target) {
        target.count += 1
        if (r.clientId === clientId) target.mine = true
      }
      map.set(r.itemId, list)
    }
    return map
  }, [data.reactions, clientId])

  const reactionsFor = React.useCallback(
    (itemId: string): ReactionSummary[] =>
      reactionsByItem.get(itemId) ??
      REACTIONS.map(entry => ({ ...entry, count: 0, mine: false })),
    [reactionsByItem]
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
    removeSlot,
    clientId,
    toggleReaction,
    reactionsFor,
    commentsFor: (itemId: string) => commentsByItem.get(itemId) ?? [],
    addComment,
    removeComment,
    restoreComment
  }
}

export type Planner = ReturnType<typeof usePlanner>
