-- Pizzarium customer accounts and secure database-only checkout.
-- Run this ONCE after database-setup.sql in Supabase Dashboard > SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
drop policy if exists "Customers can view their profile" on public.profiles;
drop policy if exists "Customers can update their profile" on public.profiles;
create policy "Customers can view their profile" on public.profiles for select to authenticated using (auth.uid() = id);
create policy "Customers can update their profile" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (new.id, new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'phone')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users for each row execute procedure public.create_profile_for_new_user();

alter table public.orders add column if not exists customer_id uuid references auth.users(id) on delete set null;
alter table public.orders enable row level security;
drop policy if exists "Visitors can place orders" on public.orders;
drop policy if exists "Customers can place their own orders" on public.orders;
drop policy if exists "Customers can view their own orders" on public.orders;
create policy "Customers can place their own orders"
on public.orders for insert to authenticated
with check (auth.uid() = customer_id and status = 'new');
create policy "Customers can view their own orders"
on public.orders for select to authenticated
using (auth.uid() = customer_id);

grant usage on schema public to authenticated;
grant select, insert on public.orders to authenticated;
grant select, update on public.profiles to authenticated;
