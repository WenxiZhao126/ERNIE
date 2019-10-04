\set ON_ERROR_STOP on
\set ECHO all

-- DataGrip: start execution from here
SET TIMEZONE = 'US/Eastern';

-- Drop existing tables manually before executing

-- region scopus_publication_groups
CREATE TABLE IF NOT EXISTS scopus_publication_groups (
  sgr BIGINT,
  pub_year SMALLINT,
  CONSTRAINT scopus_publication_groups_pk PRIMARY KEY (sgr) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_publication_groups IS --
  'Scopus group records. If a record from a third party is loaded and it has also been loaded for an Elsevier record,
then the two records will be delivered separately. Each record will have
it''s own unique "SCP" id, but the two records will have the same "SGR" id (indicating that both records are in fact
identical).';

COMMENT ON COLUMN scopus_publication_groups.sgr IS --
  'Scopus group id. Same as Scopus id, but a little less unique: if a record from a third party is loaded and it has
also been loaded for an Elsevier record, then the two records will be delivered separately. Each record will have
it''s own unique "SCP" id, but the two records will have the same "SGR" id (indicating that both records are in fact
identical).';

CREATE INDEX IF NOT EXISTS spg_pub_year_i ON scopus_publication_groups(pub_year) TABLESPACE index_tbs;
-- 2m:35s
-- endregion

-- region scopus_sources
CREATE TABLE IF NOT EXISTS scopus_sources (
  ernie_source_id SERIAL,
  source_id TEXT,
  issn_main TEXT,
  isbn_main TEXT,
  source_type TEXT,
  source_title TEXT,
  coden_code TEXT,
  website TEXT,
  publisher_name TEXT,
  publisher_e_address TEXT,
  pub_date DATE,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_sources_pk PRIMARY KEY (ernie_source_id) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

CREATE UNIQUE INDEX IF NOT EXISTS scopus_sources_source_id_issn_isbn_uk ON scopus_sources(source_id, issn_main, isbn_main);

COMMENT ON TABLE scopus_sources IS 'Journal source information table';

COMMENT ON COLUMN scopus_sources.ernie_source_id IS 'DB serial source id. Assigned by ernie team';

COMMENT ON COLUMN scopus_sources.source_id IS 'Journal source id. Example: 22414';

COMMENT ON COLUMN scopus_sources.issn_main IS 'The ISSN of a serial publication (print), pick the first one in xml if multiple. Example: 00028703';

COMMENT ON COLUMN scopus_sources.isbn_main IS 'The ISBN of a source (the first available isbn). Example: 0780388747';

COMMENT ON COLUMN scopus_sources.source_type IS 'Source type. Example: j for journal';

COMMENT ON COLUMN scopus_sources.source_title IS 'Journal name. Example: American Heart Journal';

COMMENT ON COLUMN scopus_sources.coden_code IS 'The CODEN code that uniquely identifies the source. Example: AHJOA';

COMMENT ON COLUMN scopus_sources.website IS 'Example: http://dl.acm.org/citation.cfm?id=111048';

COMMENT ON COLUMN scopus_sources.publisher_name IS 'Example: Oxford University Press';

COMMENT ON COLUMN scopus_sources.publisher_e_address IS 'Example: acmhelp@acm.org';
-- endregion

-- region scopus_isbns
CREATE TABLE IF NOT EXISTS scopus_isbns (
  ernie_source_id INTEGER
    CONSTRAINT sconf_ernie_source_id_fk REFERENCES scopus_sources(ernie_source_id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  isbn TEXT,
  isbn_length TEXT,
  isbn_type TEXT,
  isbn_level TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_isbns_pk PRIMARY KEY (ernie_source_id, isbn, isbn_type) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_isbns IS 'Scopus publications isbn information';

COMMENT ON COLUMN scopus_isbns.ernie_source_id IS 'DB serial source id assigned by ernie team';

COMMENT ON COLUMN scopus_isbns.isbn IS 'ISBN number. Example: 0080407749';

COMMENT ON COLUMN scopus_isbns.isbn_length IS 'ISBN length. Example: 10 or 13';

COMMENT ON COLUMN scopus_isbns.isbn_level IS 'Example: set or volume';

COMMENT ON COLUMN scopus_isbns.isbn_type IS 'Example: print or electronic';
-- endregion

-- region scopus_issns
CREATE TABLE IF NOT EXISTS scopus_issns (
  ernie_source_id INTEGER
    CONSTRAINT scopus_issn_scp_fk REFERENCES scopus_sources(ernie_source_id) --
      ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  issn TEXT,
  issn_type TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_issns_pk PRIMARY KEY (ernie_source_id, issn, issn_type) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;
-- endregion

-- region scopus_conference_events
CREATE TABLE IF NOT EXISTS scopus_conference_events (
  conf_code TEXT,
  conf_name TEXT,
  conf_address TEXT,
  conf_city TEXT,
  conf_postal_code TEXT,
  conf_start_date DATE,
  conf_end_date DATE,
  conf_number TEXT,
  conf_catalog_number TEXT,
  conf_sponsor TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_conference_events_pk PRIMARY KEY (conf_code, conf_name) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_conference_events IS 'Conference events information';

COMMENT ON COLUMN scopus_conference_events.conf_code IS 'Conference code, assigned by Elsevier DB';

COMMENT ON COLUMN scopus_conference_events.conf_name IS 'Conference name';

COMMENT ON COLUMN scopus_conference_events.conf_address IS 'Conference address';

COMMENT ON COLUMN scopus_conference_events.conf_city IS 'City of conference event';

COMMENT ON COLUMN scopus_conference_events.conf_postal_code IS 'Postal code of conference event';

COMMENT ON COLUMN scopus_conference_events.conf_start_date IS 'Conference start date';

COMMENT ON COLUMN scopus_conference_events.conf_end_date IS 'Conference end date';

COMMENT ON COLUMN scopus_conference_events.conf_number IS 'Sequence number of the conference';

COMMENT ON COLUMN scopus_conference_events.conf_catalog_number IS 'Conference catalogue number';

COMMENT ON COLUMN scopus_conference_events.conf_sponsor IS 'Conference sponsor names';
-- endregion

-- region scopus_publications
CREATE TABLE IF NOT EXISTS scopus_publications (
  scp BIGINT
    CONSTRAINT scopus_publications_pk PRIMARY KEY USING INDEX TABLESPACE index_tbs,
  sgr BIGINT
    CONSTRAINT sp_sgr_fk REFERENCES scopus_publication_groups ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  correspondence_person_indexed_name TEXT,
  correspondence_orgs TEXT,
  correspondence_city TEXT,
  correspondence_country TEXT,
  correspondence_e_address TEXT,
  -- TODO TEXT type should be refactored to an ENUM
  pub_type TEXT,
  -- TODO TEXT type should be refactored to scopus_citation_type ENUM
  citation_type TEXT,
  citation_language TEXT,
  process_stage TEXT,
  state TEXT,
  date_sort DATE,
  ernie_source_id INTEGER
)
TABLESPACE scopus_tbs;

ALTER TABLE scopus_publications
  ADD CONSTRAINT spub_source_id_issn_fk FOREIGN KEY (ernie_source_id) --
    REFERENCES scopus_sources(ernie_source_id) ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX IF NOT EXISTS sp_sgr_i ON scopus_publications(sgr) TABLESPACE index_tbs;

CREATE INDEX IF NOT EXISTS sp_ernie_source_id_i ON scopus_publications(ernie_source_id) TABLESPACE index_tbs;
-- 4m:24s

COMMENT ON TABLE scopus_publications IS 'Scopus bibliographic record';

COMMENT ON COLUMN scopus_publications.scp IS 'SCP = Scopus id, that uniquely identifies any core or dummy item.';

COMMENT ON COLUMN scopus_publications.sgr IS --
  'Scopus group id. Same as Scopus id, but a little less unique: if a record from a third party is loaded and it has
also been loaded for an Elsevier record, then the two records will be delivered separately. Each record will have
it''s own unique "SCP" id, but the two records will have the same "SGR" id (indicating that both records are in fact
identical).';

COMMENT ON COLUMN scopus_publications.correspondence_person_indexed_name IS 'Corresponding author''s full name.';

COMMENT ON COLUMN scopus_publications.correspondence_orgs IS --
  'Corresponding author''s affiliated organizations, line (\n)-separated.';

COMMENT ON COLUMN scopus_publications.correspondence_city IS 'Corresponding author''s affiliation city.';

COMMENT ON COLUMN scopus_publications.correspondence_country IS 'Corresponding author''s affiliation country.';

COMMENT ON COLUMN scopus_publications.correspondence_e_address IS 'Corresponding author''s e-mail.';

COMMENT ON COLUMN scopus_publications.pub_type IS --
  '"core" to indicate that the item is a full bibliographic record, or "dummy" to indicate that the item is a
"dummy item" generated from an unlinked reference.';

COMMENT ON COLUMN scopus_publications.citation_type IS --
  'The item type of the original document. Most items have exactly one citation-type. But the element is optional
(because the citation type is unknown for dummy items), and in the future this element will also be repeating (as
support for material from third party bibliographic databases). Item types of third party bibliographic databases
are mapped to these citation-types. The original citation-types are also delivered, in the descriptor element.
The following values are supported:
  * "ab" = Abstract Report
  * "ar" = Article
  * "bk" = Book
  * "br" = Book Review
  * "bz" = Business Article
  * "ch" = Chapter
  * "cp" = Conference Paper
  * "cr" = Conference Review
  * "di" = Dissertation
  * "ed" = Editorial
  * "er" = Erratum
  * "ip" = Article In Press
  * "le" = Letter
  * "no" = Note
  * "pa" = Patent
  * "pr" = Press Release
  * "re" = Review
  * "rp" = Report
  * "sh" = Short Survey
  * "wp" = Working Paper
';

-- endregion

-- region scopus_authors
CREATE TABLE IF NOT EXISTS scopus_authors (
  scp BIGINT
    CONSTRAINT sauth_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  author_seq SMALLINT,
  auid BIGINT,
  author_indexed_name TEXT,
  author_surname TEXT,
  author_given_name TEXT,
  author_initials TEXT,
  author_e_address TEXT,
  author_rank TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_authors_pk PRIMARY KEY (scp, author_seq) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

CREATE INDEX IF NOT EXISTS sa_author_indexed_name_i ON scopus_authors(author_indexed_name) TABLESPACE index_tbs;

COMMENT ON TABLE scopus_authors IS 'Scopus authors information of publications';

COMMENT ON COLUMN scopus_authors.scp IS 'Scopus id. Example: 36849140316';

COMMENT ON COLUMN scopus_authors.author_seq IS 'The order of the authors in the document. Example: 1';

COMMENT ON COLUMN scopus_authors.auid IS 'Author id: unique author identifier';

COMMENT ON COLUMN scopus_authors.author_indexed_name IS 'Author surname and initials';

COMMENT ON COLUMN scopus_authors.author_surname IS 'Example: Weller';

COMMENT ON COLUMN scopus_authors.author_given_name IS 'Example: Sol';

COMMENT ON COLUMN scopus_authors.author_initials IS 'Example: S.';

COMMENT ON COLUMN scopus_authors.author_e_address IS 'biyant@psych.stanford.edu';
-- endregion

-- region scopus_affiliations
CREATE TABLE IF NOT EXISTS scopus_affiliations (
  scp BIGINT
    CONSTRAINT saff_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  affiliation_no SMALLINT,
  afid BIGINT,
  dptid BIGINT,
  organization TEXT,
  city_group TEXT,
  state TEXT,
  postal_code TEXT,
  country_code TEXT,
  country TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_affiliations_pk PRIMARY KEY (scp, affiliation_no) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_affiliations IS 'Scopus affiliation information of authors';

COMMENT ON COLUMN scopus_affiliations.scp IS 'Scopus id. Example: 50349119549';

COMMENT ON COLUMN scopus_affiliations.affiliation_no IS 'Affiliation sequence in the document. Example: 1';

COMMENT ON COLUMN scopus_affiliations.afid IS 'Affiliation id. Example: 106106336';

COMMENT ON COLUMN scopus_affiliations.dptid IS 'Department id. Example: 104172073';

COMMENT ON COLUMN scopus_affiliations.organization IS 'Author organization. Example: Portsmouth and Isle,Wight Area Pathological Service';

COMMENT ON COLUMN scopus_affiliations.city_group IS 'Example: Portsmouth';

COMMENT ON COLUMN scopus_affiliations.state IS 'Example: LA';

COMMENT ON COLUMN scopus_affiliations.postal_code IS 'Example: 70118';

COMMENT ON COLUMN scopus_affiliations.country_code IS 'iso-code. Example: gbr';

COMMENT ON COLUMN scopus_affiliations.country IS 'Country name. Example: United Kingdom';
-- endregion

-- region scopus_author_affiliations
CREATE TABLE IF NOT EXISTS scopus_author_affiliations (
  scp BIGINT
    CONSTRAINT saff_mapping_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  author_seq SMALLINT,
  affiliation_no SMALLINT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_author_affiliations_pk PRIMARY KEY (scp, author_seq, affiliation_no) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

ALTER TABLE scopus_author_affiliations
  ADD CONSTRAINT scopus_scp_author_seq_fk FOREIGN KEY (scp, author_seq) REFERENCES scopus_authors(scp, author_seq) ON DELETE CASCADE;

ALTER TABLE scopus_author_affiliations
  ADD CONSTRAINT scopus_scp_affiliation_no_fk FOREIGN KEY (scp, affiliation_no) REFERENCES scopus_affiliations(scp, affiliation_no) ON DELETE CASCADE;

COMMENT ON TABLE scopus_author_affiliations IS 'Mapping table for scopus_authors and scopus_affiliations';

COMMENT ON COLUMN scopus_author_affiliations.scp IS 'Scopus id. Example: 50349119549';

COMMENT ON COLUMN scopus_author_affiliations.author_seq IS 'The order of the authors in the document. Example: 1';

COMMENT ON COLUMN scopus_author_affiliations.affiliation_no IS 'Affiliation sequence in the document. Example: 1';
-- endregion

-- region scopus_source_publication_details
CREATE TABLE IF NOT EXISTS scopus_source_publication_details (
  scp BIGINT
    CONSTRAINT spub_sources_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  issue TEXT,
  volume TEXT,
  first_page TEXT,
  last_page TEXT,
  publication_year SMALLINT,
  publication_date DATE,
  indexed_terms TEXT,
  conf_code TEXT,
  conf_name TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_source_publication_details_pk PRIMARY KEY (scp) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

ALTER TABLE scopus_source_publication_details
  ADD CONSTRAINT spub_conf_code_conf_name_fk FOREIGN KEY (conf_code, conf_name) REFERENCES scopus_conference_events(conf_code, conf_name) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS sspd_conf_name_fti ON scopus_source_publication_details USING gin(to_tsvector('english', conf_name));
-- 5m:37s

COMMENT ON TABLE scopus_source_publication_details IS 'Details of individual publication in a (journal) source';

COMMENT ON COLUMN scopus_source_publication_details.scp IS 'Scopus id. Example: 50349106526';

COMMENT ON COLUMN scopus_source_publication_details.issue IS 'Example: 5';

COMMENT ON COLUMN scopus_source_publication_details.volume IS 'Example: 40';

COMMENT ON COLUMN scopus_source_publication_details.first_page IS 'Page range. Example: 706';

COMMENT ON COLUMN scopus_source_publication_details.last_page IS 'Page range. Example: 730';

COMMENT ON COLUMN scopus_source_publication_details.publication_year IS 'Example: 1950';

COMMENT ON COLUMN scopus_source_publication_details.publication_date IS 'Example: 1950-05-20';

COMMENT ON COLUMN scopus_source_publication_details.indexed_terms IS 'Subject index terms';

COMMENT ON COLUMN scopus_source_publication_details.conf_code IS 'Conference code, assigned by Elsevier DB';

COMMENT ON COLUMN scopus_source_publication_details.conf_name IS 'Conference name';
-- endregion

-- region scopus_subjects
CREATE TABLE IF NOT EXISTS scopus_subjects (
  scp BIGINT
    CONSTRAINT ssubj_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  subj_abbr SCOPUS_SUBJECT_ABBRE_TYPE,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_subjects_pk PRIMARY KEY (scp, subj_abbr) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_subjects IS 'Journal subject abbreviations table';

COMMENT ON COLUMN scopus_subjects.scp IS 'Scopus id. Example: 37049154082';

COMMENT ON COLUMN scopus_subjects.subj_abbr IS 'Example: CHEM';
-- endregion

-- region scopus_subject_keywords
CREATE TABLE IF NOT EXISTS scopus_subject_keywords (
  scp BIGINT
    CONSTRAINT ssubj_keywords_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  subject TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_subject_keywords_pk PRIMARY KEY (scp, subject) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_subject_keywords IS 'Journal subject detailed keywords table';

COMMENT ON COLUMN scopus_subject_keywords.scp IS 'Scopus id. Example: 37049154082';

COMMENT ON COLUMN scopus_subject_keywords.subject IS 'Example: Health';
-- endregion

-- region scopus_classification_lookup
CREATE TABLE IF NOT EXISTS scopus_classification_lookup (
  class_type TEXT,
  class_code TEXT,
  description TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_classification_lookup_pk PRIMARY KEY (class_type, class_code) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_classification_lookup IS 'Classification lookup table';

COMMENT ON COLUMN scopus_classification_lookup.class_type IS 'Classification type. Example: EMCLASS';

COMMENT ON COLUMN scopus_classification_lookup.class_code IS 'Example: 17';

COMMENT ON COLUMN scopus_classification_lookup.description IS 'Example: Public Health, Social Medicine and Epidemiology';
-- endregion

-- region scopus_classes
CREATE TABLE IF NOT EXISTS scopus_classes (
  scp BIGINT
    CONSTRAINT sclass_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  class_type TEXT,
  class_code CHAR(4),
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_classes_pk PRIMARY KEY (scp, class_type, class_code) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

/*
TODO There are some FK violations, which we need to analyze.

ALTER TABLE scopus_classes ADD CONSTRAINT sc_class_type_class_code_fk FOREIGN KEY (class_type, class_code) --
    REFERENCES scopus_classification_lookup ON UPDATE CASCADE ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED;
*/

COMMENT ON TABLE scopus_classes IS 'All type of classification code of publications';

COMMENT ON COLUMN scopus_classes.scp IS 'Scopus id. Example: 37049154082';

COMMENT ON COLUMN scopus_classes.class_type IS 'Example: EMCLASS';

COMMENT ON COLUMN scopus_classes.class_code IS 'Example: 23.2.2';
-- endregion

-- region scopus_conf_proceedings
CREATE TABLE IF NOT EXISTS scopus_conf_proceedings (
  ernie_source_id INTEGER
    CONSTRAINT sconf_ernie_source_id_fk REFERENCES scopus_sources(ernie_source_id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  conf_code TEXT,
  conf_name TEXT,
  proc_part_no TEXT,
  proc_page_range TEXT,
  proc_page_count SMALLINT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_conf_proceedings_pk PRIMARY KEY (ernie_source_id, conf_code, conf_name) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

ALTER TABLE scopus_conf_proceedings
  ADD CONSTRAINT sconf_code_name_fk FOREIGN KEY (conf_code, conf_name) REFERENCES scopus_conference_events(conf_code, conf_name) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS scp_conf_code_conf_name_i ON scopus_conf_proceedings(conf_code, conf_name) --
  TABLESPACE index_tbs;
-- 0.6s

COMMENT ON TABLE scopus_conf_proceedings IS 'Conference publications information';

COMMENT ON COLUMN scopus_conf_proceedings.ernie_source_id IS 'DB serial source id. Assigned by ernie team';

COMMENT ON COLUMN scopus_conf_proceedings.conf_code IS 'Conference code, assigned by Elsevier DB';

COMMENT ON COLUMN scopus_conf_proceedings.conf_name IS 'Conference name';

COMMENT ON COLUMN scopus_conf_proceedings.proc_part_no IS 'Part number of the conference proceeding';

COMMENT ON COLUMN scopus_conf_proceedings.proc_page_range IS 'Start and end page of a conference proceeding';

COMMENT ON COLUMN scopus_conf_proceedings.proc_page_count IS 'Number of pages in a conference proceeding';
-- endregion

-- region scopus_conf_editors
CREATE TABLE IF NOT EXISTS scopus_conf_editors (
  ernie_source_id INTEGER
    CONSTRAINT seditor_ernie_source_id_fk REFERENCES scopus_sources(ernie_source_id) ON DELETE CASCADE ON UPDATE CASCADE DEFERRABLE INITIALLY DEFERRED,
  conf_code TEXT,
  conf_name TEXT,
  indexed_name TEXT,
  surname TEXT,
  degree TEXT,
  address TEXT,
  organization TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_conf_editors_pk PRIMARY KEY (ernie_source_id, conf_code, conf_name, indexed_name) --
    USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

ALTER TABLE scopus_conf_editors
  ADD CONSTRAINT seditor_code_name_fk FOREIGN KEY (conf_code, conf_name) REFERENCES scopus_conference_events(conf_code, conf_name) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS sce_conf_code_conf_name_i ON scopus_conf_editors(conf_code, conf_name) TABLESPACE index_tbs;
-- 0.3s

COMMENT ON TABLE scopus_conf_editors IS 'Conference editors information';

COMMENT ON COLUMN scopus_conf_editors.ernie_source_id IS 'DB serial source id. Assigned by ernie team';

COMMENT ON COLUMN scopus_conf_editors.conf_code IS 'Conference code';

COMMENT ON COLUMN scopus_conf_editors.conf_name IS 'Conference name';

COMMENT ON COLUMN scopus_conf_editors.indexed_name IS 'A sortable variant of the editor surname and initials';

COMMENT ON COLUMN scopus_conf_editors.surname IS 'Surname of the editor';

COMMENT ON COLUMN scopus_conf_editors.degree IS 'Degress of the editor';

COMMENT ON COLUMN scopus_conf_editors.address IS 'The address of the editors';

COMMENT ON COLUMN scopus_conf_editors.organization IS 'The organization of the editors';
-- endregion

-- region scopus_references
CREATE TABLE IF NOT EXISTS scopus_references (
  scp BIGINT
    CONSTRAINT sr_source_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  ref_sgr BIGINT,
  -- FK is possible to enable only after the complete data load
  -- CONSTRAINT sr_ref_sgr_fk REFERENCES scopus_publication_groups ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  --pub_ref_id SMALLINT,
  --citation_language TEXT,
  citation_text TEXT,
  CONSTRAINT scopus_references_pk PRIMARY KEY (scp, ref_sgr) USING INDEX TABLESPACE index_tbs
) PARTITION BY RANGE (scp)
TABLESPACE scopus_tbs;

CREATE TABLE IF NOT EXISTS scopus_references_partition_1 PARTITION OF scopus_references FOR VALUES FROM (0) TO (12500000000)
TABLESPACE scopus_tbs;

CREATE TABLE IF NOT EXISTS scopus_references_partition_2 PARTITION OF scopus_references FOR VALUES FROM (12500000001) TO (25000000000)
TABLESPACE scopus_tbs;

CREATE TABLE IF NOT EXISTS scopus_references_partition_3 PARTITION OF scopus_references FOR VALUES FROM (25000000001) TO (37500000000)
TABLESPACE scopus_tbs;

CREATE TABLE IF NOT EXISTS scopus_references_partition_4 PARTITION OF scopus_references FOR VALUES FROM (37500000001) TO (50000000000)
TABLESPACE scopus_tbs;

CREATE TABLE IF NOT EXISTS scopus_references_partition_5 PARTITION OF scopus_references FOR VALUES FROM (50000000001) TO (62500000000)
TABLESPACE scopus_tbs;

CREATE TABLE IF NOT EXISTS scopus_references_partition_6 PARTITION OF scopus_references FOR VALUES FROM (62500000001) TO (75000000000)
TABLESPACE scopus_tbs;

CREATE TABLE IF NOT EXISTS scopus_references_partition_7 PARTITION OF scopus_references FOR VALUES FROM (75000000001) TO (87500000000)
TABLESPACE scopus_tbs;

CREATE TABLE IF NOT EXISTS scopus_references_partition_8 PARTITION OF scopus_references FOR VALUES FROM (87500000001) TO (100000000000)
TABLESPACE scopus_tbs;

CREATE INDEX IF NOT EXISTS sr_ref_sgr_i ON scopus_references(ref_sgr) TABLESPACE index_tbs;

COMMENT ON TABLE scopus_references IS 'Elsevier: Scopus - Scopus references table for documents';

COMMENT ON COLUMN scopus_references.scp IS 'Scopus ID for a document. Example: 25766560';

COMMENT ON COLUMN scopus_references.ref_sgr IS 'Scopus Group ID for the referenced document. Example: 343442899';
--COMMENT ON COLUMN scopus_references.pub_ref_id IS --
--'Uniquely (and serially?) identifies a reference in the bibliography. Example: 1';
--COMMENT ON COLUMN scopus_references.citation_language IS 'The language of the cited works'
COMMENT ON COLUMN scopus_references.citation_text IS --
  'Citation text provided with a reference. Example: "Harker LA, Kadatz RA. Mechanism of action of dipyridamole. Thromb Res 1983;suppl IV:39-46."';
-- endregion

-- region scopus_publication_identifiers
-- Added by Sitaram Devarakonda 03/22/2019
-- DDL for scopus_publication_identifiers, scopus_abstracts, scopus_titles, scopus_keywords and scopus_chemicalgroups

CREATE TABLE IF NOT EXISTS scopus_publication_identifiers (
  scp BIGINT
    CONSTRAINT spi_source_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  document_id TEXT NOT NULL,
  document_id_type TEXT NOT NULL,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_publiaction_identifiers_pk PRIMARY KEY (scp, document_id_type, document_id) --
    USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

-- 42m:51s
CREATE INDEX IF NOT EXISTS spi_document_id_type_document_id_i --
  ON scopus_publication_identifiers(document_id_type, document_id) TABLESPACE index_tbs;

COMMENT ON TABLE scopus_publication_identifiers IS 'ELSEVIER: Scopus document identifiers of documents such as doi';

COMMENT ON COLUMN scopus_publication_identifiers.scp IS --
  'Scopus id that uniquely identifies document Ex: 85046115382';

COMMENT ON COLUMN scopus_publication_identifiers.document_id IS 'Document id Ex: S1322769617302901';

COMMENT ON COLUMN scopus_publication_identifiers.document_id_type IS 'Document id type Ex: PUI,SNEMB,DOI,PII etc';
-- endregion

-- region scopus_abstracts
CREATE TABLE IF NOT EXISTS scopus_abstracts (
  scp BIGINT
    CONSTRAINT sa_source_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  abstract_text TEXT,
  abstract_language TEXT NOT NULL,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_abstracts_pk PRIMARY KEY (scp, abstract_language) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_abstracts IS 'ELSEVIER: Scopus abstracts of publications';

COMMENT ON COLUMN scopus_abstracts.scp IS 'Scopus id that uniquely identifies document Ex: 85046115382';

COMMENT ON COLUMN scopus_abstracts.abstract_text IS 'Contains an abstract of the document';

COMMENT ON COLUMN scopus_abstracts.abstract_language IS 'Contains the language of the abstract';

-- endregion

-- region scopus_titles
CREATE TABLE IF NOT EXISTS scopus_titles (
  scp BIGINT
    CONSTRAINT st_source_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  title TEXT NOT NULL,
  language TEXT NOT NULL,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_titles_pk PRIMARY KEY (scp, language) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

CREATE INDEX IF NOT EXISTS st_title_fti ON scopus_titles USING gin(to_tsvector('english', title));

COMMENT ON TABLE scopus_titles IS 'ELSEVIER: Scopus title of publications';

COMMENT ON COLUMN scopus_titles.scp IS 'Scopus id that uniquely identifies document Ex: 85046115382';

COMMENT ON COLUMN scopus_titles.title IS --
  'Contains the original or translated title of the document. Ex: The genus Tragus';

COMMENT ON COLUMN scopus_titles.language IS 'Language of the title Ex: eng,esp';
-- endregion

-- region scopus_keywords
CREATE TABLE IF NOT EXISTS scopus_keywords (
  scp BIGINT
    CONSTRAINT sk_source_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  keyword TEXT NOT NULL,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_keywords_pk PRIMARY KEY (scp, keyword) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_keywords IS 'ELSEVIER: Keyword information table';

COMMENT ON COLUMN scopus_keywords.scp IS 'Scopus id that uniquely identifies document Ex: 85046115382';

COMMENT ON COLUMN scopus_keywords.keyword IS --
  'Keywords assigned to document by authors Ex: headache, high blood pressure';
-- endregion

-- region scopus_chemical_groups
CREATE TABLE IF NOT EXISTS scopus_chemical_groups (
  scp BIGINT
    CONSTRAINT sc_source_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  chemicals_source TEXT NOT NULL,
  chemical_name TEXT NOT NULL,
  cas_registry_number TEXT NOT NULL DEFAULT ' ',
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_chemical_groups_pk PRIMARY KEY (scp, chemical_name, cas_registry_number) --
    USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_chemical_groups IS 'ELSEVIER: Chemical names that occur in the document';

COMMENT ON COLUMN scopus_chemical_groups.scp IS 'Scopus id that uniquely identifies document Ex: 85046115382';

COMMENT ON COLUMN scopus_chemical_groups.chemicals_source IS 'Source of the chemical elements Ex: mln,esbd';

COMMENT ON COLUMN scopus_chemical_groups.chemical_name IS 'Name of the chemical substance Ex: iodine';

COMMENT ON COLUMN scopus_chemical_groups.cas_registry_number IS 'CAS registry number associated with chemical name Ex: 15715-08-9';
-- endregion

-- region scopus_grants
CREATE TABLE IF NOT EXISTS scopus_grants (
  scp BIGINT
    CONSTRAINT sg_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  grant_id TEXT,
  grantor_acronym TEXT,
  grantor TEXT NOT NULL,
  grantor_country_code CHAR(3),
  grantor_funder_registry_id TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_grants_pk PRIMARY KEY (scp, grant_id, grantor) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_grants IS 'Grants information table of publications';

COMMENT ON COLUMN scopus_grants.scp IS 'Scopus id. Example: 84936047855';

COMMENT ON COLUMN scopus_grants.grant_id IS 'Identification number of the grant assigned by grant agency';

COMMENT ON COLUMN scopus_grants.grantor_acronym IS 'Acronym of an organization that has awarded the grant';

COMMENT ON COLUMN scopus_grants.grantor IS 'Agency name that has awarded the grant';

COMMENT ON COLUMN scopus_grants.grantor_country_code IS 'Agency country 3-letter iso code';

COMMENT ON COLUMN scopus_grants.grantor_funder_registry_id IS 'Funder Registry ID';
-- endregion

-- region scopus_grant_acknowledgments
CREATE TABLE IF NOT EXISTS scopus_grant_acknowledgments (
  scp BIGINT
    CONSTRAINT sga_scp_fk REFERENCES scopus_publications ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  grant_text TEXT,
  last_updated_time TIMESTAMP DEFAULT now(),
  CONSTRAINT scopus_grant_acknowledgement_pk PRIMARY KEY (scp) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE scopus_grant_acknowledgments IS 'Grants acknowledgement table of publications';

COMMENT ON COLUMN scopus_grant_acknowledgments.scp IS 'Scopus id. Example: 84936047855';

COMMENT ON COLUMN scopus_grant_acknowledgments.grant_text IS 'The complete text of the Acknowledgement section plus all other text elements from the original source containing funding/grnat information';
--endregion

-- region update_log_scopus
CREATE TABLE IF NOT EXISTS update_log_scopus (
  id SERIAL,
  update_time TIMESTAMP,
  num_scopus_pub INTEGER,
  num_delete INTEGER,
  CONSTRAINT update_log_scopus_pk PRIMARY KEY (id) USING INDEX TABLESPACE index_tbs
)
TABLESPACE scopus_tbs;

COMMENT ON TABLE update_log_scopus IS 'Update log table for Scopus';
--endregion

CREATE TABLE IF NOT EXISTS del_scps (
  scp BIGINT NOT NULL
    CONSTRAINT del_scps_pk PRIMARY KEY,
  last_updated_time TIMESTAMP DEFAULT now()
);

