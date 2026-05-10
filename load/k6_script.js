import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const writeOnly = (__ENV.WRITE_ONLY || 'false').toLowerCase() === 'true';
const baseUrl = __ENV.BASE_URL || 'http://workload:8080';
const seedCount = Number(__ENV.SEED_COUNT || 50000);
const maxUsers = Number(__ENV.MAX_USER_ID || seedCount);
const maxSkus = Number(__ENV.MAX_SKU_ID || Math.max(1, Math.floor(seedCount / 2)));
const maxOrders = Number(__ENV.MAX_ORDER_ID || seedCount * 2);
const maxSellerOrders = Number(__ENV.MAX_SELLER_ORDER_ID || seedCount * 4);

const oltpOrderRead = new Trend('oltp_order_read_latency', true);
const oltpCartWrite = new Trend('oltp_cart_write_latency', true);
const oltpInventoryUpdate = new Trend('oltp_inventory_update_latency', true);
const olapSellerRevenue = new Trend('olap_seller_revenue_latency', true);
const olapCatalogHealth = new Trend('olap_catalog_health_latency', true);
const logStatusInsert = new Trend('log_status_insert_latency', true);
const logEventInsert = new Trend('log_event_insert_latency', true);

const fullStages = [
  { duration: __ENV.RAMP_UP || '1m', target: Number(__ENV.TARGET || 10) },
  { duration: __ENV.PLATEAU || '3m', target: Number(__ENV.TARGET || 10) },
  { duration: __ENV.RAMP_DOWN || '30s', target: 0 }
];

export const options = writeOnly
  ? {
      scenarios: {
        writes: {
          executor: 'constant-vus',
          vus: Number(__ENV.WRITE_VUS || 10),
          duration: __ENV.WRITE_DURATION || '1m',
          exec: 'writes'
        }
      }
    }
  : {
      scenarios: {
        oltp: {
          executor: 'ramping-vus',
          stages: fullStages,
          exec: 'oltp'
        },
        olap: {
          executor: 'ramping-vus',
          stages: fullStages,
          exec: 'olap'
        },
        logs: {
          executor: 'ramping-vus',
          stages: fullStages,
          exec: 'logs'
        }
      }
    };

export function oltp() {
  readOrder();
  writeCartItem();
  updateInventory();
  sleep(0.2);
}

export function olap() {
  readSellerRevenue();
  readCatalogHealth();
  sleep(1);
}

export function logs() {
  insertStatus();
  insertEvent();
  sleep(0.1);
}

export function writes() {
  writeCartItem();
  updateInventory();
  insertStatus();
  insertEvent();
  sleep(0.1);
}

function readOrder() {
  const orderId = randomInt(1, maxOrders);
  const response = http.get(`${baseUrl}/api/oltp/orders/${orderId}`, {
    tags: { profile: 'oltp', endpoint: 'oltp_order_read' }
  });
  record(response, oltpOrderRead);
}

function writeCartItem() {
  const payload = JSON.stringify({
    userId: randomInt(1, maxUsers),
    skuId: randomInt(1, maxSkus),
    qty: randomInt(1, 3)
  });
  const response = http.post(`${baseUrl}/api/oltp/cart-items`, payload, jsonParams('oltp', 'oltp_cart_write'));
  record(response, oltpCartWrite);
}

function updateInventory() {
  const payload = JSON.stringify({
    skuId: randomInt(1, maxSkus),
    delta: randomInt(-3, 5)
  });
  const response = http.patch(`${baseUrl}/api/oltp/inventory`, payload, jsonParams('oltp', 'oltp_inventory_update'));
  record(response, oltpInventoryUpdate);
}

function readSellerRevenue() {
  const fromDaysAgo = randomInt(120, 365);
  const toDaysAgo = randomInt(0, 30);
  const response = http.get(`${baseUrl}/api/olap/seller-revenue?fromDaysAgo=${fromDaysAgo}&toDaysAgo=${toDaysAgo}&limit=50`, {
    tags: { profile: 'olap', endpoint: 'olap_seller_revenue' }
  });
  record(response, olapSellerRevenue);
}

function readCatalogHealth() {
  const minPrice = randomInt(50, 200);
  const maxPrice = randomInt(500, 1000);
  const response = http.get(`${baseUrl}/api/olap/catalog-health?minPrice=${minPrice}&maxPrice=${maxPrice}&minQty=100&limit=50`, {
    tags: { profile: 'olap', endpoint: 'olap_catalog_health' }
  });
  record(response, olapCatalogHealth);
}

function insertStatus() {
  const statuses = ['new', 'paid', 'shipped', 'cancelled'];
  const payload = JSON.stringify({
    sellerOrderId: randomInt(1, maxSellerOrders),
    statusCode: statuses[randomInt(0, statuses.length - 1)]
  });
  const response = http.post(`${baseUrl}/api/log/status`, payload, jsonParams('log', 'log_status_insert'));
  record(response, logStatusInsert);
}

function insertEvent() {
  const types = ['status_changed', 'cart_changed', 'inventory_changed'];
  const payload = JSON.stringify({
    eventType: types[randomInt(0, types.length - 1)],
    sellerOrderId: randomInt(1, maxSellerOrders),
    userId: randomInt(1, maxUsers)
  });
  const response = http.post(`${baseUrl}/api/log/events`, payload, jsonParams('log', 'log_event_insert'));
  record(response, logEventInsert);
}

function record(response, trend) {
  trend.add(response.timings.duration);
  check(response, {
    'status is 2xx': r => r.status >= 200 && r.status < 300
  });
}

function jsonParams(profile, endpoint) {
  return {
    headers: { 'Content-Type': 'application/json' },
    tags: { profile, endpoint }
  };
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}
