'use client'

import * as React from 'react'
import { cn } from '@/lib/utils'
import { DAYS, TRIP } from '@/lib/newyear/config'
import type { DayId } from '@/lib/newyear/types'
import { usePlanner, type Planner as PlannerState } from '@/lib/newyear/use-planner'
import { Fireworks } from './fireworks'
import { Pocket } from './pocket'
import { SlotNameForm, SlotSection, type OpenPanel } from './slot-section'
import { FOCUS, TONE, type Tone } from './styles'

const COLUMN = 'mx-auto w-full max-w-[560px] px-5'

export function Planner() {
  const planner = usePlanner()
  const [open, setOpenPanel] = React.useState<OpenPanel>(null)
  const [pocketExpanded, setPocketExpanded] = React.useState(false)

  const setOpen = (next: OpenPanel) => {
    setOpenPanel(next)
    if (next) setPocketExpanded(false)
  }

  const setExpanded = (expanded: boolean) => {
    setPocketExpanded(expanded)
    if (expanded) setOpenPanel(null)
  }

  return (
    <div className="min-h-screen bg-[#EEF4EC] pb-24">
      <div className="bg-[#0C1030] pt-7 text-[#F4F2FF]">
        <header className={cn(COLUMN, 'flex flex-col')}>
          <div className="flex h-11 items-center justify-between">
            <span
              className="text-[13px] font-medium tracking-[0.04em] text-[#FFC857]"
              style={{ fontFamily: 'var(--font-display), system-ui, sans-serif' }}
            >
              {TRIP.years}
            </span>
            <CopyLinkButton />
          </div>
          <h1 className="mt-5 text-[40px] font-extrabold leading-[48px] tracking-[0.02em]">
            {TRIP.title}
          </h1>
          <p className="mt-2 text-sm leading-[22px] text-[#B9BEE6]">
            {TRIP.range} · 點任何一項就能改，不用登入
          </p>

          {planner.ready && planner.mode === 'local' && (
            <p className="mt-4 rounded-xl border border-[#FFC857] px-3.5 py-2.5 text-[13px] leading-5 text-[#FFC857]">
              目前是單機試用：資料只存在這台裝置，別人還看不到你的編輯。
            </p>
          )}

          <nav aria-label="跳到哪一天" className="mt-5 flex gap-2">
            <a
              href={`#${DAYS[1].anchor}`}
              className={cn(
                'flex h-11 flex-1 items-center justify-center rounded-full bg-[#FFC857] text-sm font-bold text-[#2A1A00]',
                FOCUS
              )}
            >
              {DAYS[1].nav}
            </a>
            <a
              href={`#${DAYS[2].anchor}`}
              className={cn(
                'flex h-11 flex-1 items-center justify-center rounded-full border border-[#4A5290] text-sm font-bold text-[#F4F2FF]',
                FOCUS
              )}
            >
              {DAYS[2].nav}
            </a>
          </nav>
        </header>

        <div className={cn(COLUMN, 'pt-8')}>
          <DaySection day={1} tone="night" planner={planner} open={open} setOpen={setOpen} />
        </div>
      </div>

      <Fireworks />

      <div className={cn(COLUMN, 'pt-7 text-[#12301F]')}>
        <DaySection day={2} tone="day" planner={planner} open={open} setOpen={setOpen} />
      </div>

      <Pocket
        items={planner.itemsBySlot.get(null) ?? []}
        planner={planner}
        expanded={pocketExpanded}
        setExpanded={setExpanded}
      />

      {planner.error && (
        <div
          role="alert"
          className="fixed inset-x-0 top-3 z-50 mx-auto flex w-[calc(100%-24px)] max-w-[536px] items-center gap-3 rounded-xl bg-[#A32018] py-2 pl-4 pr-2 text-sm text-white shadow-lg"
        >
          <span className="flex-1">{planner.error}</span>
          <button
            type="button"
            onClick={planner.dismissError}
            className={cn('h-11 shrink-0 rounded-lg px-3 font-bold', FOCUS)}
          >
            知道了
          </button>
        </div>
      )}
    </div>
  )
}

interface DaySectionProps {
  day: DayId
  tone: Tone
  planner: PlannerState
  open: OpenPanel
  setOpen: (open: OpenPanel) => void
}

function DaySection({ day, tone, planner, open, setOpen }: DaySectionProps) {
  const t = TONE[tone]
  const slots = planner.slotsByDay[day]
  const addingSlot = open?.type === 'new-slot' && open.day === day

  return (
    <section id={DAYS[day].anchor} className="scroll-mt-4">
      <p className={cn('text-[13px] leading-5', t.sub)}>{DAYS[day].date}</p>
      <h2 className="mb-3 text-[22px] font-extrabold leading-[30px]">
        {DAYS[day].heading}
      </h2>

      {!planner.ready ? (
        <p className={cn('pb-8 text-sm', t.sub)}>載入中…</p>
      ) : (
        <>
          {slots.map((slot, index) => (
            <SlotSection
              key={slot.id}
              slot={slot}
              items={planner.itemsBySlot.get(slot.id) ?? []}
              tone={tone}
              planner={planner}
              open={open}
              setOpen={setOpen}
              isFirst={index === 0}
              isLast={index === slots.length - 1}
            />
          ))}

          <div className="pb-8 pl-[26px]">
            {addingSlot ? (
              <SlotNameForm
                initial=""
                submitLabel="新增時段"
                onSubmit={name => {
                  planner.addSlot(day, name)
                  setOpen(null)
                }}
                onCancel={() => setOpen(null)}
              />
            ) : (
              <button
                type="button"
                onClick={() => setOpen({ type: 'new-slot', day })}
                className={cn('h-11 rounded-xl px-1 text-sm underline underline-offset-4', t.sub, FOCUS)}
              >
                ＋ 新增時段
              </button>
            )}
          </div>
        </>
      )}
    </section>
  )
}

function CopyLinkButton() {
  const [copied, setCopied] = React.useState(false)

  const copy = async () => {
    const url = window.location.href
    try {
      await navigator.clipboard.writeText(url)
      setCopied(true)
      window.setTimeout(() => setCopied(false), 2000)
    } catch {
      // 瀏覽器不給用剪貼簿時，改成讓使用者自己複製
      window.prompt('複製這個連結傳給朋友', url)
    }
  }

  return (
    <button
      type="button"
      onClick={copy}
      className={cn(
        'flex h-11 items-center gap-1.5 rounded-full border border-[#4A5290] px-3.5 text-[13px] text-[#F4F2FF]',
        FOCUS
      )}
    >
      <svg
        width="16"
        height="16"
        viewBox="0 0 16 16"
        aria-hidden="true"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M6.5 9.5l3-3" />
        <path d="M9 4.5l1-1a2.5 2.5 0 0 1 3.5 3.5l-1 1" />
        <path d="M7 11.5l-1 1A2.5 2.5 0 0 1 2.5 9l1-1" />
      </svg>
      <span aria-live="polite">{copied ? '已複製' : '複製連結'}</span>
    </button>
  )
}
