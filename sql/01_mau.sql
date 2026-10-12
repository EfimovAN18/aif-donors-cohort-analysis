-- =====================================================================
-- 01. MAU — ежемесячная динамика активных благотворителей
-- Активный пользователь: оплатил хотя бы одно пожертвование за месяц.
-- Период: весь объём данных (2021 — март 2024).
-- =====================================================================

SELECT
    CAST(DATE_TRUNC('month', "OrderFirstActionDateTimeUtc") AS date) AS "Месяц",
    COUNT(DISTINCT "OrderCustomerIdsMindboxId")                    AS "MAU"
FROM aif_data.order
WHERE "OrderLineStatusIdsExternalId" = 'Paid'          -- только оплаченные заказы
GROUP BY 1
ORDER BY 1;
