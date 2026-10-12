-- =====================================================================
-- 02. Retention Rate когорты августа 2022 в разрезе пола
--
-- Дата регистрации (CustomerChangeDateTimeUtc) перезаписывается при
-- каждом редактировании профиля, поэтому когорту «новых» пользователей
-- построить нельзя. Вместо этого когорта — все, кто оплатил
-- пожертвование в августе 2022 (месяц крупной медийной кампании).
-- Благотворители без указанного пола исключены.
--
-- Отличия от эталонного решения курса:
--   * фильтр августа через полуинтервал [2022-08-01, 2022-09-01),
--     чтобы не терять платежи 31 августа после 00:00;
--   * номер месяца жизни считается календарно, а не делением дней на 30
--     (деление на 30 «съезжает» на длинном горизонте).
-- =====================================================================

WITH paid AS (
    SELECT
        o."OrderCustomerIdsMindboxId"                                   AS user_id,
        d."CustomerSex"                                                 AS customer_sex,
        CAST(DATE_TRUNC('month', o."OrderFirstActionDateTimeUtc") AS date) AS activity_month
    FROM aif_data.order    AS o
    JOIN aif_data.id_donor AS d
      ON o."OrderCustomerIdsMindboxId" = d."CustomerIdsMindboxId"
    WHERE o."OrderLineStatusIdsExternalId" = 'Paid'
      AND d."CustomerSex" IS NOT NULL
),

august_cohort AS (                    -- когорта: платили в августе 2022
    SELECT DISTINCT user_id, customer_sex
    FROM paid
    WHERE activity_month = DATE '2022-08-01'
),

activity AS (                         -- активность когорты с августа 2022
    SELECT DISTINCT
        p.user_id,
        p.customer_sex,
        (EXTRACT(YEAR  FROM p.activity_month) - 2022) * 12
      + (EXTRACT(MONTH FROM p.activity_month) - 8)                      AS month_since_start
    FROM paid p
    JOIN august_cohort c USING (user_id)
    WHERE p.activity_month >= DATE '2022-08-01'
),

retained AS (
    SELECT customer_sex,
           month_since_start::int AS month_since_start,
           COUNT(DISTINCT user_id) AS retained_users
    FROM activity
    GROUP BY 1, 2
)

SELECT
    customer_sex                                   AS "Пол",
    month_since_start                              AS "Месяц",
    retained_users                                 AS "Удержано пользователей",
    ROUND(retained_users::numeric
          / FIRST_VALUE(retained_users) OVER (PARTITION BY customer_sex
                                              ORDER BY month_since_start), 3)
                                                   AS "Retention Rate"
FROM retained
ORDER BY 1, 2;
