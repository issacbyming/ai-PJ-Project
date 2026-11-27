import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import { DEFAULT_SLOTS, REACTIONS } from './config'
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

/* ---------- 雲端：Supabase（大家共用、即時同步） ---------- */

interface SlotRow {
  id: string
  day: number
  name: string
  sort: number
}

interface ItemRow {
  id: string
  title: string
  kind: string
  who: string
  slot_id: string | null
  sort: number
}

const toSlot = (row: SlotRow): Slot => ({
  id: row.id,
  day: (row.day === 2 ? 2 : 1) as DayId,
  name: row.name,
  sort: Number(row.sort)
})

const toItem = (row: ItemRow): Item => ({
  id: row.id,
  title: row.title,
  kind: (['food', 'play', 'show'].includes(row.kind) ? row.kind : 'food') as Kind,
  who: row.who ?? '',
  slotId: row.slot_id,
  sort: Number(row.sort)
})

const fromItem = (item: Item): ItemRow => ({
  id: item.id,
  title: item.title,
  kind: item.kind,
  who: item.who,
  slot_id: item.slotId,
  sort: item.sort
})

interface CommentRow {
  id: string
  item_id: string
  who: string
  body: string
  client_id: string
  created_at: string
}

interface ReactionRow {
  item_id: string
  reaction: string
  client_id: string
}

const toComment = (row: CommentRow): Comment => ({
  id: row.id,
  itemId: row.item_id,
  who: row.who,
  body: row.body,
  clientId: row.client_id,
  createdAt: row.created_at
})

const fromComment = (comment: Comment): CommentRow => ({
  id: comment.id,
  item_id: comment.itemId,
  who: comment.who,
  body: comment.body,
  client_id: comment.clientId,
  created_at: comment.createdAt
})

const REACTION_KEYS = REACTIONS.map(entry => entry.key)

const toReaction = (row: ReactionRow): Reaction | null =>
  REACTION_KEYS.includes(row.reaction as ReactionKey)
    ? {
        itemId: row.item_id,
        reaction: row.reaction as ReactionKey,
        clientId: row.client_id
      }
    : null

const fromReaction = (reaction: Reaction): ReactionRow => ({
  item_id: reaction.itemId,
  reaction: reaction.reaction,
  client_id: reaction.clientId
})

// 沒有產生資料庫型別檔，所以用寬鬆型別，資料形狀由 toSlot / toItem 把關
type CloudClient = SupabaseClient<any, 'public', any>

function createCloudBackend(client: CloudClient): Backend {
  const check = (error: { message: string } | null) => {
    if (error) throw new Error(error.message)
  }

  return {
    mode: 'cloud',

    async load() {
      const [slots, items, comments, reactions] = await Promise.all([
        client.from('ny_slots').select('id, day, name, sort'),
        client.from('ny_items').select('id, title, kind, who, slot_id, sort'),
        client
          .from('ny_comments')
          .select('id, item_id, who, body, client_id, created_at'),
        client.from('ny_reactions').select('item_id, reaction, client_id')
      ])
      check(slots.error)
      check(items.error)
      check(comments.error)
      check(reactions.error)
      return {
        slots: (slots.data as SlotRow[]).map(toSlot),
        items: (items.data as ItemRow[]).map(toItem),
        comments: (comments.data as CommentRow[]).map(toComment),
        reactions: (reactions.data as ReactionRow[])
          .map(toReaction)
          .filter((entry): entry is Reaction => entry !== null)
      }
    },

    subscribe(onEvent) {
      let wasSubscribed = false
      const channel = client
        .channel('newyear-planner')
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'ny_items' },
          payload => {
            if (payload.eventType === 'DELETE') {
              onEvent({ type: 'item-delete', id: (payload.old as ItemRow).id })
            } else {
              onEvent({
                type: 'item-upsert',
                item: toItem(payload.new as ItemRow)
              })
            }
          }
        )
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'ny_slots' },
          payload => {
            if (payload.eventType === 'DELETE') {
              onEvent({ type: 'slot-delete', id: (payload.old as SlotRow).id })
            } else {
              onEvent({
                type: 'slot-upsert',
                slot: toSlot(payload.new as SlotRow)
              })
            }
          }
        )
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'ny_comments' },
          payload => {
            if (payload.eventType === 'DELETE') {
              onEvent({
                type: 'comment-delete',
                id: (payload.old as CommentRow).id
              })
            } else {
              onEvent({
                type: 'comment-upsert',
                comment: toComment(payload.new as CommentRow)
              })
            }
          }
        )
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'ny_reactions' },
          payload => {
            // 刪除時只拿得到主鍵（item_id、reaction、client_id），剛好夠用
            const row = (
              payload.eventType === 'DELETE' ? payload.old : payload.new
            ) as ReactionRow
            const reaction = toReaction(row)
            if (!reaction) return
            onEvent({
              type:
                payload.eventType === 'DELETE'
                  ? 'reaction-remove'
                  : 'reaction-add',
              reaction
            })
          }
        )
        .subscribe(status => {
          // 斷線重連後補抓一次，避免漏掉離線期間別人的編輯
          if (status === 'SUBSCRIBED') {
            if (wasSubscribed) onEvent({ type: 'reload' })
            wasSubscribed = true
          }
        })
      return () => {
        client.removeChannel(channel)
      }
    },

    async saveItem(item) {
      const { error } = await client.from('ny_items').upsert(fromItem(item))
      check(error)
    },

    async removeItem(id) {
      const { error } = await client.from('ny_items').delete().eq('id', id)
      check(error)
    },

    async saveSlots(slots) {
      const { error } = await client.from('ny_slots').upsert(slots)
      check(error)
    },

    async removeSlot(id) {
      // 資料庫的外鍵會把這個時段裡的項目放回口袋（slot_id 設為 null）
      const { error } = await client.from('ny_slots').delete().eq('id', id)
      check(error)
    },

    async addComment(comment) {
      const { error } = await client
        .from('ny_comments')
        .insert(fromComment(comment))
      check(error)
    },

    async removeComment(id) {
      const { error } = await client.from('ny_comments').delete().eq('id', id)
      check(error)
    },

    async addReaction(reaction) {
      // 連按兩下時第二次當作沒事
      const { error } = await client
        .from('ny_reactions')
        .upsert(fromReaction(reaction), {
          onConflict: 'item_id,reaction,client_id',
          ignoreDuplicates: true
        })
      check(error)
    },

    async removeReaction(reaction) {
      const { error } = await client
        .from('ny_reactions')
        .delete()
        .match(fromReaction(reaction))
      check(error)
    }
  }
}

const sameReaction = (a: Reaction, b: Reaction) =>
  a.itemId === b.itemId &&
  a.reaction === b.reaction &&
  a.clientId === b.clientId

/* ---------- 本機：localStorage（只存在這台裝置） ---------- */

const STORAGE_KEY = 'newyear-planner-v1'

function createLocalBackend(): Backend {
  const read = (): PlannerData => {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY)
      if (raw) {
        const parsed = JSON.parse(raw) as Partial<PlannerData>
        if (Array.isArray(parsed.slots) && Array.isArray(parsed.items)) {
          // 舊版存的資料沒有留言與表情
          return {
            slots: parsed.slots,
            items: parsed.items,
            comments: Array.isArray(parsed.comments) ? parsed.comments : [],
            reactions: Array.isArray(parsed.reactions) ? parsed.reactions : []
          }
        }
      }
    } catch {
      // 讀不到就當作第一次使用
    }
    return { slots: DEFAULT_SLOTS, items: [], comments: [], reactions: [] }
  }

  const write = (data: PlannerData) => {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(data))
    } catch {
      throw new Error('這台裝置的瀏覽器不讓網站存資料')
    }
  }

  const upsert = <T extends { id: string }>(list: T[], next: T) =>
    list.some(entry => entry.id === next.id)
      ? list.map(entry => (entry.id === next.id ? next : entry))
      : [...list, next]

  return {
    mode: 'local',

    async load() {
      return read()
    },

    subscribe(onEvent: (event: RemoteEvent) => void) {
      // 同一台裝置開了別的分頁時，跟著更新
      const onStorage = (event: StorageEvent) => {
        if (event.key === STORAGE_KEY) onEvent({ type: 'reload' })
      }
      window.addEventListener('storage', onStorage)
      return () => window.removeEventListener('storage', onStorage)
    },

    async saveItem(item) {
      const data = read()
      write({ ...data, items: upsert(data.items, item) })
    },

    async removeItem(id) {
      const data = read()
      // 和資料庫一樣，卡片刪掉時底下的留言與表情一起刪
      write({
        ...data,
        items: data.items.filter(item => item.id !== id),
        comments: data.comments.filter(comment => comment.itemId !== id),
        reactions: data.reactions.filter(reaction => reaction.itemId !== id)
      })
    },

    async saveSlots(slots) {
      const data = read()
      write({ ...data, slots: slots.reduce(upsert, data.slots) })
    },

    async removeSlot(id) {
      const data = read()
      write({
        ...data,
        slots: data.slots.filter(slot => slot.id !== id),
        items: data.items.map(item =>
          item.slotId === id ? { ...item, slotId: null } : item
        )
      })
    },

    async addComment(comment) {
      const data = read()
      write({ ...data, comments: upsert(data.comments, comment) })
    },

    async removeComment(id) {
      const data = read()
      write({
        ...data,
        comments: data.comments.filter(comment => comment.id !== id)
      })
    },

    async addReaction(reaction) {
      const data = read()
      if (data.reactions.some(entry => sameReaction(entry, reaction))) return
      write({ ...data, reactions: [...data.reactions, reaction] })
    },

    async removeReaction(reaction) {
      const data = read()
      write({
        ...data,
        reactions: data.reactions.filter(
          entry => !sameReaction(entry, reaction)
        )
      })
    }
  }
}

let cached: Backend | null = null

/** 有設定 Supabase 環境變數就用雲端，否則退回只存在本機 */
export function getBackend(): Backend {
  if (cached) return cached
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  cached =
    url && key
      ? createCloudBackend(
          createClient<any, 'public', any>(url, key, {
            auth: { persistSession: false }
          })
        )
      : createLocalBackend()
  return cached
}
