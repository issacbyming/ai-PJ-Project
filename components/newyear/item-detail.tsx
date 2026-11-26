'use client'

import * as React from 'react'
import { cn } from '@/lib/utils'
import { KINDS, LIMITS, REACTIONS } from '@/lib/newyear/config'
import { getSavedName, saveName } from '@/lib/newyear/identity'
import type { Comment, Item } from '@/lib/newyear/types'
import type { Planner, ReactionSummary } from '@/lib/newyear/use-planner'
import { FOCUS, KIND_TAG } from './styles'

const FIELD =
  'h-11 w-full rounded-[10px] border bg-white px-3 text-base text-[#12301F] placeholder:text-[#5D7566]'

/** 留言超過這個數量時，先只顯示最新的幾則 */
const SHOW_LATEST = 3

/** 刪掉留言後，「復原」按鈕留多久（毫秒） */
const UNDO_MS = 5000

interface ItemDetailProps {
  item: Item
  planner: Planner
  /** 「編輯」按鈕的字（口袋裡的卡片寫「編輯／排時段」） */
  editLabel?: string
  onEdit: () => void
  onClose: () => void
}

/** 點開一張卡片：按表情、看留言、寫留言，或進去編輯 */
export function ItemDetail({
  item,
  planner,
  editLabel = '編輯',
  onEdit,
  onClose
}: ItemDetailProps) {
  const reactions = planner.reactionsFor(item.id)
  const comments = planner.commentsFor(item.id)
  const [name, setName] = React.useState('')
  const [nameMissing, setNameMissing] = React.useState(false)
  const [body, setBody] = React.useState('')
  const [showAll, setShowAll] = React.useState(false)
  const [undo, setUndo] = React.useState<Comment | null>(null)
  const undoTimer = React.useRef<number>()
  const nameRef = React.useRef<HTMLInputElement>(null)
  const ref = React.useRef<HTMLDivElement>(null)
  const nameId = React.useId()
  const nameHintId = React.useId()
  const bodyId = React.useId()

  React.useEffect(() => {
    setName(getSavedName())
  }, [])

  // 打開時，面板頂端不在眼前（例如從另一張卡片切過來）就捲到頂端
  React.useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      const el = ref.current
      if (!el) return
      const box = el.closest<HTMLElement>('[data-scroll-box]')
      const bounds = box
        ? box.getBoundingClientRect()
        : { top: 0, bottom: window.innerHeight }
      const top = el.getBoundingClientRect().top
      if (
        top < bounds.top ||
        top > bounds.top + (bounds.bottom - bounds.top) * 0.6
      ) {
        el.scrollIntoView({ block: 'start' })
      }
    })
    return () => window.cancelAnimationFrame(frame)
  }, [])

  React.useEffect(() => () => window.clearTimeout(undoTimer.current), [])

  const close = () => {
    onClose()
    // 收起後把游標放回這張卡片，不要跳回頁首
    window.setTimeout(() => {
      document
        .querySelector<HTMLElement>(`[data-item-card="${item.id}"]`)
        ?.focus()
    }, 0)
  }

  const send = (event: React.FormEvent) => {
    event.preventDefault()
    if (!body.trim()) return
    const who = name.trim()
    if (!who) {
      setNameMissing(true)
      nameRef.current?.focus()
      return
    }
    saveName(who)
    planner.addComment(item.id, who, body.trim())
    setBody('')
  }

  const remove = (comment: Comment) => {
    planner.removeComment(comment.id)
    setUndo(comment)
    window.clearTimeout(undoTimer.current)
    undoTimer.current = window.setTimeout(() => setUndo(null), UNDO_MS)
  }

  const restore = () => {
    if (!undo) return
    planner.restoreComment(undo)
    window.clearTimeout(undoTimer.current)
    setUndo(null)
  }

  // 剛刪掉的那則留在原位，顯示「復原」
  const listed =
    undo && undo.itemId === item.id && !comments.some(c => c.id === undo.id)
      ? [...comments, undo].sort((a, b) =>
          a.createdAt.localeCompare(b.createdAt)
        )
      : comments
  const hiddenCount = showAll ? 0 : Math.max(0, listed.length - SHOW_LATEST)
  const visible = listed.slice(hiddenCount)

  return (
    <div
      ref={ref}
      onKeyDown={event => {
        if (event.key === 'Escape') {
          event.stopPropagation()
          close()
        }
      }}
      className="flex scroll-mb-24 scroll-mt-4 flex-col gap-3 rounded-[14px] border-2 border-[#1F7A4D] bg-white p-3.5 text-[#12301F]"
    >
      <div className="flex items-start gap-2.5">
        <span
          className={cn(
            'mt-0.5 flex h-[26px] w-10 shrink-0 items-center justify-center rounded-md text-xs font-bold',
            KIND_TAG[item.kind]
          )}
        >
          {KINDS[item.kind].label}
        </span>
        <p className="min-w-0 flex-1 break-words text-base font-bold leading-6">
          {item.title}
        </p>
        {item.who && (
          <span className="mt-0.5 max-w-[35%] shrink-0 truncate text-[13px] text-[#4A6353]">
            {item.who}
          </span>
        )}
      </div>

      <div className="flex flex-col gap-1.5">
        <div role="group" aria-label="按表情" className="flex flex-wrap gap-1">
          {reactions.map(reaction => (
            <ReactionButton
              key={reaction.key}
              reaction={reaction}
              onToggle={() => planner.toggleReaction(item.id, reaction.key)}
            />
          ))}
        </div>
        <p aria-hidden="true" className="text-[13px] leading-5 text-[#4A6353]">
          {REACTIONS.map(entry => `${entry.emoji}${entry.label}`).join('　')}
        </p>
      </div>

      <div className="flex flex-col gap-2 border-t border-[#D5E0D3] pt-3">
        <h4 className="text-sm font-bold">
          留言{comments.length > 0 && `（${comments.length}）`}
        </h4>

        {hiddenCount > 0 && (
          <button
            type="button"
            onClick={() => setShowAll(true)}
            className={cn(
              'h-11 rounded-[10px] text-left text-sm font-bold text-[#17603C] underline underline-offset-4',
              FOCUS
            )}
          >
            看全部 {listed.length} 則留言
          </button>
        )}

        {visible.length > 0 ? (
          <ul className="flex flex-col gap-2">
            {visible.map(comment =>
              undo && comment.id === undo.id ? (
                <li
                  key={comment.id}
                  className="flex min-h-[44px] items-center gap-2 rounded-[10px] border border-dashed border-[#8FAE98] px-3 text-sm text-[#4A6353]"
                >
                  <span className="flex-1">已刪除你的留言</span>
                  <button
                    type="button"
                    onClick={restore}
                    className={cn(
                      '-mr-1 h-11 min-w-[44px] shrink-0 rounded-lg px-2 text-sm font-bold text-[#17603C]',
                      FOCUS
                    )}
                  >
                    復原
                  </button>
                </li>
              ) : (
                <li
                  key={comment.id}
                  className="rounded-[10px] bg-[#F2F6F1] px-3 py-2 text-[15px] leading-[22px]"
                >
                  <div className="flex items-center gap-2">
                    <span className="min-w-0 truncate font-bold">
                      {comment.who}
                    </span>
                    <span className="shrink-0 text-xs text-[#5D7566]">
                      {formatTime(comment.createdAt)}
                    </span>
                    {comment.clientId === planner.clientId && (
                      <button
                        type="button"
                        onClick={() => remove(comment)}
                        aria-label={`刪除我的留言：${comment.body}`}
                        className={cn(
                          '-my-2.5 -mr-2 ml-auto h-11 min-w-[44px] shrink-0 rounded-lg px-2 text-sm text-[#A32018]',
                          FOCUS
                        )}
                      >
                        刪除
                      </button>
                    )}
                  </div>
                  <p className="whitespace-pre-wrap break-words">
                    {comment.body}
                  </p>
                </li>
              )
            )}
          </ul>
        ) : (
          <p className="text-sm text-[#4A6353]">
            還沒有人留言，說說你的想法吧。
          </p>
        )}

        <form onSubmit={send} className="flex flex-col gap-2">
          <label htmlFor={nameId} className="sr-only">
            你的名字
          </label>
          <input
            ref={nameRef}
            id={nameId}
            type="text"
            autoComplete="nickname"
            maxLength={LIMITS.who}
            placeholder="你的名字"
            value={name}
            aria-invalid={nameMissing}
            aria-describedby={nameMissing ? nameHintId : undefined}
            onChange={event => {
              setName(event.target.value)
              if (event.target.value.trim()) setNameMissing(false)
            }}
            className={cn(
              FIELD,
              nameMissing ? 'border-2 border-[#A32018]' : 'border-[#8FAE98]',
              FOCUS
            )}
          />
          {nameMissing && (
            <p
              id={nameHintId}
              role="alert"
              className="-mt-1 text-sm text-[#A32018]"
            >
              先寫名字，大家才知道是誰說的
            </p>
          )}
          <div className="flex gap-2">
            <label htmlFor={bodyId} className="sr-only">
              留言內容
            </label>
            <input
              id={bodyId}
              type="text"
              autoComplete="off"
              maxLength={LIMITS.comment}
              placeholder="想說什麼？"
              value={body}
              onChange={event => setBody(event.target.value)}
              className={cn(FIELD, 'min-w-0 flex-1 border-[#8FAE98]', FOCUS)}
            />
            <button
              type="submit"
              disabled={body.trim().length === 0}
              className={cn(
                'h-11 shrink-0 rounded-[10px] bg-[#1F7A4D] px-4 text-[15px] font-bold text-white disabled:bg-[#C9D6CC] disabled:text-[#4A6353]',
                FOCUS
              )}
            >
              送出
            </button>
          </div>
        </form>
      </div>

      <div className="flex items-center gap-2 border-t border-[#D5E0D3] pt-2">
        <button
          type="button"
          onClick={close}
          className={cn(
            'h-11 rounded-[10px] px-3 text-[15px] text-[#4A6353]',
            FOCUS
          )}
        >
          收起
        </button>
        <button
          type="button"
          onClick={onEdit}
          className={cn(
            'ml-auto h-11 rounded-[10px] border border-[#1F7A4D] px-4 text-[15px] font-bold text-[#17603C]',
            FOCUS
          )}
        >
          {editLabel}
        </button>
      </div>
    </div>
  )
}

function ReactionButton({
  reaction,
  onToggle
}: {
  reaction: ReactionSummary
  onToggle: () => void
}) {
  return (
    <button
      type="button"
      aria-pressed={reaction.mine}
      aria-label={`${reaction.label}，${reaction.count} 人`}
      title={reaction.label}
      onClick={onToggle}
      className={cn(
        'flex h-11 min-w-[48px] items-center justify-center gap-1 rounded-full border px-2.5 text-[15px]',
        reaction.mine
          ? 'border-[#17603C] bg-[#E3F1E7] font-bold text-[#17603C] ring-1 ring-[#17603C]'
          : 'border-[#C9D6CC] bg-white text-[#12301F]',
        FOCUS
      )}
    >
      <span aria-hidden="true" className="text-lg leading-none">
        {reaction.emoji}
      </span>
      {reaction.count > 0 && <span aria-hidden="true">{reaction.count}</span>}
    </button>
  )
}

/** 卡片上的一行小字：人數最多的兩種表情與留言數，例如「👍 3 ❤️ 1 💬 2」 */
export function ReactionLine({
  reactions,
  commentCount,
  className
}: {
  reactions: ReactionSummary[]
  commentCount: number
  className?: string
}) {
  // 同樣人數時照 config 的順序（👍 優先）
  const top = reactions
    .filter(reaction => reaction.count > 0)
    .sort((a, b) => b.count - a.count)
    .slice(0, 2)
  if (top.length === 0 && commentCount === 0) return null
  const spoken = [
    ...top.map(reaction => `${reaction.label} ${reaction.count}`),
    ...(commentCount > 0 ? [`留言 ${commentCount}`] : [])
  ].join('、')
  return (
    <span className={cn('flex flex-wrap gap-x-3', className)}>
      <span className="sr-only">{spoken}</span>
      {top.map(reaction => (
        <span key={reaction.key} aria-hidden="true">
          {reaction.emoji} {reaction.count}
        </span>
      ))}
      {commentCount > 0 && <span aria-hidden="true">💬 {commentCount}</span>}
    </span>
  )
}

function formatTime(iso: string): string {
  const date = new Date(iso)
  if (Number.isNaN(date.getTime())) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${date.getMonth() + 1}/${date.getDate()} ${pad(
    date.getHours()
  )}:${pad(date.getMinutes())}`
}
