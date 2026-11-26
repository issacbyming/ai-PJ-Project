import type { DayId, Kind, Slot } from './types'

/** 活動的固定文案，要改標題或日期改這裡就好 */
export const TRIP = {
  title: '從新坡到三星',
  years: '2026 → 2027',
  range: '12/31（四）– 1/2（六）',
  newYear: '2027'
}

export const DAYS: Record<
  DayId,
  { anchor: string; nav: string; date: string; heading: string }
> = {
  1: {
    anchor: 'day1',
    nav: '第一天 12/31',
    date: '12/31（四）跨到 1/1',
    heading: '第一天・新坡好宅'
  },
  2: {
    anchor: 'day2',
    nav: '宜蘭三星 1/1',
    date: '1/1（五）住到 1/2（六）',
    heading: '宜蘭三星・張宅'
  }
}

export const KINDS: Record<Kind, { label: string; short: string }> = {
  food: { label: '吃的', short: '吃' },
  play: { label: '玩的', short: '玩' },
  show: { label: '節目', short: '節' }
}

export const KIND_ORDER: Kind[] = ['food', 'play', 'show']

export const LIMITS = { title: 60, who: 20, slotName: 20 }

/** 還沒接雲端資料庫時用的預設時段（雲端版由 migration 建立同一組） */
export const DEFAULT_SLOTS: Slot[] = [
  { id: 'd1-afternoon', day: 1, name: '下午', sort: 1 },
  { id: 'd1-dinner', day: 1, name: '晚餐', sort: 2 },
  { id: 'd1-countdown', day: 1, name: '倒數前', sort: 3 },
  { id: 'd2-noon', day: 2, name: '中午', sort: 1 },
  { id: 'd2-afternoon', day: 2, name: '下午', sort: 2 },
  { id: 'd2-dinner', day: 2, name: '晚餐', sort: 3 },
  { id: 'd2-night', day: 2, name: '晚上', sort: 4 },
  { id: 'd2-morning', day: 2, name: '1/2 早上', sort: 5 }
]
