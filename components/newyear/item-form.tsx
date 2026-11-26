'use client'

import * as React from 'react'
import { cn } from '@/lib/utils'
import { DAYS, KIND_ORDER, KINDS, LIMITS } from '@/lib/newyear/config'
import type { DayId, Slot } from '@/lib/newyear/types'
import type { ItemDraft } from '@/lib/newyear/use-planner'
import { FOCUS } from './styles'

const POCKET_VALUE = '__pocket__'

const FIELD =
  'h-12 w-full rounded-[10px] border border-[#8FAE98] bg-white px-3 text-base text-[#12301F] placeholder:text-[#5D7566]'

interface ItemFormProps {
  initial: ItemDraft
  slotsByDay: Record<DayId, Slot[]>
  /** 顯示「排在哪個時段」的選單（編輯既有項目、或從口袋排時段時用） */
  showSlot?: boolean
  submitLabel: string
  onSubmit: (draft: ItemDraft) => void
  onCancel: () => void
  onDelete?: () => void
}

export function ItemForm({
  initial,
  slotsByDay,
  showSlot = false,
  submitLabel,
  onSubmit,
  onCancel,
  onDelete
}: ItemFormProps) {
  const [draft, setDraft] = React.useState<ItemDraft>(initial)
  const titleId = React.useId()
  const whoId = React.useId()
  const slotId = React.useId()
  const canSubmit = draft.title.trim().length > 0
  const formRef = useRevealOnMount()

  const submit = (event: React.FormEvent) => {
    event.preventDefault()
    if (!canSubmit) return
    onSubmit({
      ...draft,
      title: draft.title.trim(),
      who: draft.who.trim()
    })
  }

  return (
    <form
      ref={formRef}
      onSubmit={submit}
      className="flex scroll-mb-24 scroll-mt-4 flex-col gap-2.5 rounded-[14px] border-2 border-[#1F7A4D] bg-white p-3.5 text-[#12301F]"
    >
      <label htmlFor={titleId} className="sr-only">
        要帶什麼、做什麼
      </label>
      <input
        id={titleId}
        type="text"
        autoFocus
        autoComplete="off"
        maxLength={LIMITS.title}
        placeholder="要帶什麼、做什麼？"
        value={draft.title}
        onChange={event => setDraft({ ...draft, title: event.target.value })}
        className={cn(FIELD, FOCUS)}
      />

      <div role="group" aria-label="類型" className="flex gap-1.5">
        {KIND_ORDER.map(kind => {
          const selected = draft.kind === kind
          return (
            <button
              key={kind}
              type="button"
              aria-pressed={selected}
              onClick={() => setDraft({ ...draft, kind })}
              className={cn(
                'h-11 flex-1 rounded-[10px] border text-sm',
                selected
                  ? 'border-[#12301F] bg-[#12301F] font-bold text-white'
                  : 'border-[#8FAE98] bg-white text-[#12301F]',
                FOCUS
              )}
            >
              {KINDS[kind].label}
            </button>
          )
        })}
      </div>

      <label htmlFor={whoId} className="sr-only">
        {draft.kind === 'show' ? '誰負責' : '誰帶'}
      </label>
      <input
        id={whoId}
        type="text"
        autoComplete="off"
        maxLength={LIMITS.who}
        placeholder={
          draft.kind === 'show'
            ? '誰負責？（可以先空著）'
            : '誰帶？（可以先空著）'
        }
        value={draft.who}
        onChange={event => setDraft({ ...draft, who: event.target.value })}
        className={cn(FIELD, FOCUS)}
      />

      {showSlot && (
        <div className="flex items-center gap-2">
          <label htmlFor={slotId} className="shrink-0 text-sm text-[#4A6353]">
            排在
          </label>
          <select
            id={slotId}
            value={draft.slotId ?? POCKET_VALUE}
            onChange={event =>
              setDraft({
                ...draft,
                slotId:
                  event.target.value === POCKET_VALUE
                    ? null
                    : event.target.value
              })
            }
            className={cn(FIELD, FOCUS)}
          >
            <option value={POCKET_VALUE}>口袋（先不排時段）</option>
            {([1, 2] as DayId[]).map(day => (
              <optgroup key={day} label={DAYS[day].heading}>
                {slotsByDay[day].map(slot => (
                  <option key={slot.id} value={slot.id}>
                    {slot.name}
                  </option>
                ))}
              </optgroup>
            ))}
          </select>
        </div>
      )}

      <div className="mt-0.5 flex items-center gap-2">
        {onDelete && (
          <button
            type="button"
            onClick={onDelete}
            className={cn(
              'h-11 rounded-[10px] px-3 text-[15px] text-[#A32018]',
              FOCUS
            )}
          >
            刪除
          </button>
        )}
        <button
          type="button"
          onClick={onCancel}
          className={cn(
            'ml-auto h-11 rounded-[10px] px-4 text-[15px] text-[#4A6353]',
            FOCUS
          )}
        >
          取消
        </button>
        <button
          type="submit"
          disabled={!canSubmit}
          className={cn(
            'h-11 rounded-[10px] bg-[#1F7A4D] px-5 text-[15px] font-bold text-white disabled:bg-[#C9D6CC] disabled:text-[#4A6353]',
            FOCUS
          )}
        >
          {submitLabel}
        </button>
      </div>
    </form>
  )
}

/** 表單打開時捲到看得到的位置，避免被底部的口袋擋住 */
export function useRevealOnMount() {
  const ref = React.useRef<HTMLFormElement>(null)
  React.useEffect(() => {
    ref.current?.scrollIntoView({ block: 'nearest' })
  }, [])
  return ref
}
