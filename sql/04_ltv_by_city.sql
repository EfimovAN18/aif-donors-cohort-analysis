-- =====================================================================
-- 04. LTV благотворителей: Москва, Санкт-Петербург, Екатеринбург
-- LTV = суммарные оплаченные пожертвования / число благотворителей
-- за весь период данных. У многих доноров город не указан,
-- поэтому выборка небольшая.
-- =====================================================================

WITH paid_orders AS (                 -- уровень заказа, без задвоения сумм
    SELECT
        o."OrderIdsMindboxId"              AS order_id,
        MAX(o."OrderCustomerIdsMindboxId") AS user_id,
        MAX(d."CustomerAreaName")          AS city,
        MAX(o."OrderTotalPrice")           AS order_total
    FROM aif_data.order    AS o
    JOIN aif_data.id_donor AS d
      ON o."OrderCustomerIdsMindboxId" = d."CustomerIdsMindboxId"
    WHERE o."OrderLineStatusIdsExternalId" = 'Paid'
      AND d."CustomerAreaName" IN ('Москва', 'Санкт-Петербург', 'Екатеринбург')
    GROUP BY 1
)

SELECT
    city                                                     AS "Город",
    COUNT(DISTINCT user_id)                                  AS "Количество благотворителей",
    COUNT(*)                                                 AS "Количество заказов",
    ROUND(AVG(order_total)::numeric, 2)                      AS "Средний чек",
    ROUND((SUM(order_total) / COUNT(DISTINCT user_id))::numeric, 2) AS "LTV"
FROM paid_orders
GROUP BY 1
ORDER BY "LTV" DESC;
