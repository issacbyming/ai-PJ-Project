import '@/app/globals.css'
import type { Metadata } from 'next'
import { Unbounded } from 'next/font/google'
import { TRIP } from '@/lib/newyear/config'

const fontDisplay = Unbounded({
  subsets: ['latin'],
  weight: ['500', '700'],
  variable: '--font-display'
})

export const metadata: Metadata = {
  title: `${TRIP.title}｜跨年行程`,
  description: `${TRIP.range} 跨年兩天，大家一起填要帶什麼、玩什麼。`,
  themeColor: '#0C1030',
  viewport: { width: 'device-width', initialScale: 1, viewportFit: 'cover' },
  // 只給拿到連結的朋友用，不讓搜尋引擎收錄
  robots: { index: false, follow: false },
  icons: {
    icon: '/favicon.ico',
    shortcut: '/favicon-16x16.png',
    apple: '/apple-touch-icon.png'
  }
}

export default function NewYearLayout({
  children
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="zh-Hant" className="motion-safe:scroll-smooth">
      <body
        className={`${fontDisplay.variable} antialiased`}
        style={{
          fontFamily:
            "'PingFang TC', 'Noto Sans TC', 'Microsoft JhengHei', system-ui, sans-serif"
        }}
      >
        {children}
      </body>
    </html>
  )
}
