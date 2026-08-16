const historySession = PizzariumAuth.getSession();
const pageSize = 20;
let historyOffset = 0;
let historyHasMore = false;
let orderToCancel = null;

if (!historySession?.access_token) location.replace('sign-in.html');

function historyHeaders() { return { apikey: PizzariumAuth.key, Authorization: `Bearer ${historySession.access_token}` }; }
function historyMoney(value) { return `PKR ${Number(value || 0).toLocaleString()}`; }
function historyDate(value) { return new Intl.DateTimeFormat('en-PK', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)); }
function escapeHistory(value) { return String(value || '').replace(/[&<>'"]/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' })[character]); }
function titleStatus(status) { return String(status || 'new').replaceAll('_', ' '); }
function isCancellable(status) { return ['new', 'confirmed'].includes(status); }
function renderHistory(orders, append = false) {
  const list = document.querySelector('#customerOrders');
  const markup = orders.map(order => `<article class="customer-order"><div><h2>#${escapeHistory(order.order_number || '—')}</h2><small>${historyDate(order.created_at)}</small></div><div><h3>${order.fulfillment_type === 'delivery' ? 'Delivery order' : 'Pickup order'}</h3>${order.delivery_address ? `<p>${escapeHistory(order.delivery_address)}</p>` : ''}<div class="history-items">${(order.items || []).map(item => `<div class="history-item"><span>${escapeHistory(item.name)} · ${escapeHistory(item.size)} × ${item.quantity}</span><span>${historyMoney(item.line_total)}</span></div>`).join('')}</div></div><aside><span class="status-pill ${escapeHistory(order.status)}">${escapeHistory(titleStatus(order.status))}</span><strong class="history-total">${historyMoney(order.total)}</strong>${isCancellable(order.status) ? `<button class="cancel-order" type="button" data-order-id="${order.id}">Cancel order</button>` : ''}</aside></article>`).join('');
  if (append) list.insertAdjacentHTML('beforeend', markup); else list.innerHTML = markup || '<div class="empty-history">You have not placed an order yet. Your Pizzarium orders will appear here.</div>';
}
async function loadHistory(append = false) {
  const status = document.querySelector('#ordersStatus');
  if (!append) { historyOffset = 0; status.textContent = 'Loading your orders…'; }
  try {
    const response = await fetch(`${PizzariumAuth.url}/rest/v1/orders?customer_id=eq.${encodeURIComponent(historySession.user.id)}&select=*&order=created_at.desc&limit=${pageSize}&offset=${historyOffset}`, { headers: historyHeaders() });
    if (!response.ok) throw new Error();
    const orders = await response.json();
    renderHistory(orders, append);
    historyOffset += orders.length;
    historyHasMore = orders.length === pageSize;
    document.querySelector('#loadMoreOrders').hidden = !historyHasMore;
    status.textContent = historyOffset ? `${historyOffset} recent order${historyOffset === 1 ? '' : 's'} shown` : 'No orders yet';
  } catch { status.textContent = 'Unable to load your order history.'; }
}
function openCancelDialog(id) { orderToCancel = id; document.querySelector('#cancelPopup').hidden = false; }
function closeCancelDialog() { orderToCancel = null; document.querySelector('#cancelPopup').hidden = true; }
async function cancelOrder() {
  if (!orderToCancel) return;
  const button = document.querySelector('#confirmCancel');
  button.disabled = true;
  button.textContent = 'Cancelling…';
  try {
    const response = await fetch(`${PizzariumAuth.url}/rest/v1/orders?id=eq.${encodeURIComponent(orderToCancel)}`, { method: 'PATCH', headers: { ...historyHeaders(), 'Content-Type': 'application/json', Prefer: 'return=minimal' }, body: JSON.stringify({ status: 'cancelled' }) });
    if (!response.ok) throw new Error();
    closeCancelDialog();
    await loadHistory();
  } catch { alert('This order can no longer be cancelled. Please contact Pizzarium for help.'); closeCancelDialog(); }
  finally { button.disabled = false; button.textContent = 'Cancel order'; }
}
document.querySelector('#refreshHistory').addEventListener('click', () => loadHistory());
document.querySelector('#loadMoreOrders').addEventListener('click', () => loadHistory(true));
document.querySelector('#customerOrders').addEventListener('click', event => { const button = event.target.closest('.cancel-order'); if (button) openCancelDialog(button.dataset.orderId); });
document.querySelector('#keepOrder').addEventListener('click', closeCancelDialog);
document.querySelector('.cancel-backdrop').addEventListener('click', closeCancelDialog);
document.querySelector('#confirmCancel').addEventListener('click', cancelOrder);
document.querySelector('#ordersSignOut').addEventListener('click', event => { event.preventDefault(); PizzariumAuth.signOut(); });
loadHistory();
