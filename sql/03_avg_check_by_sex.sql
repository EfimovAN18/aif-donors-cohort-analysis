-- =====================================================================
-- 03. Количество заказов и средний чек в разрезе пола
-- Период: весь объём данных. Только оплаченные заказы.
--
-- В таблице order одна строка = позиция заказа, а OrderTotalPrice —
-- сумма всего заказа. Чтобы сумма заказа не задваивалась при нескольких
-- позициях, сначала сворачиваем данные до уровня заказа.
-- =====================================================================

WITH paid_orders AS (
    SELECT
        o."OrderIdsMindboxId"          AS order_id,
        MAX(d."CustomerSex")           AS customer_sex,
        MAX(o."OrderTotalPrice")       AS order_total
    FROM aif_data.order    AS o
    JOIN aif_data.id_donor AS d
      ON o."OrderCustomerIdsMindboxId" = d."CustomerIdsMindboxId"
    WHERE o."OrderLineStatusIdsExternalId" = 'Paid'
      AND d."CustomerSex" IS NOT NULL
    GROUP BY 1
)

SELECT
    customer_sex                         AS "Пол",
    COUNT(*)                             AS "Количество заказов",
    ROUND(AVG(order_total)::numeric, 2)  AS "Средний чек"
FROM paid_orders
GROUP BY 1
ORDER BY 2 DESC;
