-- create list of scps common to all 11 years (intersection)
CREATE TABLE theta_plus.imm_85_95_common_scps tablespace theta_plus_tbs AS
with cte as (select scp from imm1985_nodes INTERSECT
select scp from imm1986_nodes INTERSECT
select scp from imm1987_nodes INTERSECT
select scp from imm1988_nodes INTERSECT
select scp from imm1989_nodes INTERSECT
select scp from imm1990_nodes INTERSECT
select scp from imm1990_nodes INTERSECT
select scp from imm1991_nodes INTERSECT
select scp from imm1992_nodes INTERSECT
select scp from imm1993_nodes INTERSECT
select scp from imm1994_nodes INTERSECT
select scp from imm1995_nodes) select * from cte;

CREATE INDEX imm1985_citing_cited_idx ON theta_plus.imm1985_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1986_citing_cited_idx ON theta_plus.imm1986_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1987_citing_cited_idx ON theta_plus.imm1987_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1988_citing_cited_idx ON theta_plus.imm1988_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1989_citing_cited_idx ON theta_plus.imm1989_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1990_citing_cited_idx ON theta_plus.imm1990_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1991_citing_cited_idx ON theta_plus.imm1991_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1992_citing_cited_idx ON theta_plus.imm1992_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1993_citing_cited_idx ON theta_plus.imm1993_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1994_citing_cited_idx ON theta_plus.imm1994_citing_cited(citing,cited) TABLESPACE index_tbs;
CREATE INDEX imm1995_citing_cited_idx ON theta_plus.imm1995_citing_cited(citing,cited) TABLESPACE index_tbs;
-- create union of edge lists across 11 years

DROP TABLE IF EXISTS theta_plus.imm_85_95_citing_cited;
CREATE TABLE theta_plus.imm_85_95_citing_cited TABLESPACE theta_plus_tbs AS
SELECT * FROM imm1985_citing_cited UNION
SELECT * FROM imm1986_citing_cited UNION
SELECT * FROM imm1987_citing_cited UNION
SELECT * FROM imm1988_citing_cited UNION
SELECT * FROM imm1989_citing_cited UNION
SELECT * FROM imm1990_citing_cited UNION
SELECT * FROM imm1991_citing_cited UNION
SELECT * FROM imm1992_citing_cited UNION
SELECT * FROM imm1993_citing_cited UNION
SELECT * FROM imm1994_citing_cited UNION
SELECT * FROM imm1995_citing_cited;