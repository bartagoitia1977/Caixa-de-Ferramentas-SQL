-- Anonimizador de nomes

CREATE OR REPLACE PROCEDURE anonymize_names(
    table_name TEXT,
    column_name TEXT,
    batch_size INT DEFAULT 1000
)
LANGUAGE plpgsql
AS $$
DECLARE
    total_rows INT;
    processed_rows INT := 0;
    anonymized_name TEXT;
    update_query TEXT;
    random_seed INT;
BEGIN
    -- Validar tabela
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = anonymize_names.table_name 
        AND column_name = anonymize_names.column_name
    ) THEN
        RAISE EXCEPTION 'Tabela %.% nao existe', table_name, column_name;
    END IF;

    -- Total de linhas a processar
    EXECUTE format('SELECT COUNT(*) FROM %I', table_name) INTO total_rows;
    
    RAISE NOTICE 'Iniciando anonimizacao de %.%. Numero total de linhas: %', 
        table_name, column_name, total_rows;
    
    -- Processamento em lotes para evitar lock na tabela
    WHILE processed_rows < total_rows LOOP
        -- Gerar semente randomica para garantir consistencia
        random_seed := floor(extract(epoch FROM now())) + processed_rows;
        
        -- Criar query de update com nomes anonimos
        update_query := format('
            WITH cte AS (
                SELECT ctid, %I, 
                       CASE 
                         WHEN %I IS NULL OR trim(%I) = '''' THEN NULL
                         ELSE ''Anonimo '' || (''Fulano de Tal '' || 
                              (row_number() OVER () + %s) %% 10 + 1) ||
                              CASE (row_number() OVER () + %s) %% 4
                                WHEN 0 THEN '' Filho''
                                WHEN 1 THEN '' Pai''
                                WHEN 2 THEN '' Neto''
                                ELSE ''''
                              END)
                       END AS new_name
                FROM %I
                WHERE %I IS DISTINCT FROM NULL AND trim(%I) != ''''
                ORDER BY ctid
                LIMIT %s
                OFFSET %s
            )
            UPDATE %I t
            SET %I = c.new_name
            FROM cte c
            WHERE t.ctid = c.ctid',
            column_name, column_name, column_name, 
            random_seed, random_seed,
            table_name, column_name, column_name,
            batch_size, processed_rows,
            table_name, column_name
        );
        
        EXECUTE update_query;
        
        GET DIAGNOSTICS processed_rows = ROW_COUNT;
        processed_rows := processed_rows + processed_rows;
        
        RAISE NOTICE 'Processed % rows (total: %/% %)', 
            processed_rows, processed_rows, total_rows;
        
        COMMIT; -- da COMMIT nos lotes para prevenir locks
        
        -- Pequeno atraso para reduzir a carga do sistema
        PERFORM pg_sleep(0.1);
    END LOOP;
    
    RAISE NOTICE 'Anonimizacao de %.% finalizada. Total de linhas processadas: %', 
        table_name, column_name, total_rows;
END;
$$;

-- Uso da procedure

CALL anonymize_names('paciente', 'nome_completo');

-- Opcional tamanho do lote

CALL anonymize_names('clientes', 'nome', 500);

-- Customizacao dentro da query update (dinamica)

ELSE (ARRAY['Anonymous','User','Test User','Temp User'])[(random()*3)::INT + 1] || 
     ' ' || (row_number() OVER () + %s) %% 1000