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
        t1.color AS t1_color

    FROM t0
    FULL JOIN t1
    ON t0.product_cd = t1.product_cd
),

-- Changed_Records: Filtra i record che sono nuovi o modificati
changed_records AS (
    SELECT
        COALESCE(t1_product_cd, t0_product_cd) AS product_cd,
        COALESCE(t1_name, t0_name) AS model_name,
        COALESCE(t1_brand, t0_brand) AS brand,
        COALESCE(t1_category, t0_category) AS category,
        COALESCE(t1_price, t0_price) AS price,
        COALESCE(t1_color, t0_color) AS color,
        
        CASE
            WHEN t1_product_cd IS NULL THEN TRUE
            ELSE FALSE
        END AS is_deleted
            

    FROM joined
),

final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['product_cd']) }} AS product_id,
        product_cd,
        model_name,
        brand,
        category,
        price,
        color,
        is_deleted

    FROM changed_records
)

SELECT
    *
FROM final