CREATE MATERIALIZED VIEW marketplace_daily_revenue AS
SELECT
  date_trunc('day', o.created_at)::date AS revenue_day,
  so.seller_id,
  sum(oi.qty * oi.unit_price)::numeric(14,2) AS revenue,
  count(DISTINCT o.id) AS orders_count,
  count(*) AS item_lines
FROM orders o
JOIN seller_orders so ON so.order_id = o.id
JOIN order_items oi ON oi.seller_order_id = so.id
GROUP BY date_trunc('day', o.created_at)::date, so.seller_id;

CREATE UNIQUE INDEX idx_marketplace_daily_revenue_day_seller ON marketplace_daily_revenue (revenue_day, seller_id);
