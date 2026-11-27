-- 跨年行程共編（/newyear）用的兩張表：時段與項目。
-- 沒有登入機制：拿到網址的人都能讀寫，所以只開放這兩張表，並限制欄位長度。

create table if not exists public.ny_slots (
  id uuid primary key default gen_random_uuid(),
  day smallint not null check (day in (1, 2)),
  name text not null check (char_length(name) between 1 and 20),
  sort double precision not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.ny_items (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 60),
  kind text not null check (kind in ('food', 'play', 'show')),
  who text not null default '' check (char_length(who) <= 20),
  -- null 代表還在「口袋」裡；時段被刪掉時，裡面的項目自動回到口袋
  slot_id uuid references public.ny_slots (id) on delete set null,
  sort double precision not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists ny_items_slot_id_idx on public.ny_items (slot_id);

alter table public.ny_slots enable row level security;
alter table public.ny_items enable row level security;

create policy "ny_slots: anyone with the link can edit"
  on public.ny_slots for all to anon, authenticated
  using (true) with check (true);

create policy "ny_items: anyone with the link can edit"
  on public.ny_items for all to anon, authenticated
  using (true) with check (true);

grant select, insert, update, delete on public.ny_slots to anon, authenticated;
grant select, insert, update, delete on public.ny_items to anon, authenticated;

-- 讓別人的編輯即時出現在其他人的畫面上
alter publication supabase_realtime add table public.ny_slots;
alter publication supabase_realtime add table public.ny_items;

-- 預設時段（之後大家可以在網站上增、改、刪）
insert into public.ny_slots (day, name, sort)
select * from (values
  (1, '下午', 1),
  (1, '晚餐', 2),
  (1, '倒數前', 3),
  (2, '中午', 1),
  (2, '下午', 2),
  (2, '晚餐', 3),
  (2, '晚上', 4),
  (2, '1/2 早上', 5)
) as defaults (day, name, sort)
where not exists (select 1 from public.ny_slots);
