# Лабораторная работа 6

## Workload-сервис

Сервис находится в `workload/` и запускается отдельным контейнером `workload`. Реализация на Spring Boot, доступ к БД через `JdbcTemplate`, профиль SQL переключается переменной `WORKLOAD_SQL_PROFILE`.

| Эндпоинт | Профиль | SQL-нагрузка |
|---|---:|---|
| `GET /api/oltp/orders/{orderId}` | OLTP read | Чтение заказа с JOIN по `orders`, `users`, `addresses`, `seller_orders`, `sellers`, `order_items`, `skus`, `products` |
| `POST /api/oltp/cart-items` | OLTP write | `INSERT ... ON CONFLICT DO UPDATE` в `cart_items` |
| `PATCH /api/oltp/inventory` | OLTP write | `UPDATE inventory` |
| `GET /api/olap/seller-revenue` | OLAP | Агрегация выручки по продавцам и дням за широкий диапазон дат |
| `GET /api/olap/catalog-health` | OLAP | Агрегация каталога, остатков и цен по продавцам |
| `POST /api/log/status` | Log/Time-series | Вставка истории статуса в `seller_order_status_history` |
| `POST /api/log/events` | Log/Time-series | Вставка события в быстрорастущую `workload_events` |

Для baseline использовался `SEED_COUNT=50000`. Для деградации и оптимизации использовался `SEED_COUNT=500000`, после сидирования суммарный объем основных и исторических таблиц превысил несколько миллионов строк.

Команды прогонов:

```bash
k6 run -e BASE_URL=http://localhost:8080 -e SEED_COUNT=50000 --summary-export profiling/1/k6_summary.json load/k6_script.js
k6 run -e BASE_URL=http://localhost:8080 -e SEED_COUNT=500000 --summary-export profiling/2/k6_summary.json load/k6_script.js
k6 run -e BASE_URL=http://localhost:8080 -e SEED_COUNT=500000 --summary-export profiling/3/k6_summary.json load/k6_script.js
WRITE_ONLY=true k6 run -e BASE_URL=http://localhost:8080 -e SEED_COUNT=500000 --summary-export profiling/3/write_k6_summary.json load/k6_script.js
```

`pg_stat_statements` включен миграцией `007_pg_stat_statements`, а параметры preload добавлены в конфигурацию Patroni.

## Изменения схемы для деградации

| Миграция | Тип изменения | Содержание |
|---|---|---|
| `009_degradation_business_features` | Новая таблица с FK | `seller_order_feedback` ссылается на горячую сущность `seller_orders` |
| `009_degradation_business_features` | Nullable-колонки в горячей таблице | `priority`, `last_status_changed_at`, `total_amount` в `seller_orders` |
| workload-сервис | Усложнение запроса | В degraded-профиле `GET /api/oltp/orders/{orderId}` добавляет агрегат по `seller_order_feedback` и lateral-подзапрос по истории статусов |

## Наблюдаемая деградация

| Эндпоинт | p95 baseline, мс | p95 degraded, мс | Рост | Гипотеза |
|---|---:|---:|---:|---|
| `GET /api/oltp/orders/{orderId}` | 34.1 | 92.7 | +171.8% | В EXPLAIN появился `HashAggregate` по `seller_order_feedback` и повторный `Seq Scan` по `seller_order_status_history` внутри lateral-подзапроса. Индексов по новым путям доступа еще нет. |
| `GET /api/olap/seller-revenue` | 921.4 | 1854.9 | +101.3% | При росте объема до миллионов строк сырой `HashAggregate` и `Hash Join` читают значительно больше блоков: `shared_blks_read` вырос с 72412 до 412508. |
| `GET /api/olap/catalog-health` | 410.6 | 620.8 | +51.2% | Запрос группирует больше SKU и остатков, в EXPLAIN сохраняется широкий `Seq Scan` по `inventory` и дорогой `HashAggregate`. |
| `POST /api/log/status` | 12.2 | 31.5 | +158.2% | Помимо вставки истории degraded-профиль обновляет денормализованный `last_status_changed_at` в `seller_orders`, поэтому появляются дополнительные dirty buffers и запись в горячую строку. |
| `POST /api/log/events` | 10.4 | 14.1 | +35.6% | Быстрорастущая `workload_events` стала больше, вставки чаще затрагивают новые страницы и больше shared blocks. |

Запросы `POST /api/oltp/cart-items` и `PATCH /api/oltp/inventory` выросли менее чем на 30%, поэтому как деградировавшие не классифицировались.

## План оптимизации

| Запрос / Профиль | Проблема из EXPLAIN / pg_stat | Предлагаемое решение | Ожидаемый эффект |
|---|---|---|---|
| `GET /api/oltp/orders/{orderId}` / OLTP | Полный агрегат `seller_order_feedback`, lateral-подзапрос без индекса по `seller_order_id` | `idx_seller_order_feedback_order_created_at`, `idx_seller_order_status_history_order_changed_at`, переписать feedback на indexed lateral lookup | Убрать полные сканы новых таблиц, вернуть чтение к latency baseline |
| `GET /api/olap/seller-revenue` / OLAP | `HashAggregate` по миллионам строк `orders`, `seller_orders`, `order_items` | Материализованное представление `marketplace_daily_revenue` и индекс по `(revenue_day, seller_id)` | Перейти от агрегации фактов к чтению дневных агрегатов |
| `GET /api/olap/catalog-health` / OLAP | Широкая агрегация по каталогу и остаткам | Сохранить запрос, опереться на прогретый cache и уменьшение конкуренции со стороны revenue-запроса | Снизить p95 за счет освобождения CPU и shared buffers |
| `POST /api/oltp/cart-items` / OLTP write | Поиск активной корзины по `user_id` без специализированного индекса | `idx_carts_user_status_id` | Ускорить выбор корзины перед upsert |
| `POST /api/log/status` / Log | Дополнительное обновление `seller_orders`, растущая история статусов | Индекс истории по `(seller_order_id, changed_at DESC)` | Ускорить read-path, контролируя умеренное замедление INSERT из-за обслуживания индекса |
| `POST /api/log/events` / Log | Быстрорастущая таблица событий без временного индекса | `idx_workload_events_created_at` | Ускорить будущие временные срезы, принять небольшую цену на INSERT |

## Примененные оптимизации

| Миграция | Решение |
|---|---|
| `010_optimization_indexes` | `idx_orders_created_at_id`, `idx_seller_order_status_history_order_changed_at`, `idx_seller_order_feedback_order_created_at`, `idx_workload_events_created_at`, `idx_carts_user_status_id` |
| `011_optimization_revenue_view` | Материализованное представление `marketplace_daily_revenue` с уникальным индексом `(revenue_day, seller_id)` |
| workload-сервис | В optimized-профиле revenue-запрос читает materialized view, а order-read использует indexed lateral lookup вместо полного агрегата feedback |

После сидирования выполняется `seeds/007_refresh_optimization.seed.sql`, чтобы materialized view содержало данные свежего seed-набора.

## Проверка влияния на запись

Короткий write-only прогон после оптимизаций показал, что индексы ожидаемо добавили небольшую цену к вставкам истории и событий относительно baseline, но не вернули систему к degraded-уровню.

| Запрос записи | p95 baseline, мс | p95 optimized write-only, мс | Вывод |
|---|---:|---:|---|
| `POST /api/oltp/cart-items` | 18.3 | 20.6 | Слегка медленнее baseline из-за конкуренции на большой БД, но индекс корзин удерживает поиск активной корзины дешевым |
| `PATCH /api/oltp/inventory` | 16.5 | 17.5 | Почти baseline, оптимизации напрямую не затронули таблицу |
| `POST /api/log/status` | 12.2 | 20.8 | Медленнее baseline из-за дополнительного индекса истории и денормализованного UPDATE, но лучше degraded p95 31.5 мс |
| `POST /api/log/events` | 10.4 | 13.4 | Небольшое замедление связано с индексом `idx_workload_events_created_at` |

## Итоговая сводная таблица

| Запрос / Эндпоинт | p95 пункт 1, мс | p95 пункт 2, мс | p95 пункт 3, мс | Δ 1→2 | Δ 2→3 | Примененное решение |
|---|---:|---:|---:|---:|---:|---|
| `GET /api/oltp/orders/{orderId}` | 34.1 | 92.7 | 30.6 | +171.8% | -67.0% | Индексы feedback/history, optimized lateral lookup |
| `POST /api/oltp/cart-items` | 18.3 | 23.1 | 20.4 | +26.2% | -11.7% | `idx_carts_user_status_id` |
| `PATCH /api/oltp/inventory` | 16.5 | 18.2 | 17.0 | +10.3% | -6.6% | Побочный эффект снижения общей конкуренции |
| `GET /api/olap/seller-revenue` | 921.4 | 1854.9 | 140.7 | +101.3% | -92.4% | `marketplace_daily_revenue` |
| `GET /api/olap/catalog-health` | 410.6 | 620.8 | 318.4 | +51.2% | -48.7% | Снижение конкуренции после перевода revenue на matview |
| `POST /api/log/status` | 12.2 | 31.5 | 20.2 | +158.2% | -35.9% | Индекс истории, контролируемая цена денормализации |
| `POST /api/log/events` | 10.4 | 14.1 | 13.0 | +35.6% | -7.8% | `idx_workload_events_created_at` |
