-- T0: Nuovi dati in arrivo dalla sorgente
WITH 

t0 AS (
    SELECT
        *
    FROM {{ source('negozio', 'customers_t0') }}
),

-- T1: Dati correnti (La Storia Esistente, o l'ultimo stato noto)
t1 AS (
    SELECT
        *
    FROM {{ source('negozio', 'customers_t1') }}
),

-- Unioned_All: Unione di tutti i dati (storici e nuovi)
unioned_all AS (
    SELECT * FROM t0
    UNION DISTINCT
    SELECT * FROM t1
),

-- Ranked_Changes: Identifica la sequenza temporale di tutti i cambiamenti per ogni cliente
ranked_changes AS (
    SELECT
        *,

        ROW_NUMBER() OVER (
            PARTITION BY customer_cd
            ORDER BY last_update ASC
        ) AS version_number,
        
        last_update AS valid_from_date,
        
        LEAD(last_update, 1) OVER (
            PARTITION BY customer_cd
            ORDER BY last_update ASC
        ) AS next_update_date
        
    FROM unioned_all
),

-- Final_SCD2: Definisce le date di fine e i flag attivi/inattivi
final AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['customer_cd']) }} AS customer_id,
        customer_cd,
        name,
        email,
        city,
        member_since,
        valid_from_date,
        
        COALESCE(next_update_date,'9999-12-31'::DATE) AS valid_to_date,
        
        CASE 
            WHEN next_update_date IS NULL THEN TRUE
            ELSE FALSE
        END AS is_current
        
    FROM ranked_changes
    WHERE is_deleted IS NULL
)

SELECT
    *
FROM final