export type Kind = 'food' | 'play' | 'show'

export type DayId = 1 | 2

export interface Slot {
  id: string
  day: DayId
  name: string
  sort: number
}

export interface Item {
  id: string
  title: string
  kind: Kind
  /** 提議者（誰的點子），可以是空字串。資料庫欄位沿用 who */
  who: string
  /** null 代表還在口袋裡，沒排時段 */
  slotId: string | null
  sort: number
}

/** 卡片上可以按的表情（存進資料庫的是英文代號，畫面上顯示的符號在 config.ts） */
export type ReactionKey = 'like' | 'love' | 'haha' | 'yum' | 'hmm'

export interface Comment {
  id: string
  itemId: string
  who: string
  body: string
  /** 寫這則留言的瀏覽器，用來決定能不能刪 */
  clientId: string
  createdAt: string
}

export interface Reaction {
  itemId: string
  reaction: ReactionKey
  /** 按這個表情的瀏覽器；同一個瀏覽器對同一張卡片的同一種表情只算一次 */
  clientId: string
}

export interface PlannerData {
  slots: Slot[]
  items: Item[]
  comments: Comment[]
  reactions: Reaction[]
}

export type RemoteEvent =
  | { type: 'reload' }
  | { type: 'item-upsert'; item: Item }
  | { type: 'item-delete'; id: string }
  | { type: 'slot-upsert'; slot: Slot }
  | { type: 'slot-delete'; id: string }
  | { type: 'comment-upsert'; comment: Comment }
  | { type: 'comment-delete'; id: string }
  | { type: 'reaction-add'; reaction: Reaction }
  | { type: 'reaction-remove'; reaction: Reaction }

export interface Backend {
  /** cloud：大家共用；local：只存在這台裝置的瀏覽器 */
  mode: 'cloud' | 'local'
  load(): Promise<PlannerData>
  subscribe(onEvent: (event: RemoteEvent) => void): () => void
  saveItem(item: Item): Promise<void>
  removeItem(id: string): Promise<void>
  saveSlots(slots: Slot[]): Promise<void>
  removeSlot(id: string): Promise<void>
  addComment(comment: Comment): Promise<void>
  removeComment(id: string): Promise<void>
  addReaction(reaction: Reaction): Promise<void>
  removeReaction(reaction: Reaction): Promise<void>
}
