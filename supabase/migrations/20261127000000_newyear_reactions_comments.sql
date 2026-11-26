-- 跨年行程共編（/newyear）：每張卡片的表情符號與留言。
-- 和前一個 migration 一樣沒有登入機制，只開放這兩張表，並限制內容長度。
-- client_id 是每個瀏覽器自己產生的亂數，用來記「我按過哪個表情」「哪則留言是我寫的」。

create table if not exists public.ny_comments (
  id uuid primary key default gen_random_uuid(),
  -- 卡片被刪掉時，底下的留言一起刪
  item_id uuid not null references public.ny_items (id) on delete cascade,
  who text not null check (char_length(who) between 1 and 20),
  body text not null check (char_length(body) between 1 and 200),
  client_id uuid not null,
  created_at timestamptz not null default now()
);

create index if not exists ny_comments_item_id_idx on public.ny_comments (item_id);

-- 同一個瀏覽器對同一張卡片的同一種表情只算一次
create table if not exists public.ny_reactions (
  item_id uuid not null references public.ny_items (id) on delete cascade,
  reaction text not null check (reaction in ('like', 'love', 'haha', 'yum', 'hmm')),
  client_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (item_id, reaction, client_id)
);

alter table public.ny_comments enable row level security;
alter table public.ny_reactions enable row level security;

create policy "ny_comments: anyone with the link can edit"
  on public.ny_comments for all to anon, authenticated
  using (true) with check (true);

create policy "ny_reactions: anyone with the link can edit"
  on public.ny_reactions for all to anon, authenticated
  using (true) with check (true);

grant select, insert, update, delete on public.ny_comments to anon, authenticated;
grant select, insert, update, delete on public.ny_reactions to anon, authenticated;

-- 別人按的表情、寫的留言即時出現在其他人的畫面上
alter publication supabase_realtime add table public.ny_comments;
alter publication supabase_realtime add table public.ny_reactions;
