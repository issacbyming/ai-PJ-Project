<a href="https://chat.vercel.ai/">
  <h1 align="center">ExplainThis AI Chatbot</h1>
</a>

<p align="center">
  An open-source AI chatbot app template built with Next.js, the Vercel AI SDK, OpenAI, and React Query.
</p>

<p align="center">
  <a href="#features"><strong>Features</strong></a> ·
  <a href="#deploy-your-own"><strong>Deploy Your Own</strong></a> ·
  <a href="#running-locally"><strong>Running locally</strong></a> ·
</p>
<br/>

## Features

- [Next.js](https://nextjs.org) App Router
- React Server Components (RSCs), Suspense, and Server Actions
- [Vercel AI SDK](https://sdk.vercel.ai/docs) for streaming chat UI
- Support for OpenAI (default), Anthropic, Hugging Face, or custom AI chat models and/or LangChain
- Edge runtime-ready
- [shadcn/ui](https://ui.shadcn.com)
  - Styling with [Tailwind CSS](https://tailwindcss.com)
  - [Radix UI](https://radix-ui.com) for headless component primitives
  - Icons from [Phosphor Icons](https://phosphoricons.com)

## Deploy Your Own

You can deploy your own version of the AI Chatbot to Vercel with one click:

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2FTheExplainthis%2Fai-chatbot&env=NEXT_PUBLIC_APP_NAME,NEXT_PUBLIC_API_BASE_URL,NEXT_PUBLIC_LOGO_URL,NEXT_PUBLIC_EMPTY_SCREEN_TITLE,NEXT_PUBLIC_EMPTY_SCREEN_DESC&project-name=ai-chatbot&repository-name=my-ai-chatbot&demo-title=AI%20%E8%81%8A%E5%A4%A9%E6%A9%9F%E5%99%A8%E4%BA%BA&demo-description=AI%20%E8%81%8A%E5%A4%A9%E6%A9%9F%E5%99%A8%E4%BA%BA)

## Running locally

You will need to use the environment variables [defined in `.env.example`](.env.example) to run this Chatbot. It's recommended you use [Vercel Environment Variables](https://vercel.com/docs/concepts/projects/environment-variables) for this, but a `.env` file is all that is necessary.

> Note: You should not commit your `.env` file or it will expose secrets that will allow others to control access to your various OpenAI and authentication provider accounts.

1. Install Vercel CLI: `npm i -g vercel`
2. Link local instance with Vercel and GitHub accounts (creates `.vercel` directory): `vercel link`
3. Download your environment variables: `vercel env pull`

```bash
pnpm install
pnpm dev
```

Your app template should now be running on [localhost:3000](http://localhost:3000/).

## 跨年行程共編（`/newyear`）

給朋友一起編輯跨年兩天行程的頁面：誰帶什麼、安排什麼節目，免登入、任何人都能改。

- 上半是第一天（12/31），中間用 00:00 的煙火隔開，下半是宜蘭三星張宅（1/1–1/2）。
- 每個時段可以加「吃的／玩的／節目」，點任何一項就能修改、換時段或刪除。
- 底部的「口袋」放還沒排時段的點子，點一下再選要排到哪個時段。
- 時段可以新增、改名、前後移動、刪除（刪除時裡面的東西會回到口袋）。

標題、日期等固定文案在 `lib/newyear/config.ts`。

### 資料存在哪

設定 `NEXT_PUBLIC_SUPABASE_URL` 與 `NEXT_PUBLIC_SUPABASE_ANON_KEY` 後，資料存在 Supabase 並即時同步給所有人；
資料表用 `supabase/migrations/20261126000000_newyear_planner.sql` 建立。
兩個變數沒設定時，資料只存在各自瀏覽器的 localStorage（頁面上會顯示提醒）。
