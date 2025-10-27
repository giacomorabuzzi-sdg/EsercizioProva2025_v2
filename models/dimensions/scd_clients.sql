{{
    config(
        materialized='incremental',
        unique_key=['customer_id'],
        incremental_strategy='merge'
    )
}}

-- T1: Nuovi dati (o dati potenzialmente aggiornati) in arrivo dallo staging
-- La data di cambiamento viene sempre generata in questa CTE.
WITH new_data AS (
    SELECT
        customer_id,
        name,
        email,
        city,
        member_since,
        -- Usiamo current_timestamp() per tracciare il momento dell'esecuzione, essenziale per l'audit
         current_timestamp() AS change_date 
    
    FROM {{ ref('stg_cli') }}
)



{% if is_incremental() %}

-- Modalità INCREMENTALE: Esegui il confronto (JOIN)
, current_data AS (
    SELECT
        customer_id,
        customer_name AS name, 
        customer_email AS email,
        customer_city AS city,
        customer_member_since AS member_since,
        last_changed_date AS old_last_changed_date

    FROM {{ this }}
),

changes AS (
    SELECT
        COALESCE(t1.customer_id, t0.customer_id) AS customer_id,
        t1.name AS new_name,
        t0.name AS old_name,
        t1.email AS new_email,
        t0.email AS old_email,
        t1.city AS new_city,
        t0.city AS old_city,
        t1.member_since AS new_member_since,
        t0.member_since AS old_member_since,
        t0.old_last_changed_date AS old_last_changed_date
    FROM new_data AS t1
    FULL JOIN current_data AS t0
        ON t1.customer_id = t0.customer_id
)

SELECT
    c.customer_id,
    COALESCE(c.new_name, c.old_name) AS customer_name,
    COALESCE(c.new_email, c.old_email) AS customer_email,
    COALESCE(c.new_city, c.old_city) AS customer_city,
    COALESCE(c.new_member_since, c.old_member_since) AS customer_member_since,
    
    CASE
        WHEN c.old_name IS NULL THEN 'Inserted'
        WHEN c.new_name IS NULL THEN 'Deleted'
        -- Confronta OGNI campo per rilevare l'aggiornamento
        WHEN c.old_name != c.new_name
             OR c.old_email != c.new_email
             OR c.old_city != c.new_city
             OR c.old_member_since != c.new_member_since
             THEN 'Updated'
        ELSE 'No Change'
    END AS record_status,
    
    CASE
        -- Se è un Inserted o Updated, usa il timestamp corrente.
        WHEN c.old_name IS NULL
             OR c.old_name != c.new_name
             OR c.old_email != c.new_email
             OR c.old_city != c.new_city
             OR c.old_member_since != c.new_member_since THEN current_timestamp()
        -- Se è un Deleted o No Change, usa il timestamp ESISTENTE (old_last_changed_date).
        ELSE c.old_last_changed_date 
    END AS last_changed_date

FROM changes AS c

-- Filtra il delta che deve essere applicato con la strategia MERGE
WHERE
    record_status IN ('Inserted', 'Updated', 'Deleted')

{% else %}

-- Modalità FULL REFRESH (Prima run)
SELECT
    customer_id,
    name AS customer_name,
    email AS customer_email,
    city AS customer_city,
    member_since AS customer_member_since,
    'Inserted' AS record_status,
    change_date AS last_changed_date
FROM new_data

{% endif %}