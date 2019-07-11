-- Server version
SHOW SERVER_VERSION;

-- Version details
SELECT version();

-- Installed extensions
SELECT *
FROM pg_extension
ORDER BY extname;

SELECT *
FROM pg_available_extensions
ORDER BY name;

-- region Install out-of-the-box extensions: postgresql96-contrib
CREATE EXTENSION postgres_fdw;
CREATE EXTENSION dblink;
CREATE EXTENSION pg_buffercache;
CREATE EXTENSION fuzzystrmatch;
-- endregion

-- region Install third-party extensions
-- TBD could not install with Postgres 11
CREATE EXTENSION pg_dropcache;
-- endregion

-- Cache, ordered by the number of buffers
SELECT pn.nspname AS schema, pc.relname, count(1) AS buffers, sum(pb.isdirty :: INT) AS dirty_pages
FROM pg_buffercache pb
JOIN pg_class pc ON pb.relfilenode = pg_relation_filenode(pc.oid) --
    AND pb.reldatabase IN(0,
                          (SELECT oid
                           FROM pg_database
                           WHERE datname = current_database()))
JOIN pg_namespace pn ON pn.oid = pc.relnamespace
GROUP BY pc.relname, pn.nspname
ORDER BY buffers DESC;

-- Cache by object names
SELECT pn.nspname AS schema, pc.relname, count(1) AS buffers, sum(pb.isdirty :: INT) AS dirty_pages
FROM pg_buffercache pb
JOIN pg_class pc ON pb.relfilenode = pg_relation_filenode(pc.oid) --
    AND pb.reldatabase IN(0,
                          (SELECT oid
                           FROM pg_database
                           WHERE datname = current_database()))
JOIN pg_namespace pn ON pn.oid = pc.relnamespace
WHERE pc.relname SIMILAR TO '(wos_|dataset)%'
GROUP BY pc.relname, pn.nspname
ORDER BY relname;

-- Drop cache by object(s)
SELECT pg_drop_rel_cache('wos_references'), pg_drop_rel_cache('wos_references_pk');