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
  /** 誰帶／誰負責，可以是空字串 */
  who: string
  /** null 代表還在口袋裡，沒排時段 */
  slotId: string | null
  sort: number
}

export interface PlannerData {
  slots: Slot[]
  items: Item[]
}

export type RemoteEvent =
  | { type: 'reload' }
  | { type: 'item-upsert'; item: Item }
  | { type: 'item-delete'; id: string }
  | { type: 'slot-upsert'; slot: Slot }
  | { type: 'slot-delete'; id: string }

export interface Backend {
  /** cloud：大家共用；local：只存在這台裝置的瀏覽器 */
  mode: 'cloud' | 'local'
  load(): Promise<PlannerData>
  subscribe(onEvent: (event: RemoteEvent) => void): () => void
  saveItem(item: Item): Promise<void>
  removeItem(id: string): Promise<void>
  saveSlots(slots: Slot[]): Promise<void>
  removeSlot(id: string): Promise<void>
}
