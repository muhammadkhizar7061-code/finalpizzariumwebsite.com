-- Pizzarium customer order-history and secure cancellation setup.
-- Run this ONCE in Supabase Dashboard > SQL Editor, after admin-database-setup.sql.

drop policy if exists "Customers can cancel their eligible orders" on public.orders;
create policy "Customers can cancel their eligible orders"
on public.orders for update to authenticated
using (auth.uid() = customer_id and status in ('new', 'confirmed'))
with check (auth.uid() = customer_id and status = 'cancelled');

-- Customers and staff may change an order status only. They cannot alter prices,
-- customer data, addresses, or items through the browser.
revoke update on public.orders from authenticated;
grant update(status) on public.orders to authenticated;
