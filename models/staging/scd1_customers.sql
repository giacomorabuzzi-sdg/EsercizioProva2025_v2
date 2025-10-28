-- T0: Nuovi dati in arrivo dalla sorgente
WITH 

t0 AS (
    SELECT
        *
    
    FROM {{ source('negozio', 'customers_t0') }}
),

-- T1: Dati correnti
t1 AS (
    SELECT
        *
    
    FROM {{ source('negozio', 'customers_t1') }}
),

-- Unioned: Unione dei dati T0 e T1
unioned AS (
    SELECT * FROM t0
    UNION ALL
    SELECT * FROM t1
),


-- Most_Recent: Identifica il record più recente per ogni cliente
most_recent AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_cd
            ORDER BY last_update DESC
        ) as rn
    FROM unioned
),

-- Final: SCD 1 - Seleziona solo il record con rn = 1
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['customer_cd']) }} AS customer_id,
        customer_cd,
        name,
        email,
        city,
        member_since,
        last_update,
        case
            when (is_deleted) is null then false
            else true end as is_deleted
    
    FROM most_recent
    WHERE rn = 1
)


SELECT
    *
FROM final