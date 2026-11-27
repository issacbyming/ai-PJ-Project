'use client'

import * as React from 'react'
import { cn } from '@/lib/utils'
import { KIND_ORDER, KINDS, LIMITS } from '@/lib/newyear/config'
import { getSavedName } from '@/lib/newyear/identity'
import type { Item, Kind } from '@/lib/newyear/types'
import type { Planner } from '@/lib/newyear/use-planner'
import { CardMeta, ItemDetail, confirmRemoveItem } from './item-detail'
import { ItemForm } from './item-form'
import { FOCUS, KIND_CHIP, KIND_TAG } from './styles'

interface PocketProps {
  items: Item[]
  planner: Planner
  expanded: boolean
  setExpanded: (expanded: boolean) => void
}

/** 畫面底部的「口袋」：還沒排時段的點子，兩天共用 */
export function Pocket({ items, planner, expanded, setExpanded }: PocketProps) {
  const [editingId, setEditingId] = React.useState<string | null>(null)
  const [detailId, setDetailId] = React.useState<string | null>(null)
  const [title, setTitle] = React.useState('')
  const [kind, setKind] = React.useState<Kind>('food')
  const panelId = React.useId()
  const inputId = React.useId()
  const editing = items.find(item => item.id === editingId) ?? null
  const detail = items.find(item => item.id === detailId) ?? null

  const close = () => {
    setExpanded(false)
    setEditingId(null)
    setDetailId(null)
  }

  React.useEffect(() => {
    if (!expanded) return
    const onKey = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setExpanded(false)
        setEditingId(null)
        setDetailId(null)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [expanded, setExpanded])

  const addToPocket = (event: React.FormEvent) => {
    event.preventDefault()
    const trimmed = title.trim()
    if (!trimmed) return
    // 提議者記成自己（留言時記住的名字），之後可以在「編輯」改
    planner.addItem({ title: trimmed, kind, who: getSavedName(), slotId: null })
    setTitle('')
  }

  return (
    <>
      {expanded && (
        <button
          type="button"
          aria-label="收起口袋"
          onClick={close}
          className="fixed inset-0 z-30 cursor-default bg-[#0C1030]/50"
        />
      )}

      <aside
        aria-label="口袋"
        className="fixed inset-x-0 bottom-0 z-40 mx-auto w-full max-w-[560px] rounded-t-[22px] bg-[#0C1030] pb-[env(safe-area-inset-bottom)] text-white shadow-[0_-8px_24px_rgba(12,16,48,0.28)]"
      >
        <button
          type="button"
          aria-expanded={expanded}
          aria-controls={panelId}
          onClick={() => (expanded ? close() : setExpanded(true))}
          className={cn(
            'flex h-14 w-full items-center gap-2 rounded-t-[22px] px-5 text-left',
            FOCUS
          )}
        >
          <span className="text-base font-extrabold">口袋</span>
          <span className="flex h-6 min-w-[24px] items-center justify-center rounded-full bg-[#FFC857] px-1.5 text-xs font-bold text-[#2A1A00]">
            {items.length}
          </span>
          <span className="min-w-0 flex-1 truncate text-[13px] text-[#B9BEE6]">
            還沒排時段的點子，兩天共用
          </span>
          <svg
            width="18"
            height="18"
            viewBox="0 0 18 18"
            aria-hidden="true"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className={cn('shrink-0', expanded && 'rotate-180')}
          >
            <path d="M4 11l5-5 5 5" />
          </svg>
        </button>

        {expanded && (
          <div
            id={panelId}
            data-scroll-box
            className="flex max-h-[70vh] flex-col gap-3.5 overflow-y-auto px-5 pb-5"
          >
            {editing ? (
              <ItemForm
                key={editing.id}
                initial={editing}
                slotsByDay={planner.slotsByDay}
                showSlot
                submitLabel="儲存"
                onSubmit={draft => {
                  planner.updateItem({ ...editing, ...draft })
                  setEditingId(null)
                }}
                onCancel={() => {
                  // 取消編輯就回到剛才的面板
                  setEditingId(null)
                  setDetailId(editing.id)
                }}
                onDelete={() => {
                  if (!confirmRemoveItem(editing, planner)) return
                  planner.removeItem(editing.id)
                  setEditingId(null)
                }}
              />
            ) : detail ? (
              <ItemDetail
                key={detail.id}
                item={detail}
                planner={planner}
                editLabel="編輯／排時段"
                onEdit={() => {
                  setDetailId(null)
                  setEditingId(detail.id)
                }}
                onClose={() => setDetailId(null)}
                onDelete={() => {
                  if (!confirmRemoveItem(detail, planner)) return
                  planner.removeItem(detail.id)
                  setDetailId(null)
                }}
              />
            ) : items.length > 0 ? (
              <ul className="flex flex-wrap gap-2">
                {items.map(item => (
                  <li key={item.id} className="max-w-full">
                    <button
                      type="button"
                      data-item-card={item.id}
                      onClick={() => setDetailId(item.id)}
                      className={cn(
                        'flex min-h-[44px] max-w-full items-center gap-1.5 rounded-[22px] py-1 pl-1.5 pr-3 text-left text-[#1F1A17]',
                        KIND_CHIP[item.kind],
                        FOCUS
                      )}
                    >
                      <span
                        className={cn(
                          'flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-xs font-extrabold',
                          KIND_TAG[item.kind]
                        )}
                      >
                        <span aria-hidden="true">{KINDS[item.kind].short}</span>
                        <span className="sr-only">{KINDS[item.kind].label}：</span>
                      </span>
                      <span className="flex min-w-0 flex-col">
                        <span className="break-words text-sm">
                          {item.title}
                        </span>
                        {/* 提議者與人數放在標題下一行，避免把標題擠窄 */}
                        <CardMeta
                          who={item.who}
                          reactions={planner.reactionsFor(item.id)}
                          commentCount={planner.commentsFor(item.id).length}
                          className="gap-x-2 text-[13px] text-[#4F4741]"
                        />
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-sm leading-6 text-[#B9BEE6]">
                口袋是空的。想到什麼先丟進來，之後再點它排到某個時段。
              </p>
            )}

            {!editing && !detail && (
              <form onSubmit={addToPocket} className="flex flex-col gap-2">
                <div role="group" aria-label="類型" className="flex gap-1.5">
                  {KIND_ORDER.map(option => {
                    const selected = kind === option
                    return (
                      <button
                        key={option}
                        type="button"
                        aria-pressed={selected}
                        onClick={() => setKind(option)}
                        className={cn(
                          'h-11 flex-1 rounded-[22px] border text-sm',
                          selected
                            ? cn('border-transparent font-bold', KIND_TAG[option])
                            : 'border-[#4A5290] text-[#F4F2FF]',
                          FOCUS
                        )}
                      >
                        {KINDS[option].label}
                      </button>
                    )
                  })}
                </div>
                <div className="flex gap-2">
                  <label htmlFor={inputId} className="sr-only">
                    新增點子
                  </label>
                  <input
                    id={inputId}
                    type="text"
                    autoComplete="off"
                    maxLength={LIMITS.title}
                    placeholder="想吃什麼？想玩什麼？"
                    value={title}
                    onChange={event => setTitle(event.target.value)}
                    className={cn(
                      'h-12 min-w-0 flex-1 rounded-3xl border border-[#4A5290] bg-[#1A2150] px-4 text-base text-white placeholder:text-[#B9BEE6]',
                      FOCUS
                    )}
                  />
                  <button
                    type="submit"
                    disabled={title.trim().length === 0}
                    className={cn(
                      'h-12 shrink-0 rounded-3xl bg-[#FFC857] px-4 text-[15px] font-extrabold text-[#2A1A00] disabled:bg-[#3A4175] disabled:text-[#B9BEE6]',
                      FOCUS
                    )}
                  >
                    丟進口袋
                  </button>
                </div>
              </form>
            )}
          </div>
        )}
      </aside>
    </>
  )
}
