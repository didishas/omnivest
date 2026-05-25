-- FinanceIQ — Supabase schema de synchronisation téléphone / PC
-- À coller dans Supabase > SQL Editor > Run

create extension if not exists pgcrypto;

create table if not exists public.finance_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revenues jsonb not null default '{"salaire":2400,"km":600,"location":365,"autres":0,"excep":0}'::jsonb,
  ibkr_total numeric(12,2) not null default 20,
  ibkr_pnl numeric(12,2) not null default 0,
  invested_this_month numeric(12,2) not null default 0,
  debt_huissier numeric(12,2) not null default 14000,
  debt_onem numeric(12,2) not null default 1300,
  real_capital numeric(12,2) not null default 20,
  current_month integer not null default 0 check (current_month between 1 and 60),
  manual_plan_month boolean not null default false,
  plan_start_date date not null default date '2026-05-01',
  updated_at timestamptz not null default now()
);

create table if not exists public.finance_expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  amt numeric(12,2) not null check (amt >= 0),
  cat text not null default 'autre',
  expense_date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_finance_state_updated_at on public.finance_state;
create trigger trg_finance_state_updated_at
before update on public.finance_state
for each row execute function public.set_updated_at();

drop trigger if exists trg_finance_expenses_updated_at on public.finance_expenses;
create trigger trg_finance_expenses_updated_at
before update on public.finance_expenses
for each row execute function public.set_updated_at();

alter table public.finance_state enable row level security;
alter table public.finance_expenses enable row level security;

drop policy if exists "finance_state_select_own" on public.finance_state;
create policy "finance_state_select_own"
on public.finance_state for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "finance_state_insert_own" on public.finance_state;
create policy "finance_state_insert_own"
on public.finance_state for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "finance_state_update_own" on public.finance_state;
create policy "finance_state_update_own"
on public.finance_state for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "finance_state_delete_own" on public.finance_state;
create policy "finance_state_delete_own"
on public.finance_state for delete
to authenticated
using (auth.uid() = user_id);

drop policy if exists "finance_expenses_select_own" on public.finance_expenses;
create policy "finance_expenses_select_own"
on public.finance_expenses for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "finance_expenses_insert_own" on public.finance_expenses;
create policy "finance_expenses_insert_own"
on public.finance_expenses for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "finance_expenses_update_own" on public.finance_expenses;
create policy "finance_expenses_update_own"
on public.finance_expenses for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "finance_expenses_delete_own" on public.finance_expenses;
create policy "finance_expenses_delete_own"
on public.finance_expenses for delete
to authenticated
using (auth.uid() = user_id);

-- Optionnel: index utile pour afficher rapidement les dépenses du mois
create index if not exists finance_expenses_user_date_idx
on public.finance_expenses(user_id, expense_date desc);
