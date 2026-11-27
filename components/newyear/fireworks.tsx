import { TRIP } from '@/lib/newyear/config'

interface BurstProps {
  size: number
  rays: number
  color: string
  className: string
}

function Burst({ size, rays, color, className }: BurstProps) {
  const half = size / 2
  return (
    <svg
      width={size}
      height={size}
      viewBox={`${-half} ${-half} ${size} ${size}`}
      aria-hidden="true"
      fill="none"
      stroke={color}
      strokeWidth={size > 60 ? 2.5 : 2}
      strokeLinecap="round"
      className={className}
    >
      {Array.from({ length: rays }, (_, index) => (
        <line
          key={index}
          x1="0"
          y1={-half * 0.3}
          x2="0"
          y2={-half * 0.94}
          transform={`rotate(${(360 / rays) * index})`}
        />
      ))}
    </svg>
  )
}

/** 兩天中間的分隔：00:00 的煙火，底下的山接到宜蘭的白天 */
export function Fireworks() {
  return (
    <section
      aria-label={`跨年倒數，${TRIP.newYear} 新年快樂`}
      className="relative flex h-80 flex-col items-center overflow-hidden bg-[#0C1030] pt-24 text-[#F4F2FF]"
    >
      <Burst
        size={80}
        rays={12}
        color="#FFC857"
        className="absolute left-[8%] top-4 motion-safe:animate-pulse"
      />
      <Burst
        size={66}
        rays={10}
        color="#FF9EBB"
        className="absolute right-[10%] top-4 motion-safe:animate-pulse"
      />
      <Burst size={42} rays={8} color="#7CC6FF" className="absolute right-[4%] top-36" />
      <Burst size={38} rays={8} color="#7CC6FF" className="absolute left-[4%] top-[152px]" />

      <svg
        viewBox="0 0 390 90"
        preserveAspectRatio="none"
        aria-hidden="true"
        className="absolute inset-x-0 bottom-0 h-[90px] w-full"
      >
        <path
          d="M0 32 C 60 2, 110 6, 160 26 S 250 -4, 300 14 S 360 20, 390 6 L390 90 L0 90 Z"
          fill="#23306B"
        />
        <path
          d="M0 52 C 50 28, 120 32, 180 50 S 300 20, 390 38 L390 90 L0 90 Z"
          fill="#2E7D5B"
        />
        <path
          d="M0 68 C 70 42, 130 54, 200 64 S 310 42, 390 60 L390 90 L0 90 Z"
          fill="#EEF4EC"
        />
      </svg>

      <p
        className="relative text-[54px] font-bold leading-[64px] text-[#FFC857]"
        style={{ fontFamily: 'var(--font-display), system-ui, sans-serif' }}
      >
        00:00
      </p>
      <p className="relative mt-1.5 text-lg font-bold tracking-[0.12em]">
        新年快樂・{TRIP.newYear}
      </p>
    </section>
  )
}
