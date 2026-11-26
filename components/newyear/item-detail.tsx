'use client'

import * as React from 'react'
import { cn } from '@/lib/utils'
import { KINDS, LIMITS } from '@/lib/newyear/config'
import { getSavedName, saveName } from '@/lib/newyear/identity'
import type { Item } from '@/lib/newyear/types'
import type { Planner, ReactionSummary } from '@/lib/newyear/use-planner'
import { useRevealOnMount } from './item-form'
import { FOCUS, KIND_TAG } from './styles'

const FIELD =
  'h-11 w-full rounded-[10px] border border-[#8FAE98] bg-white px-3 text-base text-[#12301F] placeholder:text-[#5D7566]'

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
  const [body, setBody] = React.useState('')
  const nameId = React.useId()
  const bodyId = React.useId()
  const ref = useRevealOnMount<HTMLDivElement>()
  const canSend = name.trim().length > 0 && body.trim().length > 0

  React.useEffect(() => {
    setName(getSavedName())
  }, [])

  const send = (event: React.FormEvent) => {
    event.preventDefault()
    if (!canSend) return
    const who = name.trim()
    saveName(who)
    planner.addComment(item.id, who, body.trim())
    setBody('')
  }

  return (
    <div
      ref={ref}
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

      <div role="group" aria-label="按表情" className="flex flex-wrap gap-1">
        {reactions.map(reaction => (
          <ReactionButton
            key={reaction.key}
            reaction={reaction}
            onToggle={() => planner.toggleReaction(item.id, reaction.key)}
          />
        ))}
      </div>

      <div className="flex flex-col gap-2 border-t border-[#D5E0D3] pt-3">
        <h4 className="text-sm font-bold">
          留言{comments.length > 0 && `（${comments.length}）`}
        </h4>
        {comments.length > 0 ? (
          <ul className="flex flex-col gap-2">
            {comments.map(comment => (
              <li
                key={comment.id}
                className="rounded-[10px] bg-[#F2F6F1] px-3 py-2 text-[15px] leading-[22px]"
              >
                <div className="flex items-baseline gap-2">
                  <span className="min-w-0 truncate font-bold">
                    {comment.who}
                  </span>
                  <span className="shrink-0 text-xs text-[#5D7566]">
                    {formatTime(comment.createdAt)}
                  </span>
                  {comment.clientId === planner.clientId && (
                    <button
                      type="button"
                      onClick={() => planner.removeComment(comment.id)}
                      aria-label={`刪除我的留言：${comment.body}`}
                      className={cn(
                        '-my-2 ml-auto h-9 shrink-0 rounded-lg px-2 text-[13px] text-[#A32018]',
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
            ))}
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
            id={nameId}
            type="text"
            autoComplete="nickname"
            maxLength={LIMITS.who}
            placeholder="你的名字"
            value={name}
            onChange={event => setName(event.target.value)}
            className={cn(FIELD, FOCUS)}
          />
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
              className={cn(FIELD, 'min-w-0 flex-1', FOCUS)}
            />
            <button
              type="submit"
              disabled={!canSend}
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
          onClick={onClose}
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
          ? 'border-[#1F7A4D] bg-[#E3F1E7] font-bold text-[#17603C]'
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

/** 卡片上的一行小字：有人按的表情與留言數，例如「👍 3 ❤️ 1 💬 2」 */
export function ReactionLine({
  reactions,
  commentCount,
  className
}: {
  reactions: ReactionSummary[]
  commentCount: number
  className?: string
}) {
  const used = reactions.filter(reaction => reaction.count > 0)
  if (used.length === 0 && commentCount === 0) return null
  const spoken = [
    ...used.map(reaction => `${reaction.label} ${reaction.count}`),
    ...(commentCount > 0 ? [`留言 ${commentCount}`] : [])
  ].join('、')
  return (
    <span className={cn('flex flex-wrap gap-x-2.5 text-[13px]', className)}>
      <span className="sr-only">{spoken}</span>
      {used.map(reaction => (
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
