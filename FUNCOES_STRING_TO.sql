CREATE OR REPLACE FUNCTION fn_aux_ChartoInt(columnConvert character varying)
RETURNS int4 AS
$BODY$
SELECT CASE WHEN trim($1) SIMILAR TO '[0-9]+'
    THEN CAST(trim($1) AS int4)
ELSE NULL END;
$BODY$
LANGUAGE 'sql' IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION fn_aux_ChartoDate(columnConvert character varying)
RETURNS date AS
$BODY$
SELECT CASE WHEN trim($1) SIMILAR TO '[0-9]+'
    THEN CAST(trim($1) AS date)
ELSE NULL END;
$BODY$
LANGUAGE 'sql' IMMUTABLE STRICT;

ALTER TABLE public.tabela
ALTER COLUMN coluna TYPE int4 USING fn_aux_ChartoInt(coluna);

ALTER TABLE public.tabela
ALTER COLUMN coluna_data TYPE date USING fn_aux_ChartoDate(coluna_data);
