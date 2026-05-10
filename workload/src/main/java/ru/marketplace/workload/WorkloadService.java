package ru.marketplace.workload;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

@Service
public class WorkloadService {
    private final JdbcTemplate jdbcTemplate;
    private final String profile;

    public WorkloadService(JdbcTemplate jdbcTemplate, @Value("${workload.sql-profile}") String profile) {
        this.jdbcTemplate = jdbcTemplate;
        this.profile = profile == null ? "optimized" : profile.toLowerCase(Locale.ROOT);
    }

    public Map<String, Object> counts() {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("profile", profile);
        result.put("users", jdbcTemplate.queryForObject("SELECT count(*) FROM users", Long.class));
        result.put("skus", jdbcTemplate.queryForObject("SELECT count(*) FROM skus", Long.class));
        result.put("orders", jdbcTemplate.queryForObject("SELECT count(*) FROM orders", Long.class));
        result.put("sellerOrders", jdbcTemplate.queryForObject("SELECT count(*) FROM seller_orders", Long.class));
        result.put("statusHistory", jdbcTemplate.queryForObject("SELECT count(*) FROM seller_order_status_history", Long.class));
        result.put("workloadEvents", jdbcTemplate.queryForObject("SELECT count(*) FROM workload_events", Long.class));
        return result;
    }

    public Map<String, Object> order(long orderId) {
        String sql = switch (profile) {
            case "degraded" -> degradedOrderSql();
            case "optimized" -> optimizedOrderSql();
            default -> baselineOrderSql();
        };
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, orderId);
        return response("oltp_order_read", rows);
    }

    public Map<String, Object> upsertCartItem(Long userId, Long skuId, Integer qty) {
        long safeUserId = valueOrDefault(userId, 1L);
        long safeSkuId = valueOrDefault(skuId, 1L);
        int safeQty = Math.max(1, valueOrDefault(qty, 1));
        String sql = """
                WITH selected_cart AS (
                  SELECT id
                  FROM carts
                  WHERE user_id = ?
                    AND status = 'active'
                  ORDER BY id DESC
                  LIMIT 1
                ),
                selected_sku AS (
                  SELECT id
                  FROM skus
                  WHERE id >= ?
                  ORDER BY id
                  LIMIT 1
                )
                INSERT INTO cart_items (cart_id, sku_id, qty, added_at)
                SELECT c.id, s.id, ?, now()
                FROM selected_cart c
                JOIN selected_sku s ON true
                ON CONFLICT (cart_id, sku_id)
                DO UPDATE SET
                  qty = cart_items.qty + EXCLUDED.qty,
                  added_at = now()
                RETURNING cart_id, sku_id, qty
                """;
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, safeUserId, safeSkuId, safeQty);
        int carts = jdbcTemplate.update(
                "UPDATE carts SET updated_at = now() WHERE user_id = ? AND status = 'active'",
                safeUserId
        );
        Map<String, Object> result = response("oltp_cart_write", rows);
        result.put("updatedCarts", carts);
        return result;
    }

    public Map<String, Object> updateInventory(Long skuId, Integer delta) {
        long safeSkuId = valueOrDefault(skuId, 1L);
        int safeDelta = valueOrDefault(delta, -1);
        String sql = """
                WITH target_inventory AS (
                  SELECT warehouse_id, sku_id
                  FROM inventory
                  WHERE sku_id = ?
                  ORDER BY warehouse_id
                  LIMIT 1
                )
                UPDATE inventory i
                SET
                  qty = greatest(i.qty + ?, 0),
                  updated_at = now()
                FROM target_inventory t
                WHERE i.warehouse_id = t.warehouse_id
                  AND i.sku_id = t.sku_id
                RETURNING i.warehouse_id, i.sku_id, i.qty
                """;
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, safeSkuId, safeDelta);
        return response("oltp_inventory_update", rows);
    }

    public Map<String, Object> sellerRevenue(int fromDaysAgo, int toDaysAgo, int limit) {
        int safeFrom = Math.max(fromDaysAgo, toDaysAgo + 1);
        int safeTo = Math.max(toDaysAgo, 0);
        int safeLimit = Math.max(1, Math.min(limit, 200));
        String sql = "optimized".equals(profile) ? optimizedRevenueSql() : rawRevenueSql();
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, safeFrom, safeTo, safeLimit);
        return response("olap_seller_revenue", rows);
    }

    public Map<String, Object> catalogHealth(int minPrice, int maxPrice, int minQty, int limit) {
        int safeLimit = Math.max(1, Math.min(limit, 200));
        String sql = """
                SELECT
                  p.seller_id,
                  count(DISTINCT p.id) AS product_count,
                  count(DISTINCT sk.id) AS sku_count,
                  sum(i.qty) AS total_qty,
                  avg(sk.price)::numeric(12,2) AS avg_price,
                  percentile_disc(0.95) WITHIN GROUP (ORDER BY sk.price) AS p95_price
                FROM products p
                JOIN skus sk ON sk.product_id = p.id
                JOIN inventory i ON i.sku_id = sk.id
                JOIN warehouses w ON w.id = i.warehouse_id AND w.seller_id = p.seller_id
                WHERE sk.price BETWEEN ? AND ?
                  AND p.is_active = true
                GROUP BY p.seller_id
                HAVING sum(i.qty) >= ?
                ORDER BY total_qty DESC
                LIMIT ?
                """;
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, minPrice, maxPrice, minQty, safeLimit);
        return response("olap_catalog_health", rows);
    }

    public Map<String, Object> insertStatus(Long sellerOrderId, String statusCode) {
        long safeSellerOrderId = valueOrDefault(sellerOrderId, 1L);
        String safeStatusCode = statusCode == null || statusCode.isBlank() ? "paid" : statusCode;
        String sql = """
                WITH selected_order AS (
                  SELECT so.id AS seller_order_id, o.user_id
                  FROM seller_orders so
                  JOIN orders o ON o.id = so.order_id
                  WHERE so.id = ?
                ),
                selected_status AS (
                  SELECT id
                  FROM order_statuses
                  WHERE code = ?
                )
                INSERT INTO seller_order_status_history (seller_order_id, status_id, changed_at, changed_by_user_id)
                SELECT so.seller_order_id, st.id, now(), so.user_id
                FROM selected_order so
                JOIN selected_status st ON true
                RETURNING id, seller_order_id, status_id, changed_at
                """;
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, safeSellerOrderId, safeStatusCode);
        if (!"baseline".equals(profile) && !rows.isEmpty()) {
            jdbcTemplate.update(
                    "UPDATE seller_orders SET last_status_changed_at = now() WHERE id = ?",
                    safeSellerOrderId
            );
        }
        return response("log_status_insert", rows);
    }

    public Map<String, Object> insertEvent(String eventType, Long sellerOrderId, Long userId) {
        String safeEventType = eventType == null || eventType.isBlank() ? "status_changed" : eventType;
        long safeSellerOrderId = valueOrDefault(sellerOrderId, 1L);
        long safeUserId = valueOrDefault(userId, 1L);
        String sql = """
                WITH selected_order AS (
                  SELECT so.id AS seller_order_id
                  FROM seller_orders so
                  WHERE so.id >= ?
                  ORDER BY so.id
                  LIMIT 1
                ),
                selected_user AS (
                  SELECT u.id AS user_id
                  FROM users u
                  WHERE u.id >= ?
                  ORDER BY u.id
                  LIMIT 1
                )
                INSERT INTO workload_events (event_type, seller_order_id, user_id, payload, created_at)
                SELECT ?, so.seller_order_id, u.user_id, jsonb_build_object('profile', ?, 'source', 'workload'), now()
                FROM selected_order so
                JOIN selected_user u ON true
                RETURNING id, event_type, seller_order_id, user_id, created_at
                """;
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, safeSellerOrderId, safeUserId, safeEventType, profile);
        return response("log_event_insert", rows);
    }

    public Map<String, Object> refreshRevenueView() {
        jdbcTemplate.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY marketplace_daily_revenue");
        return Map.of("operation", "refresh_revenue_view", "status", "ok");
    }

    private Map<String, Object> response(String query, List<Map<String, Object>> rows) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("query", query);
        result.put("profile", profile);
        result.put("rowCount", rows.size());
        result.put("rows", rows);
        return result;
    }

    private String baselineOrderSql() {
        return """
                SELECT
                  o.id AS order_id,
                  o.created_at,
                  u.email,
                  a.city,
                  so.id AS seller_order_id,
                  s.shop_name,
                  p.title,
                  sk.sku_code,
                  oi.qty,
                  oi.unit_price
                FROM orders o
                JOIN users u ON u.id = o.user_id
                JOIN addresses a ON a.id = o.address_id
                JOIN seller_orders so ON so.order_id = o.id
                JOIN sellers s ON s.id = so.seller_id
                JOIN order_items oi ON oi.seller_order_id = so.id
                JOIN skus sk ON sk.id = oi.sku_id
                JOIN products p ON p.id = sk.product_id
                WHERE o.id = ?
                ORDER BY so.id, oi.id
                LIMIT 50
                """;
    }

    private String degradedOrderSql() {
        return """
                SELECT
                  o.id AS order_id,
                  o.created_at,
                  u.email,
                  a.city,
                  so.id AS seller_order_id,
                  so.priority,
                  so.total_amount,
                  s.shop_name,
                  p.title,
                  sk.sku_code,
                  oi.qty,
                  oi.unit_price,
                  coalesce(f.feedback_count, 0) AS feedback_count,
                  coalesce(f.avg_rating, 0) AS avg_rating,
                  coalesce(h.status_count, 0) AS status_count,
                  h.last_changed_at
                FROM orders o
                JOIN users u ON u.id = o.user_id
                JOIN addresses a ON a.id = o.address_id
                JOIN seller_orders so ON so.order_id = o.id
                JOIN sellers s ON s.id = so.seller_id
                JOIN order_items oi ON oi.seller_order_id = so.id
                JOIN skus sk ON sk.id = oi.sku_id
                JOIN products p ON p.id = sk.product_id
                LEFT JOIN (
                  SELECT seller_order_id, count(*) AS feedback_count, avg(rating)::numeric(12,2) AS avg_rating
                  FROM seller_order_feedback
                  GROUP BY seller_order_id
                ) f ON f.seller_order_id = so.id
                LEFT JOIN LATERAL (
                  SELECT count(*) AS status_count, max(changed_at) AS last_changed_at
                  FROM seller_order_status_history ssh
                  WHERE ssh.seller_order_id = so.id
                ) h ON true
                WHERE o.id = ?
                ORDER BY so.id, oi.id
                LIMIT 50
                """;
    }

    private String optimizedOrderSql() {
        return """
                SELECT
                  o.id AS order_id,
                  o.created_at,
                  u.email,
                  a.city,
                  so.id AS seller_order_id,
                  so.priority,
                  so.total_amount,
                  s.shop_name,
                  p.title,
                  sk.sku_code,
                  oi.qty,
                  oi.unit_price,
                  coalesce(f.feedback_count, 0) AS feedback_count,
                  coalesce(f.avg_rating, 0) AS avg_rating,
                  coalesce(h.status_count, 0) AS status_count,
                  h.last_changed_at
                FROM orders o
                JOIN users u ON u.id = o.user_id
                JOIN addresses a ON a.id = o.address_id
                JOIN seller_orders so ON so.order_id = o.id
                JOIN sellers s ON s.id = so.seller_id
                JOIN order_items oi ON oi.seller_order_id = so.id
                JOIN skus sk ON sk.id = oi.sku_id
                JOIN products p ON p.id = sk.product_id
                LEFT JOIN LATERAL (
                  SELECT count(*) AS feedback_count, avg(rating)::numeric(12,2) AS avg_rating
                  FROM seller_order_feedback f
                  WHERE f.seller_order_id = so.id
                ) f ON true
                LEFT JOIN LATERAL (
                  SELECT count(*) AS status_count, max(changed_at) AS last_changed_at
                  FROM seller_order_status_history ssh
                  WHERE ssh.seller_order_id = so.id
                ) h ON true
                WHERE o.id = ?
                ORDER BY so.id, oi.id
                LIMIT 50
                """;
    }

    private String rawRevenueSql() {
        return """
                SELECT
                  so.seller_id,
                  date_trunc('day', o.created_at)::date AS revenue_day,
                  sum(oi.qty * oi.unit_price)::numeric(14,2) AS revenue,
                  count(DISTINCT o.id) AS orders_count,
                  count(*) AS item_lines
                FROM orders o
                JOIN seller_orders so ON so.order_id = o.id
                JOIN order_items oi ON oi.seller_order_id = so.id
                JOIN sellers s ON s.id = so.seller_id
                WHERE o.created_at >= now() - make_interval(days => ?)
                  AND o.created_at < now() - make_interval(days => ?)
                GROUP BY so.seller_id, date_trunc('day', o.created_at)::date
                HAVING sum(oi.qty * oi.unit_price) > 0
                ORDER BY revenue DESC
                LIMIT ?
                """;
    }

    private String optimizedRevenueSql() {
        return """
                SELECT
                  seller_id,
                  revenue_day,
                  revenue,
                  orders_count,
                  item_lines
                FROM marketplace_daily_revenue
                WHERE revenue_day >= current_date - CAST(? AS integer)
                  AND revenue_day < current_date - CAST(? AS integer)
                ORDER BY revenue DESC
                LIMIT ?
                """;
    }

    private long valueOrDefault(Long value, long fallback) {
        return value == null || value < 1 ? fallback : value;
    }

    private int valueOrDefault(Integer value, int fallback) {
        return value == null ? fallback : value;
    }
}
