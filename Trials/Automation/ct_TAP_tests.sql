/*
 Title: Scopus-update TAP-test
 Author: Djamil Lakhdar-Hamina
 Date: 07/23/2019
 Purpose: Develop a TAP protocol to test if the scopus_update parser is behaving as intended.
 TAP protocol specifies that you determine a set of assertions with binary-semantics. The assertion is evaluated either true or false.
 The evaluation should allow the client or user to understand what the problem is and to serve as a guide for diagnostics.
 The assertions to test are:
 1. do expected tables exist
 2. do all tables have at least a UNIQUE INDEX
 3. do any of the tables have columns that are 100% NULL
 4. for various tables was there an increase
*/

\set ON_ERROR_STOP on
\set ECHO all

-- public has to be used in search_path to find pgTAP routines
SET search_path = public;

--DO blocks don't accept any parameters. In order to pass a parameter, use a custom session variable AND current_settings
-- https://github.com/NETESOLUTIONS/tech/wiki/Postgres-Recipes#Passing_psql_variables_to_DO_blocks
--for more:https://stackoverflow.com/questions/24073632/passing-argument-to-a-psql-procedural-script
set script.module_name = :'module_name';

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

DO
$block$
    DECLARE
        tab RECORD;
    BEGIN
        FOR tab IN (
            SELECT table_name
            FROM information_schema.tables --
            WHERE table_schema = current_schema
              AND table_name LIKE current_setting('script.module_name') || '%'
        )
            LOOP
                EXECUTE format('ANALYZE VERBOSE %I;', tab.table_name);
            END LOOP;
    END
$block$;

SELECT *
FROM no_plan();

-- region all ct_ tables exist
SELECT has_table(:'module_name' || '_clinical_studies');
SELECT has_table(:'module_name' || '_arm_groups');
SELECT has_table(:'module_name' || '_collaborators');
SELECT has_table(:'module_name' || '_condition_browses');
SELECT has_table(:'module_name' || '_conditions');
SELECT has_table(:'module_name' || '_expanded_access_info');
SELECT has_table(:'module_name' || '_intervention_arm_group_labels');
SELECT has_table(:'module_name' || '_intervention_browses');
SELECT has_table(:'module_name' || '_intervention_other_names');
SELECT has_table(:'module_name' || '_interventions');
SELECT has_table(:'module_name' || '_keywords');
SELECT has_table(:'module_name' || '_links');
SELECT has_table(:'module_name' || '_location_countries');
SELECT has_table(:'module_name' || '_location_investigators');
SELECT has_table(:'module_name' || '_locations');
SELECT has_table(:'module_name' || '_outcomes');
SELECT has_table(:'module_name' || '_overall_contacts');
SELECT has_table(:'module_name' || '_overall_officials');
SELECT has_table(:'module_name' || '_publications');
SELECT has_table(:'module_name' || '_references');
SELECT has_table(:'module_name' || '_secondary_ids');
SELECT has_table(:'module_name' || '_study_design_info');
BEGIN;
-- endregion

--region all scopus tables have at least a UNIQUE INDEX
SELECT is_empty($$
 SELECT current_schema || '.' || tablename
  FROM pg_catalog.pg_tables tbls
 WHERE schemaname= current_schema AND tablename LIKE 'ct_%'
   AND NOT EXISTS(SELECT *
                    FROM pg_indexes idx
                   WHERE idx.schemaname = current_schema
                     AND idx.tablename = tbls.tablename
                     and idx.indexdef like 'CREATE UNIQUE INDEX%')$$,
                'All CT tables should have at least a UNIQUE INDEX');
-- endregion

-- region Are any tables completely null for every field
SELECT is_empty($$
  SELECT current_schema || '.' || tablename || '.' || attname AS not_populated_column
    FROM pg_stats
  WHERE schemaname = current_schema AND tablename LIKE 'ct_%' AND null_frac = 1$$,
                'All CT table columns should be populated (not 100% NULL)');
-- endregion


-- region are all tables populated

DO
$block$
    DECLARE
        tab RECORD;
    BEGIN
        FOR tab IN (
            SELECT table_name
            FROM information_schema.tables --
            WHERE table_schema = current_schema
              AND table_name LIKE current_setting('script.module_name') || '%'
        )
            LOOP
                EXECUTE format('ANALYZE VERBOSE %I;', tab.table_name);
            END LOOP;
    END
$block$;


WITH cte AS (
    SELECT parent_pc.relname, sum(coalesce(partition_pc.reltuples, parent_pc.reltuples)) AS total_rows
    FROM pg_class parent_pc
             JOIN pg_namespace pn ON pn.oid = parent_pc.relnamespace AND pn.nspname = current_schema
             LEFT JOIN pg_inherits pi ON pi.inhparent = parent_pc.oid
             LEFT JOIN pg_class partition_pc ON partition_pc.oid = pi.inhrelid
    WHERE parent_pc.relname LIKE :'module_name' || '%'
      AND parent_pc.relkind IN ('r', 'p')
      AND NOT parent_pc.relispartition
    GROUP BY parent_pc.oid, parent_pc.relname
)
SELECT cmp_ok(CAST(cte.total_rows AS BIGINT), '>=', CAST(:min_num_of_records AS BIGINT),
              format('%s.%s table should have at least %s record%s', current_schema, cte.relname, :min_num_of_records,
                     CASE WHEN :min_num_of_records > 1 THEN 's' ELSE '' END))
FROM cte;
-- endregion

--region show update log
SELECT id, num_nct, last_updated
FROM update_log_:module_name
WHERE num_nct IS NOT NULL
ORDER BY id DESC
LIMIT 10;
--endregion

-- region is there a decrease in records
WITH cte AS (
    SELECT num_nct, lead(num_nct, 1, 0) OVER (ORDER BY id DESC) AS prev_num_nct
    FROM update_log_:module_name
    WHERE num_nct IS NOT NULL
    ORDER BY id DESC
    LIMIT 1
)
SELECT cmp_ok(cte.num_nct, '>=', cte.prev_num_nct,
              'The number of CT records should not decrease after an update')
FROM cte;
-- endregion

--region show rows per year
SELECT clinical_studies.study_start_year,
       count(clinical_studies.nct_id )  count_nct,
       coalesce(count(nct_id) -
                lag(count(nct_id)) over (order by clinical_studies.study_start_year),
                '0')                         as difference,
       coalesce(round(100.0*(count(nct_id) -
                lag(count(nct_id)) over (order by clinical_studies.study_start_year))/ lag(count(nct_id)) over (order by clinical_studies.study_start_year),2),
                '0')                         as percent_difference
FROM
      (SELECT ccs.*, start_year.study_start_year
      FROM ct_clinical_studies ccs
      JOIN (SELECT nct_id,
            CASE
            WHEN (start_date ~ ',') THEN extract('year' FROM to_date(start_date, 'Month DD, YYYY'))::int
            WHEN (start_date !~ ',') THEN extract('year' FROM to_date(start_date, 'Month YYYY'))::int END study_start_year
            FROM ct_clinical_studies) start_year
          ON ccs.nct_id = start_year.nct_id) clinical_studies
WHERE clinical_studies.study_start_year BETWEEN 1981 AND extract(YEAR FROM current_date - INTERVAL '1 year')::INT
GROUP BY clinical_studies.study_start_year
ORDER BY clinical_studies.study_start_year;
--endregion

--region do clinical trials increase year by year
WITH cte as (SELECT clinical_studies.study_start_year,
                     count(clinical_studies.nct_id )  count_nct,
                     coalesce(count(nct_id) -
                              lag(count(nct_id)) over (order by clinical_studies.study_start_year),
                              '0')                         as difference,
                     coalesce(round(100.0*(count(nct_id) -
                              lag(count(nct_id)) over (order by clinical_studies.study_start_year))/ lag(count(nct_id)) over (order by clinical_studies.study_start_year),2),
                              '0')                         as percent_difference
              FROM
                    (SELECT ccs.*, start_year.study_start_year
                    FROM ct_clinical_studies ccs
                    JOIN (SELECT nct_id,
                          CASE
                          WHEN (start_date ~ ',') THEN extract('year' FROM to_date(start_date, 'Month DD, YYYY'))::int
                          WHEN (start_date !~ ',') THEN extract('year' FROM to_date(start_date, 'Month YYYY'))::int END study_start_year
                          FROM ct_clinical_studies) start_year
                        ON ccs.nct_id = start_year.nct_id) clinical_studies
              WHERE clinical_studies.study_start_year BETWEEN 1981 AND extract(YEAR FROM current_date - INTERVAL '1 year')::INT
              GROUP BY clinical_studies.study_start_year
              ORDER BY clinical_studies.study_start_year)
              SELECT cmp_ok(CAST(cte.percent_difference AS BIGINT), '>=',
              CAST(:min_yearly_difference AS BIGINT),
              format('CT Clinical Studies table should increase by at least %s per cent of records year on year', :min_yearly_difference))
FROM cte;
--endregion


-- region are there records in the future
SELECT is_empty($$SELECT clinical_studies.verify_year,
                           coalesce(count(clinical_studies.nct_id) -
                                    lag(count(clinical_studies.nct_id)) over (order by clinical_studies.verify_year),
                                                 '0')         as difference
                    FROM
                          (SELECT ccs.*, start_year.verify_year
                          FROM ct_clinical_studies ccs
                          JOIN (SELECT nct_id,
                                CASE
                                WHEN (verification_date ~ ',') THEN extract('year' FROM to_date(verification_date, 'Month DD, YYYY'))::int
                                WHEN (verification_date !~ ',') THEN extract('year' FROM to_date(verification_date, 'Month YYYY'))::int END verify_year
                                FROM ct_clinical_studies) start_year
                              ON ccs.nct_id = start_year.nct_id) clinical_studies
                    WHERE clinical_studies.verify_year >= extract(YEAR FROM date_trunc('year', current_date + INTERVAL '2 year')::date)
                    GROUP BY clinical_studies.verify_year
                    ORDER BY clinical_studies.verify_year;$$,
                  'There should be no CT records two years from present');

-- endregion

SELECT *
FROM finish();
ROLLBACK;

-- END OF SCRIPT
