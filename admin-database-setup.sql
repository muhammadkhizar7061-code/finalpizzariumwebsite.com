-- Pizzarium Order Console staff-access setup.
-- Run once after auth-database-setup.sql in Supabase Dashboard > SQL Editor.

alter table public.profiles add column if not exists role text not null default 'customer'
  check (role in ('customer', 'staff', 'admin'));

-- Create profile rows for any accounts that existed before the profile trigger was added.
insert into public.profiles (id, full_name, phone)
select id, raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'phone'
from auth.users
on conflict (id) do nothing;

create or replace function public.is_pizzarium_staff()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role in ('staff', 'admin'));
$$;

grant execute on function public.is_pizzarium_staff() to authenticated;

drop policy if exists "Staff can view all orders" on public.orders;
drop policy if exists "Staff can update all orders" on public.orders;
create policy "Staff can view all orders"
on public.orders for select to authenticated
using (public.is_pizzarium_staff());
create policy "Staff can update all orders"
on public.orders for update to authenticated
using (public.is_pizzarium_staff())
with check (public.is_pizzarium_staff());

grant select, update on public.orders to authenticated;

-- After you create and confirm your own customer account, replace YOUR_EMAIL below
-- with your own sign-in email, then run this final command.
-- update public.profiles set role = 'admin'
-- where id = (select id from auth.users where email = 'YOUR_EMAIL');
