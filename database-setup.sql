-- Pizzarium order database setup for Supabase
-- Run this entire file once in Supabase Dashboard > SQL Editor > New query.

create extension if not exists pgcrypto;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number bigint generated always as identity unique,
  created_at timestamptz not null default now(),
  status text not null default 'new' check (status in ('new', 'confirmed', 'preparing', 'out_for_delivery', 'completed', 'cancelled')),
  fulfillment_type text not null check (fulfillment_type in ('delivery', 'pickup')),
  customer_name text not null,
  customer_phone text not null,
  delivery_address text,
  location_url text,
  notes text,
  items jsonb not null check (jsonb_typeof(items) = 'array'),
  total integer not null check (total >= 0)
);

alter table public.orders enable row level security;

-- A visitor can create only a new order. No visitor can read customer data.
drop policy if exists "Visitors can place orders" on public.orders;
create policy "Visitors can place orders"
on public.orders for insert to anon, authenticated
with check (status = 'new');

grant usage on schema public to anon, authenticated;
grant insert on public.orders to anon, authenticated;
grant usage, select on sequence public.orders_order_number_seq to anon, authenticated;

-- Restaurant staff can view and update orders securely in the Supabase Dashboard > Table Editor.
