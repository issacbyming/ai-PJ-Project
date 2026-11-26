import type { Kind } from '@/lib/newyear/types'

/** night：第一天的夜色區塊；day：宜蘭的白天區塊 */
export type Tone = 'night' | 'day'

export const FOCUS =
  'focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-current'

export const TONE: Record<
  Tone,
  {
    row: string
    sub: string
    dashed: string
    rail: string
    dot: string
    unclaimed: string
  }
> = {
  night: {
    row: 'bg-[#1A2150] text-[#F4F2FF]',
    sub: 'text-[#B9BEE6]',
    dashed: 'border-[#4A5290] text-[#B9BEE6]',
    rail: 'bg-[#2A3270]',
    dot: 'bg-[#FFC857]',
    unclaimed: 'border-[#FFC857] text-[#FFC857]'
  },
  day: {
    row: 'border border-[#D5E0D3] bg-white text-[#12301F]',
    sub: 'text-[#4A6353]',
    dashed: 'border-[#8FAE98] text-[#4A6353]',
    rail: 'bg-[#B7CDBD]',
    dot: 'bg-[#1F7A4D]',
    unclaimed: 'border-[#1F7A4D] text-[#17603C]'
  }
}

/** 類型標籤（實心）與口袋小卡（淡底）的顏色 */
export const KIND_TAG: Record<Kind, string> = {
  food: 'bg-[#FFC857] text-[#2A1A00]',
  play: 'bg-[#7CC6FF] text-[#04233D]',
  show: 'bg-[#FF9EBB] text-[#3D0A1C]'
}

export const KIND_CHIP: Record<Kind, string> = {
  food: 'bg-[#FFEFC9]',
  play: 'bg-[#DDEFFF]',
  show: 'bg-[#FFE1EA]'
}
