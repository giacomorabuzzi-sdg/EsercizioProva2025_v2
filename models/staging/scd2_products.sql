-- T0: Nuovi dati in arrivo dalla sorgente
WITH 

t0 AS (
    SELECT
        *
    FROM {{ source('negozio', 'products_t0') }}
),

-- T1: Dati correnti
t1 AS (
    SELECT
        *
    FROM {{ source('negozio', 'products_t1') }}
),

-- Full join T0 e T1 per identificare i record modificati o nuovi
joined AS (
    SELECT
        t0.product_cd AS t0_product_cd,
        t1.product_cd AS t1_product_cd,
        t0.model_name as t0_name,
        t1.model_name AS t1_name,
        t0.brand AS t0_brand,
        t1.brand AS t1_brand,
        t0.category AS t0_category,
        t1.category AS t1_category,
        t0.list_price AS t0_price,
        t1.list_price AS t1_price,
        t0.color AS t0_color,
        t1.color AS t1_color,
        
        CASE 
            WHEN t1.product_cd IS NULL THEN TRUE
            ELSE FALSE END AS is_deleted,

        CASE
            WHEN t0.product_cd IS NOT NULL AND t1.product_cd IS NOT NULL
            AND t0.model_name = t1.model_name
            AND t0.brand = t1.brand
            AND t0.category = t1.category
            AND t0.list_price = t1.list_price
            AND t0.color = t1.color
            THEN TRUE
            ELSE FALSE END AS is_identical

    FROM t0
    FULL JOIN t1
    ON t0.product_cd = t1.product_cd
),

--- UNPIVOT: Trasforma il join in una singola colonna per sorgente
unpivoted AS (

    SELECT 
        t0_product_cd AS product_cd,
        t0_name AS model_name,
        t0_brand AS brand,
        t0_category AS category,
        t0_price AS price,
        t0_color AS color,
        is_deleted,
        FALSE AS is_current
    FROM joined,
    WHERE t0_product_cd IS NOT NULL
        AND is_identical = FALSE
    
    UNION ALL

    SELECT 
        t1_product_cd AS product_cd,
        t1_name AS model_name,
        t1_brand AS brand,
        t1_category AS category,
        t1_price AS price,
        t1_color AS color,
        is_deleted,
        TRUE AS is_current
    FROM joined,
    WHERE t1_product_cd IS NOT NULL
),

final as (
    select 
        {{ dbt_utils.generate_surrogate_key(['product_cd']) }} AS product_id,
        product_cd,
        model_name,
        brand,
        category,
        price,
        color,
        is_current
    from unpivoted
)

SELECT
*
FROM final