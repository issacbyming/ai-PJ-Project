'use client'

import * as React from 'react'
import { cn } from '@/lib/utils'
import { KINDS, LIMITS } from '@/lib/newyear/config'
import type { DayId, Item, Slot } from '@/lib/newyear/types'
import type { Planner } from '@/lib/newyear/use-planner'
import { ItemDetail, ReactionLine } from './item-detail'
import { ItemForm, useRevealOnMount } from './item-form'
import { FOCUS, KIND_TAG, TONE, type Tone } from './styles'

/** 整頁同一時間只會打開一個表單 */
export type OpenPanel =
  | { type: 'add'; slotId: string }
  | { type: 'detail'; itemId: string }
  | { type: 'edit'; itemId: string }
  | { type: 'slot'; slotId: string }
  | { type: 'new-slot'; day: DayId }
  | null

interface SlotSectionProps {
  slot: Slot
  items: Item[]
  tone: Tone
  planner: Planner
  open: OpenPanel
  setOpen: (open: OpenPanel) => void
  isFirst: boolean
  isLast: boolean
}

export function SlotSection({
  slot,
  items,
  tone,
  planner,
  open,
  setOpen,
  isFirst,
  isLast
}: SlotSectionProps) {
  const t = TONE[tone]
  const editingSlot = open?.type === 'slot' && open.slotId === slot.id
  const adding = open?.type === 'add' && open.slotId === slot.id

  return (
    <section className="flex gap-3">
      <div aria-hidden="true" className="flex w-3.5 shrink-0 flex-col items-center">
        <span className={cn('mt-[17px] h-2.5 w-2.5 shrink-0 rounded-full', t.dot)} />
        <span className={cn('w-0.5 flex-1', t.rail)} />
      </div>

      <div className="flex min-w-0 flex-1 flex-col pb-6">
        {editingSlot ? (
          <SlotNameForm
            initial={slot.name}
            submitLabel="儲存"
            onSubmit={name => {
              planner.renameSlot(slot, name)
              setOpen(null)
            }}
            onCancel={() => setOpen(null)}
            extra={
              <>
                <button
                  type="button"
                  disabled={isFirst}
                  onClick={() => planner.moveSlot(slot, -1)}
                  className={cn(SLOT_ACTION, FOCUS)}
                >
                  往前移
                </button>
                <button
                  type="button"
                  disabled={isLast}
                  onClick={() => planner.moveSlot(slot, 1)}
                  className={cn(SLOT_ACTION, FOCUS)}
                >
                  往後移
                </button>
                <button
                  type="button"
                  onClick={() => {
                    const message =
                      items.length > 0
                        ? `刪除「${slot.name}」？裡面的 ${items.length} 樣東西會回到口袋。`
                        : `刪除「${slot.name}」這個時段？`
                    if (window.confirm(message)) {
                      planner.removeSlot(slot.id)
                      setOpen(null)
                    }
                  }}
                  className={cn(SLOT_ACTION, 'text-[#A32018]', FOCUS)}
                >
                  刪除時段
                </button>
              </>
            }
          />
        ) : (
          <div className="flex h-11 items-center justify-between">
            <h3 className="text-[17px] font-bold">{slot.name}</h3>
            <button
              type="button"
              aria-label={`編輯時段「${slot.name}」`}
              onClick={() => setOpen({ type: 'slot', slotId: slot.id })}
              className={cn(
                '-mr-2 flex h-11 w-11 items-center justify-center rounded-full',
                t.sub,
                FOCUS
              )}
            >
              <PencilIcon />
            </button>
          </div>
        )}

        <div className="mt-1 flex flex-col gap-1.5">
          {items.map(item =>
            open?.type === 'edit' && open.itemId === item.id ? (
              <ItemForm
                key={item.id}
                initial={item}
                slotsByDay={planner.slotsByDay}
                showSlot
                submitLabel="儲存"
                onSubmit={draft => {
                  planner.updateItem({ ...item, ...draft })
                  setOpen(null)
                }}
                onCancel={() => setOpen(null)}
                onDelete={() => {
                  planner.removeItem(item.id)
                  setOpen(null)
                }}
              />
            ) : open?.type === 'detail' && open.itemId === item.id ? (
              <ItemDetail
                key={item.id}
                item={item}
                planner={planner}
                onEdit={() => setOpen({ type: 'edit', itemId: item.id })}
                onClose={() => setOpen(null)}
              />
            ) : (
              <button
                key={item.id}
                type="button"
                onClick={() => setOpen({ type: 'detail', itemId: item.id })}
                className={cn(
                  'flex min-h-[52px] items-center gap-2.5 rounded-xl px-3 py-2 text-left',
                  t.row,
                  FOCUS
                )}
              >
                <span
                  className={cn(
                    'flex h-[26px] w-10 shrink-0 items-center justify-center rounded-md text-xs font-bold',
                    KIND_TAG[item.kind]
                  )}
                >
                  {KINDS[item.kind].label}
                </span>
                <span className="flex min-w-0 flex-1 flex-col">
                  <span className="break-words text-[15px]">{item.title}</span>
                  <ReactionLine
                    reactions={planner.reactionsFor(item.id)}
                    commentCount={planner.commentsFor(item.id).length}
                    className={cn('mt-0.5', t.sub)}
                  />
                </span>
                {item.who ? (
                  <span className={cn('max-w-[40%] shrink-0 truncate text-[13px]', t.sub)}>
                    {item.who}
                  </span>
                ) : (
                  <span
                    className={cn(
                      'flex h-7 shrink-0 items-center rounded-full border border-dashed px-2.5 text-[13px]',
                      t.unclaimed
                    )}
                  >
                    {item.kind === 'show' ? '誰負責？' : '誰帶？'}
                  </span>
                )}
              </button>
            )
          )}

          {adding ? (
            <ItemForm
              initial={{ title: '', kind: 'food', who: '', slotId: slot.id }}
              slotsByDay={planner.slotsByDay}
              submitLabel={`加到「${slot.name}」`}
              onSubmit={draft => {
                planner.addItem(draft)
                setOpen(null)
              }}
              onCancel={() => setOpen(null)}
            />
          ) : (
            <button
              type="button"
              onClick={() => setOpen({ type: 'add', slotId: slot.id })}
              className={cn(
                'h-11 rounded-xl border border-dashed text-sm',
                t.dashed,
                FOCUS
              )}
            >
              ＋ 加在「{slot.name}」
            </button>
          )}
        </div>
      </div>
    </section>
  )
}

const SLOT_ACTION =
  'h-11 rounded-[10px] px-2.5 text-sm text-[#12301F] disabled:text-[#9AA89E]'

interface SlotNameFormProps {
  initial: string
  submitLabel: string
  onSubmit: (name: string) => void
  onCancel: () => void
  extra?: React.ReactNode
}

/** 新增時段、或改時段名稱用的小表單 */
export function SlotNameForm({
  initial,
  submitLabel,
  onSubmit,
  onCancel,
  extra
}: SlotNameFormProps) {
  const [name, setName] = React.useState(initial)
  const inputId = React.useId()
  const canSubmit = name.trim().length > 0
  const formRef = useRevealOnMount()

  return (
    <form
      ref={formRef}
      onSubmit={event => {
        event.preventDefault()
        if (canSubmit) onSubmit(name.trim())
      }}
      className="flex scroll-mb-24 scroll-mt-4 flex-col gap-2 rounded-[14px] border-2 border-[#1F7A4D] bg-white p-3.5 text-[#12301F]"
    >
      <label htmlFor={inputId} className="sr-only">
        時段名稱
      </label>
      <input
        id={inputId}
        type="text"
        autoFocus
        autoComplete="off"
        maxLength={LIMITS.slotName}
        placeholder="時段名稱，例如：宵夜"
        value={name}
        onChange={event => setName(event.target.value)}
        className={cn(
          'h-12 w-full rounded-[10px] border border-[#8FAE98] bg-white px-3 text-base placeholder:text-[#5D7566]',
          FOCUS
        )}
      />
      {extra && <div className="flex flex-wrap gap-x-1">{extra}</div>}
      <div className="flex justify-end gap-2">
        <button
          type="button"
          onClick={onCancel}
          className={cn('h-11 rounded-[10px] px-4 text-[15px] text-[#4A6353]', FOCUS)}
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

function PencilIcon() {
  return (
    <svg
      width="16"
      height="16"
      viewBox="0 0 16 16"
      aria-hidden="true"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M10.5 2.5l3 3L5.5 13.5l-3.5.5.5-3.5z" />
    </svg>
  )
}
