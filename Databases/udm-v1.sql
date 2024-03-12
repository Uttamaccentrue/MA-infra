--
-- PostgreSQL database dump
--

-- Dumped from database version 14.8 (Ubuntu 14.8-0ubuntu0.22.04.1)
-- Dumped by pg_dump version 15.2

-- Started on 2023-06-28 15:11:53

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 15 (class 2615 OID 17467)
-- Name: cameo; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA cameo;


--
-- TOC entry 14 (class 2615 OID 17468)
-- Name: events; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA events;


--
-- TOC entry 13 (class 2615 OID 17469)
-- Name: geonames; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA geonames;


--
-- TOC entry 12 (class 2615 OID 17470)
-- Name: nma; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA nma;


--
-- TOC entry 8 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- TOC entry 16 (class 2615 OID 19102)
-- Name: queue; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA queue;


--
-- TOC entry 11 (class 2615 OID 17472)
-- Name: social_media; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA social_media;


--
-- TOC entry 10 (class 2615 OID 17473)
-- Name: udm; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA udm;


--
-- TOC entry 17 (class 2615 OID 17474)
-- Name: users; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA users;


--
-- TOC entry 2 (class 3079 OID 17475)
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- TOC entry 4181 (class 0 OID 0)
-- Dependencies: 2
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- TOC entry 3 (class 3079 OID 17603)
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- TOC entry 4182 (class 0 OID 0)
-- Dependencies: 3
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- TOC entry 4 (class 3079 OID 17628)
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- TOC entry 4183 (class 0 OID 0)
-- Dependencies: 4
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- TOC entry 5 (class 3079 OID 17709)
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- TOC entry 4184 (class 0 OID 0)
-- Dependencies: 5
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- TOC entry 312 (class 1255 OID 17720)
-- Name: add_location_to_workspace(integer, text, double precision, double precision); Type: FUNCTION; Schema: geonames; Owner: -
--

CREATE FUNCTION geonames.add_location_to_workspace(_group_id integer, _location_name text, _latitude double precision, _longitude double precision) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
    _new_location_id INT4;
    row_json JSONB;
    new_row RECORD;
    _parent_field_id INT;
BEGIN
    /* Insert new location into table */
    INSERT INTO geonames.geonames
        (group_id, name, latitude, longitude)
    VALUES
        (_group_id, _location_name, _latitude, _longitude)
    RETURNING id INTO _new_location_id;

    /* Get Quote Location parent field ID*/
    SELECT custom_fields.parent_field_id 
        FROM users.custom_fields 
        WHERE name = 'Quote Location' AND custom_fields.group_id = _group_id
        INTO _parent_field_id;
		
	/* Insert location into terms table if a Quote Location field exists*/
	IF _parent_field_id IS NOT NULL THEN 
		INSERT INTO udm.terms (parent_id, name, type_id, owner_id, group_id, 
                reference_id, reference_schema, reference_table)
            VALUES (_parent_field_id, _location_name, 11, _group_id, _group_id,
                _new_location_id, 'geonames', 'geonames');
	END IF;
 
    /* Update the location list for the workspace with the new ID */
    UPDATE
        users.group_config 
    SET 
        config = config || _new_location_id::varchar(255)::jsonb 
    WHERE 
        group_id=_group_id AND type_id=6;
    
    /* Select new location */
    SELECT * FROM geonames.geonames
    WHERE id = _new_location_id
    INTO new_row;
    
    row_json = row_to_json(new_row);

    RETURN row_json;
END;
$$;


--
-- TOC entry 313 (class 1255 OID 17721)
-- Name: remove_alternate_names(); Type: FUNCTION; Schema: geonames; Owner: -
--

CREATE FUNCTION geonames.remove_alternate_names() RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
  ids TEXT;
  row_count INTEGER;
  delete_query TEXT;
BEGIN
  SELECT array_to_string(array_agg(id), ', ') INTO ids FROM deletes;
  delete_query := 'DELETE FROM geonames.alternate_names WHERE id IN (' || ids || ')';
  EXECUTE 'SELECT master_modify_multiple_shards($1)' INTO row_count USING delete_query;
  RETURN row_count;
END
$_$;


--
-- TOC entry 314 (class 1255 OID 17722)
-- Name: remove_geonames(); Type: FUNCTION; Schema: geonames; Owner: -
--

CREATE FUNCTION geonames.remove_geonames() RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ids TEXT;
	row_count INTEGER;
	delete_query TEXT;
BEGIN
	SELECT array_to_string(array_agg(id), ', ') INTO ids FROM deletes;
	delete_query := 'DELETE FROM geonames.geonames WHERE id IN (' || ids || ')';
	EXECUTE 'SELECT master_modify_multiple_shards($1)' INTO row_count USING delete_query;
	RETURN row_count;
END
$_$;


--
-- TOC entry 317 (class 1255 OID 17723)
-- Name: write_article_instance_last_modified(); Type: FUNCTION; Schema: nma; Owner: -
--

CREATE FUNCTION nma.write_article_instance_last_modified() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
        DECLARE
            _user_id TEXT;
            _created_at TIMESTAMP;
            insert_audit_log_cmd TEXT := $$
                INSERT INTO %s (
                    article_instance_id,
                    group_id,
                    last_modified_at,
                    last_modified_by
                ) VALUES ($1, $2, $3, $4)
                ON CONFLICT (article_instance_id, group_id)
                DO UPDATE SET
                    last_modified_at = EXCLUDED.last_modified_at,
                    last_modified_by = EXCLUDED.last_modified_by;
            $$;
            select_query TEXT := $$
                SELECT
                    created_at, user_id
                FROM
                    %s.%s
                WHERE
                    article_instance_id = $1
                    AND group_id = $2
                ORDER BY created_at DESC
                LIMIT 1
            $$;
        BEGIN
            IF (TG_OP = 'INSERT') THEN
                EXECUTE format(insert_audit_log_cmd, TG_ARGV[0])
                USING
                    NEW.article_instance_id,
                    NEW.group_id,
                    NEW.created_at,
                    NEW.user_id;
            ELSIF (TG_OP = 'UPDATE') THEN
                EXECUTE
                    format(select_query, TG_TABLE_SCHEMA, TG_TABLE_NAME)
                INTO
                    _created_at, _user_id
                USING
                    NEW.article_instance_id,
                    NEW.group_id;

                EXECUTE
                    format(insert_audit_log_cmd, TG_ARGV[0])
                USING
                    NEW.article_instance_id,
                    NEW.group_id,
                    _created_at,
                    _user_id;
            ELSIF (TG_OP = 'DELETE') THEN
                EXECUTE
                    format(select_query, TG_TABLE_SCHEMA, TG_TABLE_NAME)
                INTO
                    _created_at, _user_id
                USING
                    OLD.article_instance_id,
                    OLD.group_id;

                EXECUTE
                    format(insert_audit_log_cmd, TG_ARGV[0])
                USING
                    OLD.article_instance_id,
                    OLD.group_id,
                    _created_at,
                    _user_id;
            END IF;

            RETURN NULL;
        END;
        $_$;


--
-- TOC entry 318 (class 1255 OID 17724)
-- Name: add_modified_trigger_to_table(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_modified_trigger_to_table(tablename text) RETURNS void
    LANGUAGE plpgsql
    AS $$
            DECLARE
                drop_trigger TEXT :=
                    'DROP TRIGGER IF EXISTS update_modified_at ON ' || tablename || ';';
                create_trigger TEXT :=
                    'CREATE TRIGGER update_modified_at ' ||
                    'BEFORE UPDATE ON ' || tablename || ' ' ||
                    'FOR EACH ROW EXECUTE PROCEDURE update_modified_column();';
            BEGIN
                EXECUTE drop_trigger;
                EXECUTE create_trigger;
            END;
        $$;


--
-- TOC entry 378 (class 1255 OID 17725)
-- Name: migrate_excerpt_locations(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.migrate_excerpt_locations(_group_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _location_field_id INT;
    _location_id TEXT;
    _term_id INT;
    _location_value JSONB;
BEGIN
    SELECT
        id
    FROM
        users.custom_fields cf
    WHERE
        cf.group_id = _group_id AND
        cf.name = 'Quote Location'
    INTO
        _location_field_id;

    FOR _location_id IN
        SELECT
            jsonb_array_elements_text(config)
        FROM
            users.group_config gc
        WHERE
            gc.type_id = 6 AND
            gc.group_id = _group_id
    LOOP
        SELECT
            id
        FROM
            udm.terms t
        WHERE
            t.group_id = _group_id AND
            t.reference_table = 'geonames' AND
            t.reference_id = _location_id
        INTO
            _term_id;

        SELECT
            jsonb_build_object(_location_field_id, jsonb_build_array(_term_id))
        INTO
            _location_value;

        INSERT INTO udm.excerpt_fields AS ef (excerpt_id, group_id, data)
            SELECT
                e.id,
                e.group_id,
                _location_value
            FROM
                udm.excerpts e
            WHERE
                e.group_id = _group_id AND
                e.geoname_id = _location_id::INT
            ON CONFLICT (excerpt_id, group_id)
            DO UPDATE SET
                data = ef.data || _location_value;
    END LOOP;
END;
$$;


--
-- TOC entry 379 (class 1255 OID 17726)
-- Name: migrate_excerpt_sentiments(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.migrate_excerpt_sentiments(_group_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    _sentiment_field_id INT;
    _sentiment_parent_id INT;
    _location_id TEXT;
    _term_id INT;
    _sentiment_value JSONB;
    _pos_term_id INT;
    _neg_term_id INT;
    _neu_term_id INT;
	res RECORD;
	counter INT = 0;
BEGIN
    SELECT
        id, parent_field_id
    FROM
        users.custom_fields cf
    WHERE
        cf.group_id = _group_id AND
        cf.name = 'Quote Sentiment'
    INTO
        _sentiment_field_id, _sentiment_parent_id;

    SELECT
        id
    FROM
        udm.terms t
    WHERE
        t.group_id = _group_id AND
        t.name = 'Positive' AND
        t.parent_id = _sentiment_parent_id
    INTO
        _pos_term_id;

    SELECT
        id
    FROM
        udm.terms t
    WHERE
        t.group_id = _group_id AND
        t.name = 'Negative' AND
        t.parent_id = _sentiment_parent_id
    INTO
        _neg_term_id;

    SELECT
        id
    FROM
        udm.terms t
    WHERE
        t.group_id = _group_id AND
        t.name = 'Neutral' AND
        t.parent_id = _sentiment_parent_id
    INTO
        _neu_term_id;

    FOR res IN
        SELECT
            excerpt_id, value
        FROM
            udm.sentiments s
        WHERE
            s.group_id = _group_id
		order by id desc
    LOOP
        SELECT 
            CASE WHEN res.value = 1 THEN _pos_term_id
				WHEN res.value = -1 THEN _neg_term_id
				ELSE _neu_term_id
            END
        INTO _term_id;

        SELECT
            jsonb_build_object(_sentiment_field_id, jsonb_build_array(_term_id))
        INTO
            _sentiment_value;

        INSERT INTO udm.excerpt_fields as ef (excerpt_id, group_id, data)
           values (res.excerpt_id, _group_id, _sentiment_value)
            ON CONFLICT (excerpt_id, group_id)
            DO UPDATE SET
                data = ef.data || _sentiment_value;
			counter := counter + 1;
    END LOOP;
	RAISE NOTICE 'Total rows affected: %', counter;
END;
$$;


--
-- TOC entry 415 (class 1255 OID 17727)
-- Name: update_modified_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_modified_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                NEW.modified_at = now();
                RETURN NEW;
            END;
        $$;


--
-- TOC entry 416 (class 1255 OID 17728)
-- Name: add_value_to_custom_field(regclass, text, uuid[], text, integer, integer, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.add_value_to_custom_field(_tbl regclass, _id_col text, _ids uuid[], _fields_col text, _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT
          %1$s AS id,
          jsonb_set(
            %2$s,
            ARRAY[$1],
            array_to_json(
              ARRAY(
                SELECT DISTINCT (
                  UNNEST(
                    ARRAY(
                      SELECT jsonb_array_elements_text(
                        COALESCE(%2$s->$1, '[]')
                      )
                    ) || ARRAY[$2::text]
                  )
                )::int
              )
            )::jsonb
          ) AS fields
        FROM %3$s
        WHERE %1$s = ANY ($3)
      $$, _id_col, _fields_col, _tbl)
    USING
      _custom_field_id::text, _term_id, _ids
  LOOP
    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $3, modified_at = now()
          WHERE %3$s = $2
          RETURNING %3$s AS id, %2$s AS fields
        $$, _tbl, _fields_col, _id_col)
      USING
        rec.fields, rec.id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 417 (class 1255 OID 17729)
-- Name: old_add_value_to_custom_field(regclass, text, uuid[], integer, integer, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.old_add_value_to_custom_field(_tbl regclass, _id_col text, _ids uuid[], _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        EXECUTE format($$
            SELECT %s AS id, jsonb_set(
                fields,
                ARRAY[$1],
                array_to_json(
                    ARRAY(
                        SELECT DISTINCT(
                            UNNEST(
                                ARRAY(
                                    SELECT jsonb_array_elements_text(
                                        COALESCE(fields->$1, '[]')
                                    )
                                ) || ARRAY[$2::text]
                            )
                        )::int
                    )
                )::jsonb
            ) AS fields
            FROM %s
            WHERE %s = ANY($3)
            $$, _id_col, _tbl, _id_col)
        USING _custom_field_id::text, _term_id, _ids
    LOOP
        RETURN QUERY
            EXECUTE format($$
                UPDATE %s SET fields=$1, modified_by=$3, modified_at=now()
                WHERE %s = $2
                RETURNING %s AS id, fields
            $$, _tbl, _id_col, _id_col)
            USING rec.fields, rec.id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 418 (class 1255 OID 17730)
-- Name: old_post_add_value_to_custom_field(regclass, text, uuid[], integer, integer, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.old_post_add_value_to_custom_field(_tbl regclass, _id_col text, _ids uuid[], _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
    _fields JSONB;
BEGIN
    FOR rec IN
        EXECUTE format($$
            SELECT %s AS id, author_id FROM %s
            WHERE %s = ANY($1)
            $$, _id_col, _tbl, _id_col)
        USING _ids
    LOOP
        EXECUTE format($$
            SELECT jsonb_set(fields, ARRAY[$1], array_to_json(
                ARRAY(
                    SELECT DISTINCT(
                        UNNEST(
                            ARRAY(
                                SELECT jsonb_array_elements_text(
                                    COALESCE(fields->$1, '[]')
                                )
                            ) || ARRAY[$2::text]
                        )
                    )::int
                )
            )::jsonb) AS fields
            FROM %s
            WHERE %s = $3 AND author_id = $4
            $$, _tbl, _id_col)
        USING _custom_field_id::text, _term_id, rec.id, rec.author_id
        INTO _fields;

        RETURN QUERY
            EXECUTE format($$
                UPDATE %s SET fields=$1, modified_by=$4, modified_at=now()
                WHERE %s = $2 AND author_id = $3
                RETURNING %s AS id, fields
            $$, _tbl, _id_col, _id_col)
            USING _fields, rec.id, rec.author_id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 419 (class 1255 OID 17731)
-- Name: old_post_remove_value_from_custom_field(regclass, text, uuid[], integer, integer, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.old_post_remove_value_from_custom_field(_tbl regclass, _id_col text, _ids uuid[], _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
    _fields JSONB;
BEGIN
    FOR rec IN
        EXECUTE format($$
            SELECT %s AS id, author_id FROM %s
            WHERE %s = ANY($1)
            $$, _id_col, _tbl, _id_col)
        USING _ids
    LOOP
        EXECUTE format($$
            SELECT jsonb_set(fields, ARRAY[$1],
                array_to_json(
                    ARRAY(
                        SELECT DISTINCT(value::int) FROM jsonb_array_elements_text(
                            COALESCE(fields->$1, '[]')
                        ) WHERE value::int != $2
                    )
                )::jsonb
            ) AS fields
            FROM %s
            WHERE %s = $3 AND author_id = $4
            $$, _tbl, _id_col)
        USING _custom_field_id::text, _term_id, rec.id, rec.author_id
        INTO _fields;

        RETURN QUERY
            EXECUTE format($$
                UPDATE %s SET fields=$1, modified_by=$4, modified_at=now()
                WHERE %s = $2 AND author_id = $3
                RETURNING %s AS id, fields
            $$, _tbl, _id_col, _id_col)
            USING _fields, rec.id, rec.author_id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 420 (class 1255 OID 17732)
-- Name: old_remove_value_from_custom_field(regclass, text, uuid[], integer, integer, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.old_remove_value_from_custom_field(_tbl regclass, _id_col text, _ids uuid[], _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN EXECUTE format($$
        SELECT %s AS id, jsonb_set(
            fields,
            ARRAY[$1],
            array_to_json(
                ARRAY(
                    SELECT DISTINCT(value::int) FROM jsonb_array_elements_text(
                        COALESCE(fields->$1, '[]')
                    ) WHERE value::int != $2
                )
            )::jsonb
        ) AS fields
        FROM %s
        WHERE %s = ANY($3)
    $$, _id_col, _tbl, _id_col)
        USING _custom_field_id::text, _term_id, _ids
    LOOP
        RETURN QUERY EXECUTE format($$
                UPDATE %s SET fields=$1, modified_by=$3, modified_at=now()
                WHERE %s = $2
                RETURNING %s AS id, fields
            $$, _tbl, _id_col, _id_col)
            USING rec.fields, rec.id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 421 (class 1255 OID 17733)
-- Name: old_set_values_for_custom_field(regclass, text, uuid[], integer, integer[], text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.old_set_values_for_custom_field(_tbl regclass, _id_col text, _ids uuid[], _custom_field_id integer, _term_ids integer[], _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN EXECUTE format($$
        SELECT
            %s AS id, jsonb_set(fields, ARRAY [ $1 ], array_to_json($2)::jsonb) AS fields
    FROM
        %s
    WHERE
        %s = ANY ($3) $$, _id_col, _tbl, _id_col)
    USING _custom_field_id::text, _term_ids, _ids LOOP
        RETURN QUERY EXECUTE format($$
            UPDATE
                %s
            SET
                fields = $1, modified_by = $2, modified_at = now()
            WHERE
                %s = $2
            RETURNING
                %s AS id, fields $$, _tbl, _id_col, _id_col)
            USING rec.fields, rec.id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 422 (class 1255 OID 17734)
-- Name: old_set_values_for_custom_fields(regclass, text, uuid[], jsonb, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.old_set_values_for_custom_fields(_tbl regclass, _id_col text, _ids uuid[], _custom_field_data jsonb, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN EXECUTE format($$
        SELECT
            %s AS id, fields || $1 AS fields
        FROM
            %s
        WHERE
            %s = ANY ($2) $$, _id_col, _tbl, _id_col)
    USING _custom_field_data, _ids LOOP
        RETURN QUERY EXECUTE format($$
            UPDATE
                %s
            SET
                fields = $1, modified_by = $3, modified_at = now()
            WHERE
                %s = $2
            RETURNING
                %s AS id, fields $$, _tbl, _id_col, _id_col)
            USING rec.fields, rec.id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 423 (class 1255 OID 17735)
-- Name: post_add_value_to_custom_field(regclass, text, uuid[], text, integer, integer, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.post_add_value_to_custom_field(_tbl regclass, _id_col text, _ids uuid[], _fields_col text, _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
  _fields jsonb;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT %1$s AS id, author_id
        FROM %2$s
        WHERE %1$s = ANY ($1)
      $$, _id_col, _tbl)
    USING
      _ids
    LOOP
      EXECUTE
        format($$
          SELECT
            jsonb_set(
              %1$s,
              ARRAY[$1],
              array_to_json(
                ARRAY(
                  SELECT DISTINCT (
                    UNNEST(
                      ARRAY(
                        SELECT jsonb_array_elements_text(
                          COALESCE(%1$s->$1, '[]')
                        )
                      ) || ARRAY[$2::text]
                    )
                  )::int
                )
              )::jsonb
            ) AS fields
          FROM %2$s
          WHERE %3$s = $3 AND author_id = $4
        $$, _fields_col, _tbl, _id_col)
      USING
        _custom_field_id::text, _term_id, rec.id, rec.author_id
      INTO
        _fields;

      RETURN QUERY
        EXECUTE
          format($$
            UPDATE %1$s SET %2$s = $1, modified_by = $4, modified_at = now()
            WHERE %3$s = $2 AND author_id = $3
            RETURNING %3$s AS id, %2$s
          $$, _tbl, _fields_col, _id_col)
        USING
          _fields, rec.id, rec.author_id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 424 (class 1255 OID 17736)
-- Name: post_remove_value_from_custom_field(regclass, text, uuid[], text, integer, integer, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.post_remove_value_from_custom_field(_tbl regclass, _id_col text, _ids uuid[], _fields_col text, _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
  _fields jsonb;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT %1$s AS id, author_id
        FROM %2$s
        WHERE %1$s = ANY ($1)
      $$, _id_col, _tbl)
    USING
      _ids
  LOOP
    EXECUTE
      format($$
        SELECT
          jsonb_set(
            %1$s,
            ARRAY[$1],
            array_to_json(
              ARRAY(
                SELECT DISTINCT value::int
                FROM jsonb_array_elements_text(COALESCE(%1$s->$1, '[]'))
                WHERE value::int != $2
              )
            )::jsonb
          ) AS fields
        FROM %2$s
        WHERE %3$s = $3 AND author_id = $4
      $$, _fields_col, _tbl, _id_col)
    USING
      _custom_field_id::text, _term_id, rec.id, rec.author_id
    INTO
      _fields;

    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $4, modified_at = now()
          WHERE %3$s = $2 AND author_id = $3
          RETURNING %3$s AS id, %2$s AS fields
        $$, _tbl, _fields_col, _id_col)
      USING
        _fields, rec.id, rec.author_id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 425 (class 1255 OID 17737)
-- Name: remove_value_from_custom_field(regclass, text, uuid[], text, integer, integer, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.remove_value_from_custom_field(_tbl regclass, _id_col text, _ids uuid[], _fields_col text, _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT
          %1$s AS id,
          jsonb_set(
            %2$s,
            ARRAY[$1],
            array_to_json(
              ARRAY(
                SELECT DISTINCT value::int
                FROM jsonb_array_elements_text(COALESCE(%2$s->$1, '[]'))
                WHERE value::int != $2
              )
            )::jsonb
          ) AS fields
        FROM %3$s
        WHERE %1$s = ANY ($3)
      $$, _id_col, _fields_col, _tbl)
    USING
      _custom_field_id::text, _term_id, _ids
  LOOP
    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $3, modified_at = now()
          WHERE %3$s = $2
          RETURNING %3$s AS id, %2$s AS fields
        $$, _tbl, _fields_col, _id_col)
      USING
        rec.fields, rec.id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 427 (class 1255 OID 17738)
-- Name: set_values_for_custom_field(regclass, text, uuid[], text, integer, integer[], text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.set_values_for_custom_field(_tbl regclass, _id_col text, _ids uuid[], _fields_col text, _custom_field_id integer, _term_ids integer[], _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT
          %1$s AS id,
          jsonb_set(%2$s, ARRAY[$1], array_to_json($2)::jsonb) AS fields
        FROM %3$s
        WHERE %1$s = ANY ($3)
      $$, _id_col, _fields_col, _tbl)
    USING
      _custom_field_id::text, _term_ids, _ids
  LOOP
    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $3, modified_at = now()
          WHERE %3$s = $2
          RETURNING %3$s AS id, %2$s AS fields
        $$, _tbl, _fields_col, _id_col)
      USING
        rec.fields, rec.id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 428 (class 1255 OID 17739)
-- Name: set_values_for_custom_fields(regclass, text, uuid[], text, jsonb, text); Type: FUNCTION; Schema: social_media; Owner: -
--

CREATE FUNCTION social_media.set_values_for_custom_fields(_tbl regclass, _id_col text, _ids uuid[], _fields_col text, _custom_field_data jsonb, _modified_by text) RETURNS TABLE(id uuid, fields jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT %1$s AS id, %2$s || $1 AS fields
        FROM %3$s
        WHERE %1$s = ANY ($2)
      $$, _id_col, _fields_col, _tbl)
    USING
      _custom_field_data, _ids
  LOOP
    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $3, modified_at = now()
          WHERE %3$s = $2
          RETURNING %3$s AS id, %2$s AS fields
        $$, _tbl, _fields_col, _id_col)
      USING
        rec.fields, rec.id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 429 (class 1255 OID 17740)
-- Name: add_stopword_file(text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.add_stopword_file(_language text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    _create_dictionary TEXT := format($one$
        CREATE TEXT SEARCH DICTIONARY simple_%s_stop (TEMPLATE = pg_catalog.simple, STOPWORDS = %s);
    $one$, _language, _language);
    _create_config TEXT := format($two$
        CREATE TEXT SEARCH CONFIGURATION simple_%s (copy = simple);
    $two$, _language);
    _alter_config_mapping1 TEXT := format($three$
        ALTER TEXT SEARCH CONFIGURATION simple_%s
            ALTER MAPPING FOR asciihword, asciiword, hword, hword_asciipart, hword_part, word
            WITH simple_%s_stop;
    $three$, _language, _language);
    _alter_config_mapping2 TEXT := format($four$
        ALTER TEXT SEARCH CONFIGURATION simple_%s
            DROP MAPPING FOR email, url, host, url_path, file, sfloat, float, int, uint, version;
    $four$, _language);
BEGIN
    EXECUTE _create_dictionary;
    EXECUTE _create_config;
    EXECUTE _alter_config_mapping1;
    EXECUTE _alter_config_mapping2;
    PERFORM run_command_on_workers(_create_dictionary);
    PERFORM run_command_on_workers(_create_config);
    PERFORM run_command_on_workers(_alter_config_mapping1);
    PERFORM run_command_on_workers(_alter_config_mapping2);
END;
$_$;


--
-- TOC entry 430 (class 1255 OID 17741)
-- Name: add_value_to_custom_field(regclass, text, bigint[], integer, text, integer, integer, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.add_value_to_custom_field(_tbl regclass, _id_col text, _ids bigint[], _group_id integer, _data_col text, _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id bigint, data jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT
          %1$s AS id,
          jsonb_set(
            %2$s,
            ARRAY[$1],
            array_to_json(
              ARRAY(
                SELECT DISTINCT (
                  UNNEST(
                    ARRAY(
                      SELECT jsonb_array_elements_text(
                        COALESCE(%2$s->$1, '[]')
                      )
                    ) || ARRAY[$2::text]
                  )
                )::int
              )
            )::jsonb
          ) AS data
        FROM %3$s
        WHERE group_id = $3 AND %1$s = ANY ($4)
      $$, _id_col, _data_col, _tbl)
    USING
      _custom_field_id::text, _term_id, _group_id, _ids
  LOOP
    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $4, modified_at = now()
          WHERE group_id = $2 AND %3$s = $3
          RETURNING %3$s AS id, %2$s AS data
        $$, _tbl, _data_col, _id_col)
      USING
        rec.data, _group_id, rec.id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 431 (class 1255 OID 17742)
-- Name: body_to_tsvector(text, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.body_to_tsvector(lang_639_1 text, body text, OUT tsv tsvector) RETURNS tsvector
    LANGUAGE plpgsql IMMUTABLE
    AS $$
        DECLARE
            dict regconfig;
        BEGIN
            SELECT
                CASE
                    WHEN lang_639_1 = 'ar' THEN 'simple_arabic'
                    WHEN lang_639_1 = 'da' THEN 'simple_danish'
                    WHEN lang_639_1 = 'de' THEN 'simple_german'
                    WHEN lang_639_1 = 'en' THEN 'simple_english'
                    WHEN lang_639_1 = 'es' THEN 'simple_spanish'
                    WHEN lang_639_1 = 'fi' THEN 'simple_finnish'
                    WHEN lang_639_1 = 'fr' THEN 'simple_french'
                    WHEN lang_639_1 = 'hu' THEN 'simple_hungarian'
                    WHEN lang_639_1 = 'it' THEN 'simple_italian'
                    WHEN lang_639_1 = 'nl' THEN 'simple_dutch'
                    WHEN lang_639_1 = 'no' THEN 'simple_norwegian'
                    WHEN lang_639_1 = 'pt' THEN 'simple_portuguese'
                    WHEN lang_639_1 = 'ro' THEN 'simple_romanian'
                    WHEN lang_639_1 = 'ru' THEN 'simple_russian'
                    WHEN lang_639_1 = 'sv' THEN 'simple_swedish'
                    ELSE 'simple_simple'
                END
            INTO dict;
            SELECT to_tsvector(dict, body) INTO tsv;
        END;
        $$;


--
-- TOC entry 432 (class 1255 OID 17743)
-- Name: check_entity_merge_args(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.check_entity_merge_args(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
        group_count INT;
        found_group_id BIGINT;
    BEGIN
        -- Check that all entities involved have the same group.
        SELECT COUNT(DISTINCT group_id) INTO group_count
        FROM udm.entities WHERE id = ANY(array_append(merged_ids, target_id));
        IF group_count > 1 THEN
            RAISE EXCEPTION 'Not all entities are in the same group';
        END IF;

        -- Check that the given group_id matches the entity.
        SELECT group_id INTO found_group_id FROM udm.entities WHERE id = target_id;
        IF entity_group_id != found_group_id  THEN
            RAISE EXCEPTION 'The target entity group_id % does not match provided group_id %', found_group_id, entity_group_id;
        END IF;
        RETURN;
    END;
$$;


--
-- TOC entry 426 (class 1255 OID 17744)
-- Name: get_custom_fields(bigint, bigint, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.get_custom_fields(query_id bigint, query_group_id bigint, query_type text) RETURNS json
    LANGUAGE plpgsql
    AS $$
        DECLARE
            cf json;
        BEGIN
            SELECT udm.get_custom_fields(query_id, query_group_id, query_type, query_type || 's')
            INTO cf;
            return cf;
        END
        $$;


--
-- TOC entry 433 (class 1255 OID 17745)
-- Name: get_custom_fields(bigint, bigint, text, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.get_custom_fields(query_id bigint, query_group_id bigint, query_type text, type_plural text) RETURNS json
    LANGUAGE plpgsql
    AS $_$
        DECLARE
            cf json;
        BEGIN
            EXECUTE format(
                $cf$
                SELECT
                    json_agg(json_build_object(
                        field_values.name,
                        row_to_json(t.*)
                    )) AS custom_fields
                FROM (
                    /* Break out custom field values */
                    SELECT
                        field_data.id,
                        field_data.group_id,
                        cf.name,
                        jsonb_array_elements_text(field_data.data->cf.id::text) AS field_value_id
                    FROM (
                        /* Break out custom field IDs */
                        SELECT
                            e.id, e.group_id,
                            jsonb_object_keys(ef.data) AS field_id,
                            ef.data
                        FROM udm.%4$s AS e
                        LEFT OUTER JOIN udm.%3$s_fields AS ef
                        ON e.group_id = ef.group_id AND e.id = ef.%3$s_id
                        WHERE e.id = %1$s
                        /* field IDs */
                    ) AS field_data
                    LEFT OUTER JOIN users.custom_fields AS cf
                    ON field_data.group_id = cf.group_id AND field_data.field_id::bigint = cf.id::bigint
                    /* field values */
                ) AS field_values
                LEFT OUTER JOIN udm.terms AS t
                ON field_values.group_id = t.group_id AND field_values.field_value_id::bigint = t.id::bigint
                WHERE field_values.group_id = %2$s
                GROUP BY field_values.id;
                $cf$, query_id, query_group_id, query_type, type_plural
            ) INTO cf;
            return cf;
        END
        $_$;


--
-- TOC entry 434 (class 1255 OID 17746)
-- Name: get_uuid_v1_timestamp(uuid); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.get_uuid_v1_timestamp(u uuid) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
            DECLARE
                u_bytes     BYTEA := decode(REPLACE(u::TEXT, '-', ''), 'hex');
                u_version   INTEGER := get_byte(u_bytes, 6) >> 4;
                u_bigint    INT8;
            BEGIN
                IF u_version != 1 THEN
                    RAISE EXCEPTION 'UUID version is %, expected version 1.', u_version;
                END IF;

                -- First 8 bytes of uuid has 4 sections, lo, mid, and hi timestamp sections, and version number:
                --   ll ll ll ll mm mm vh hh

                -- With this we extract and construct the timestamp to be:
                --   0h hh mm mm ll ll ll ll

                u_bigint = ((get_byte(u_bytes, 6) & 15)::BIGINT << 56) | -- discard first four bits (they contain version)
                            (get_byte(u_bytes, 7)::BIGINT       << 48) |

                            (get_byte(u_bytes, 4)::BIGINT       << 40) |
                            (get_byte(u_bytes, 5)::BIGINT       << 32) |

                            (get_byte(u_bytes, 0)::BIGINT       << 24) |
                            (get_byte(u_bytes, 1)::BIGINT       << 16) |
                            (get_byte(u_bytes, 2)::BIGINT       << 8 ) |
                            (get_byte(u_bytes, 3)::BIGINT       << 0 );

                RETURN u_bigint;
            END;
        $$;


--
-- TOC entry 435 (class 1255 OID 17747)
-- Name: merge_entities(bigint, bigint[], bigint, json, json, json); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities(target_id bigint, merged_ids bigint[], entity_group_id bigint, resolved_entity json, resolved_custom_fields json, resolved_reach json) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check the provided arguments.
    PERFORM
        udm.check_entity_merge_args (target_id,
            merged_ids,
            entity_group_id);
    -- Resolve all tables referencing the merged entities.
    PERFORM
        udm.merge_entities_article_instances (target_id,
            merged_ids,
            entity_group_id);
    PERFORM
        udm.merge_entities_article_instances_authors (target_id,
            merged_ids,
            entity_group_id);
    PERFORM
        udm.merge_entities_entity_fields (target_id,
            merged_ids,
            entity_group_id,
            resolved_custom_fields);
    PERFORM
        udm.merge_entities_entity_relations (target_id,
            merged_ids,
            entity_group_id);
    PERFORM
        udm.merge_entities_excerpts (target_id,
            merged_ids,
            entity_group_id);
    PERFORM
        udm.merge_entities_reach (target_id,
            merged_ids,
            entity_group_id,
            resolved_reach);
    PERFORM
        udm.merge_entities_sentiments (target_id,
            merged_ids,
            entity_group_id);
    PERFORM
        udm.merge_entities_terms (target_id,
            merged_ids,
            entity_group_id);
    -- Merge the entities themselves.
    PERFORM
        udm.merge_entities_entities (target_id,
            merged_ids,
            entity_group_id,
            resolved_entity);
    RETURN target_id;
END;
$$;


--
-- TOC entry 436 (class 1255 OID 17748)
-- Name: merge_entities_article_instances(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_article_instances(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        UPDATE udm.article_instances SET organization_id = target_id
        WHERE organization_id = ANY(merged_ids) AND group_id = entity_group_id;
        RETURN;
    END;
$$;


--
-- TOC entry 437 (class 1255 OID 17749)
-- Name: merge_entities_article_instances_authors(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_article_instances_authors(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        -- For each row referencing a merged entity, insert a duplicate referencing the target entity.
        INSERT INTO udm.article_instances_authors (
            article_instance_id,
            author_id,
            group_id
        ) (
            SELECT
                article_instance_id,
                target_id AS author_id,
                group_id
            FROM udm.article_instances_authors
            WHERE author_id = ANY(merged_ids) AND group_id = entity_group_id
        ) ON CONFLICT DO NOTHING;

        -- Delete the old rows referencing the merged entities.
        DELETE FROM udm.article_instances_authors 
        WHERE author_id = ANY(merged_ids) AND group_id = entity_group_id;
        RETURN;
    END;
$$;


--
-- TOC entry 438 (class 1255 OID 17750)
-- Name: merge_entities_entities(bigint, bigint[], bigint, json); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_entities(target_id bigint, merged_ids bigint[], entity_group_id bigint, resolved_entity json) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        -- Delete any references to old merged entities.
        DELETE FROM udm.entities
        WHERE id = ANY(merged_ids) AND group_id = entity_group_id;
        
        -- Resolve the merged entity.
        IF resolved_entity IS NULL THEN RETURN; END IF;
        UPDATE udm.entities
        SET name = (resolved_entity ->> 'name')::TEXT,
            data = (resolved_entity ->> 'data')::JSONB,
            url = (resolved_entity ->> 'url')::TEXT,
            owner_id = (resolved_entity ->> 'owner_id')::INT,
            originating_id = (resolved_entity ->> 'originating_id')::BIGINT,
            originating_namespace = (resolved_entity ->> 'originating_namespace')::TEXT
        WHERE id = target_id AND group_id = entity_group_id;

        RETURN;
    END;
$$;


--
-- TOC entry 439 (class 1255 OID 17751)
-- Name: merge_entities_entity_fields(bigint, bigint[], bigint, json); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_entity_fields(target_id bigint, merged_ids bigint[], entity_group_id bigint, resolved_custom_fields json) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        -- Delete any references to old entity custom fields.
        DELETE FROM udm.entity_fields
        WHERE entity_id = ANY(array_append(merged_ids, target_id)) AND group_id = entity_group_id;

        -- Resolve the merged fields.
        IF resolved_custom_fields IS NULL THEN RETURN; END IF;
        INSERT INTO udm.entity_fields (
            entity_id,
            group_id,
            data
        ) VALUES (
            target_id,
            entity_group_id,
            resolved_custom_fields
        );
        RETURN;
    END;
$$;


--
-- TOC entry 440 (class 1255 OID 17752)
-- Name: merge_entities_entity_relations(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_entity_relations(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        -- For each row referencing a merged entity in the subject_id, insert a duplicate referencing the target entity.
        INSERT INTO udm.entity_relations (
            subject_id,
            object_id,
            predicate_id,
            during,
            created_at,
            owner_id,
            group_id
        ) (
            SELECT
                target_id AS subject_id,
                object_id,
                predicate_id,
                during,
                created_at,
                owner_id,
                group_id
            FROM udm.entity_relations
            WHERE subject_id = ANY(merged_ids) AND group_id = entity_group_id
        ) ON CONFLICT DO NOTHING;

        -- Delete the old rows referencing the merged entities in the subject_id.
        DELETE FROM udm.entity_relations
        WHERE subject_id = ANY(merged_ids) AND group_id = entity_group_id;

        -- For each row referencing a merged entity in the object_id, insert a duplicate referencing the target entity.
        INSERT INTO udm.entity_relations (
            subject_id,
            object_id,
            predicate_id,
            during,
            created_at,
            owner_id,
            group_id
        ) (
            SELECT
                subject_id,
                target_id AS object_id,
                predicate_id,
                during,
                created_at,
                owner_id,
                group_id
            FROM udm.entity_relations
            WHERE object_id = ANY(merged_ids) AND group_id = entity_group_id
        ) ON CONFLICT DO NOTHING;

        -- Delete the old rows referencing the merged entities in the object_id.
        DELETE FROM udm.entity_relations
        WHERE subject_id = ANY(merged_ids) AND group_id = entity_group_id;

        RETURN;
    END;
$$;


--
-- TOC entry 441 (class 1255 OID 17753)
-- Name: merge_entities_events(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_events(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        UPDATE udm.events SET actor1_id = target_id
        WHERE actor1_id = ANY(merged_ids) AND group_id = entity_group_id;

        UPDATE udm.events SET actor2_id = target_id
        WHERE actor2_id = ANY(merged_ids) AND group_id = entity_group_id;

        RETURN;
    END;
$$;


--
-- TOC entry 442 (class 1255 OID 17754)
-- Name: merge_entities_excerpts(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_excerpts(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        UPDATE udm.excerpts SET source_id = target_id
        WHERE source_id = ANY(merged_ids) AND group_id = entity_group_id;
        RETURN;
    END;
$$;


--
-- TOC entry 443 (class 1255 OID 17755)
-- Name: merge_entities_reach(bigint, bigint[], bigint, json); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_reach(target_id bigint, merged_ids bigint[], entity_group_id bigint, resolved_reach json) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        -- Delete any references to old entity reaches.
        DELETE FROM udm.reach
        WHERE entity_id = ANY(array_append(merged_ids, target_id)) AND group_id = entity_group_id;

        -- Resolve merged entity reaches.
        IF resolved_reach IS NULL THEN RETURN; END IF;
        INSERT INTO udm.reach (
            entity_id,
            demographic_id,
            score,
            owner_id,
            group_id,
            originating_namespace,
            originating_id
        ) VALUES (
            target_id,
            (resolved_reach ->> 'demographic_id')::INT,
            (resolved_reach ->> 'score')::INT,
            (resolved_reach ->> 'owner_id')::INT,
            entity_group_id,
            (resolved_reach ->> 'originating_namespace')::TEXT,
            (resolved_reach ->> 'originating_id')::BIGINT
        );
        RETURN;
    END;
$$;


--
-- TOC entry 444 (class 1255 OID 17756)
-- Name: merge_entities_reported_events(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_reported_events(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        UPDATE udm.reported_events SET actor1_id = target_id
        WHERE actor1_id = ANY(merged_ids) AND group_id = entity_group_id;

        UPDATE udm.reported_events SET actor1_id = target_id
        WHERE actor2_id = ANY(merged_ids) AND group_id = entity_group_id;

        RETURN;
    END;
$$;


--
-- TOC entry 445 (class 1255 OID 17757)
-- Name: merge_entities_sentiments(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_sentiments(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        UPDATE udm.sentiments SET towards_id = target_id
        WHERE towards_id = ANY(merged_ids) AND group_id = entity_group_id;
        RETURN;
    END;
$$;


--
-- TOC entry 446 (class 1255 OID 17758)
-- Name: merge_entities_terms(bigint, bigint[], bigint); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.merge_entities_terms(target_id bigint, merged_ids bigint[], entity_group_id bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
    DECLARE
    BEGIN
        UPDATE udm.terms SET entity_id = target_id
        WHERE entity_id = ANY(merged_ids) AND group_id = entity_group_id;
        RETURN;
    END;
$$;


--
-- TOC entry 447 (class 1255 OID 17759)
-- Name: migrate_entity_data(integer, text, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.migrate_entity_data(_group_id integer, _key text, _new_name text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
DECLARE
    _parent_term_id INT4;
    _custom_field_id INT4;
    _value TEXT;
    _entity_id INT4;
    _json JSONB;
    _nothing INT4; /* placeholder to prevent error in Create Value Terms loop */
BEGIN
    /* Create Custom Field Term */
    INSERT INTO udm.terms
        (owner_id, group_id, name, type_id)
    VALUES
        (_group_id, _group_id, _new_name, 10)
    RETURNING id INTO _parent_term_id;

    /* Create Custom Field */
    INSERT INTO users.custom_fields
        (group_id, subject_type, name, mandatory, parent_field_id)
    VALUES
        (_group_id, 'entity', _new_name, False, _parent_term_id)
    RETURNING id INTO _custom_field_id;

    /* Create Value Terms */
    FOR _value, _nothing IN
        SELECT DISTINCT data ->> _key AS value, group_id
        FROM udm.entities
        WHERE group_id = _group_id
        AND data -> _key IS NOT NULL
        AND TRIM(data ->> _key) != ''
        GROUP BY owner_id, group_id, value
    LOOP
        INSERT INTO udm.terms
            (owner_id, group_id, name, type_id, parent_id)
        VALUES
            (_group_id, _group_id, _value, 10, _parent_term_id);
    END LOOP;

    /* Use explicit formatting to avoid triggering citus bug:
       https://github.com/citusdata/citus/issues/499
    */
    EXECUTE format('INSERT INTO udm.entity_fields AS ef (entity_id, group_id, data)'
        || ' SELECT e.id, e.group_id, jsonb_object_agg( cf.id, ARRAY[t.id])'
        || ' FROM udm.entities AS e'
        || ' JOIN jsonb_each_text(e.data) AS kv ON kv.key = %2$L'
        || ' JOIN users.custom_fields AS cf ON e.group_id = cf.group_id AND cf.name = %3$L'
        || ' JOIN udm.terms AS t ON e.group_id = t.group_id AND kv.value = t.name AND t.parent_id = %4$L'
        || ' WHERE e.group_id = %1$L'
        || ' GROUP BY e.id, e.group_id'
        || ' ON CONFLICT (entity_id, group_id)'
        || ' DO UPDATE SET data = EXCLUDED.data || ef.data;',
        _group_id, _key, _new_name, _parent_term_id);

END;
$_$;


--
-- TOC entry 448 (class 1255 OID 17760)
-- Name: migrate_entity_data_cleanup(integer, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.migrate_entity_data_cleanup(_group_id integer, _key text) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    /* Remove old data key */
    UPDATE udm.entities
        SET data = data - _key
    WHERE group_id = _group_id;
END
$$;


--
-- TOC entry 465 (class 1255 OID 19158)
-- Name: msg_excerpt(); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.msg_excerpt() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO queue.msg_excerpt(excerpt_id, action)
	VALUES(NEW.id, TG_OP);

	RETURN NEW;
END;
$$;


--
-- TOC entry 466 (class 1255 OID 19181)
-- Name: msg_excerpt_fields(); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.msg_excerpt_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO queue.msg_excerpt(excerpt_id, action)
	VALUES(NEW.excerpt_id, TG_OP);

	RETURN NEW;
END;
$$;


--
-- TOC entry 450 (class 1255 OID 17761)
-- Name: old_add_value_to_custom_field(regclass, text, bigint[], integer, integer, integer, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.old_add_value_to_custom_field(_tbl regclass, _id_col text, _ids bigint[], _group_id integer, _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id bigint, data jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        EXECUTE format($$
            SELECT %s AS id, jsonb_set(
                data,
                ARRAY[$1],
                array_to_json(
                    ARRAY(
                        SELECT DISTINCT(
                            UNNEST(
                                ARRAY(
                                    SELECT jsonb_array_elements_text(
                                        COALESCE(data->$1, '[]')
                                    )
                                ) || ARRAY[$2::text]
                            )
                        )::int
                    )
                )::jsonb
            ) AS data
            FROM %s
            WHERE group_id = $3 AND %s = ANY($4)
            $$, _id_col, _tbl, _id_col)
        USING _custom_field_id::text, _term_id, _group_id, _ids
    LOOP
        RETURN QUERY
            EXECUTE format($$
                UPDATE %s SET data=$1, modified_by=$4, modified_at=now()
                WHERE group_id = $2 AND %s = $3
                RETURNING %s AS id, data
            $$, _tbl, _id_col, _id_col)
            USING rec.data, _group_id, rec.id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 451 (class 1255 OID 17762)
-- Name: old_remove_value_from_custom_field(regclass, text, bigint[], integer, integer, integer, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.old_remove_value_from_custom_field(_tbl regclass, _id_col text, _ids bigint[], _group_id integer, _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id bigint, data jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN EXECUTE format($$
        SELECT %s AS id, jsonb_set(
            data,
            ARRAY[$1],
            array_to_json(
                ARRAY(
                    SELECT DISTINCT(value::int) FROM jsonb_array_elements_text(
                        COALESCE(data->$1, '[]')
                    ) WHERE value::int != $2
                )
            )::jsonb
        ) AS data
        FROM %s
        WHERE group_id = $3 AND %s = ANY($4)
    $$, _id_col, _tbl, _id_col)
        USING _custom_field_id::text, _term_id, _group_id, _ids
    LOOP
        RETURN QUERY EXECUTE format($$
                UPDATE %s SET data=$1, modified_by=$4, modified_at=now()
                WHERE group_id = $2 AND %s = $3
                RETURNING %s AS id, data
            $$, _tbl, _id_col, _id_col)
            USING rec.data, _group_id, rec.id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 452 (class 1255 OID 17763)
-- Name: old_set_values_for_custom_field(regclass, text, bigint[], integer, integer, integer[], text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.old_set_values_for_custom_field(_tbl regclass, _id_col text, _ids bigint[], _group_id integer, _custom_field_id integer, _term_ids integer[], _modified_by text) RETURNS TABLE(id bigint, data jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN EXECUTE format($$
        SELECT
            %s AS id, jsonb_set(data, ARRAY [ $1 ], array_to_json($2)::jsonb) AS data
    FROM
        %s
    WHERE
        group_id = $3
        AND %s = ANY ($4) $$, _id_col, _tbl, _id_col)
    USING _custom_field_id::text, _term_ids, _group_id, _ids LOOP
        RETURN QUERY EXECUTE format($$
            UPDATE
                %s
            SET
                data = $1, modified_by = $4, modified_at = now()
            WHERE
                group_id = $2
                AND %s = $3
            RETURNING
                %s AS id, data $$, _tbl, _id_col, _id_col)
            USING rec.data, _group_id, rec.id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 453 (class 1255 OID 17764)
-- Name: old_set_values_for_custom_fields(regclass, text, bigint[], integer, jsonb, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.old_set_values_for_custom_fields(_tbl regclass, _id_col text, _ids bigint[], _group_id integer, _custom_field_data jsonb, _modified_by text) RETURNS TABLE(id bigint, data jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN EXECUTE format($$
        SELECT
            %s AS id, data || $1 AS data
        FROM
            %s
        WHERE
            group_id = $2
            AND %s = ANY ($3) $$, _id_col, _tbl, _id_col)
    USING _custom_field_data, _group_id, _ids LOOP
        RETURN QUERY EXECUTE format($$
            UPDATE
                %s
            SET
                data = $1, modified_by = $4, modified_at = now()
            WHERE
                group_id = $2
                AND %s = $3
            RETURNING
                %s AS id, data $$, _tbl, _id_col, _id_col)
            USING rec.data, _group_id, rec.id, _modified_by;
    END LOOP;
    RETURN;
END;
$_$;


--
-- TOC entry 454 (class 1255 OID 17765)
-- Name: remove_value_from_custom_field(regclass, text, bigint[], integer, text, integer, integer, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.remove_value_from_custom_field(_tbl regclass, _id_col text, _ids bigint[], _group_id integer, _data_col text, _custom_field_id integer, _term_id integer, _modified_by text) RETURNS TABLE(id bigint, data jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT
          %1$s AS id,
          jsonb_set(
            %2$s,
            ARRAY[$1],
            array_to_json(
              ARRAY(
                SELECT DISTINCT value::int
                FROM jsonb_array_elements_text(COALESCE(%2$s->$1, '[]'))
                WHERE value::int != $2
              )
            )::jsonb
          ) AS data
        FROM %3$s
        WHERE group_id = $3 AND %1$s = ANY ($4)
      $$, _id_col, _data_col, _tbl)
    USING
      _custom_field_id::text, _term_id, _group_id, _ids
  LOOP
    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $4, modified_at = now()
          WHERE group_id = $2 AND %3$s = $3
          RETURNING %3$s AS id, %2$s AS data
        $$, _tbl, _data_col, _id_col)
      USING
        rec.data, _group_id, rec.id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 449 (class 1255 OID 17766)
-- Name: set_values_for_custom_field(regclass, text, bigint[], integer, text, integer, integer[], text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.set_values_for_custom_field(_tbl regclass, _id_col text, _ids bigint[], _group_id integer, _data_col text, _custom_field_id integer, _term_ids integer[], _modified_by text) RETURNS TABLE(id bigint, data jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    EXECUTE
      format($$
        SELECT
          %1$s AS id,
          jsonb_set(%2$s, ARRAY[$1], array_to_json($2)::jsonb) AS data
        FROM %3$s
        WHERE group_id = $3 AND %1$s = ANY ($4)
      $$, _id_col, _data_col, _tbl)
    USING
      _custom_field_id::text, _term_ids, _group_id, _ids
  LOOP
    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $4, modified_at = now()
          WHERE group_id = $2 AND %3$s = $3
          RETURNING %3$s AS id, %2$s AS data
        $$, _tbl, _data_col, _id_col)
      USING
        rec.data, _group_id, rec.id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 456 (class 1255 OID 17767)
-- Name: set_values_for_custom_fields(regclass, text, bigint[], integer, text, jsonb, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.set_values_for_custom_fields(_tbl regclass, _id_col text, _ids bigint[], _group_id integer, _data_col text, _custom_field_data jsonb, _modified_by text) RETURNS TABLE(id bigint, data jsonb)
    LANGUAGE plpgsql
    AS $_$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN
    -- This is a place where PL/pgSQL can get cryptic. Here we are executing
    -- a query with two phases of parameter substitution.
    --
    -- First, `format` is called with a format string and a list of parameters.
    -- `%1$I` refers to the first parameter passed to the `format` function,
    -- treated as an identifier (double quoting if necessary).
    --
    -- Next, the output of `format` is passed to EXECUTE ... USING ..., which
    -- also takes a list of parameters. `$1` refers to the first USING
    -- parameter, `$2` to the second, and so on.
    --
    -- This explanation is relevant in many places through this migration file.
    EXECUTE
      format($$
        SELECT %1$s AS id, %2$s || $1 AS data
        FROM %3$s
        WHERE group_id = $2 AND %1$s = ANY ($3)
      $$, _id_col, _data_col, _tbl)
    USING
      _custom_field_data, _group_id, _ids
  LOOP
    RETURN QUERY
      EXECUTE
        format($$
          UPDATE %1$s
          SET %2$s = $1, modified_by = $4, modified_at = now()
          WHERE group_id = $2 AND %3$s = $3
          RETURNING %3$s AS id, %2$s AS data
        $$, _tbl, _data_col, _id_col)
      USING
        rec.data, _group_id, rec.id, _modified_by;
  END LOOP;
  RETURN;
END;
$_$;


--
-- TOC entry 457 (class 1255 OID 17768)
-- Name: text_to_timestamptz(text, text); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.text_to_timestamptz(str text, fmt text) RETURNS timestamp with time zone
    LANGUAGE sql IMMUTABLE
    AS $$
                SELECT to_timestamp(str, fmt)
            $$;


--
-- TOC entry 458 (class 1255 OID 17769)
-- Name: write_article_instance_audit_log(); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.write_article_instance_audit_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
        DECLARE
            rec HSTORE;
            item_id BIGINT;
            insert_audit_log_cmd TEXT := $$
                INSERT INTO %s (
                    group_id,
                    article_instance_id,
                    tablename,
                    schemaname,
                    operation,
                    user_id,
                    new_val
                ) VALUES ($1, $2, $3, $4, $5, $6, $7);
            $$;
            update_audit_log_cmd TEXT := $$
                INSERT INTO %s (
                    group_id,
                    article_instance_id,
                    tablename,
                    schemaname,
                    operation,
                    user_id,
                    new_val,
                    old_val
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8);
            $$;
            delete_audit_log_cmd TEXT := $$
                INSERT INTO %s (
                    group_id,
                    article_instance_id,
                    tablename,
                    schemaname,
                    operation,
                    user_id,
                    old_val
                ) VALUES ($1, $2, $3, $4, $5, $6, $7);
            $$;
        BEGIN
            IF (TG_OP = 'INSERT') THEN
                rec := hstore(NEW);
                item_id := rec -> TG_ARGV[1];
                EXECUTE format(insert_audit_log_cmd, TG_ARGV[0])
                    USING
                        NEW.group_id,
                        item_id,
                        regexp_replace(lower(TG_RELNAME), '_\d+$', ''),
                        TG_TABLE_SCHEMA,
                        TG_OP,
                        NEW.created_by,
                        rec;
            ELSIF (TG_OP = 'UPDATE') THEN
                rec := hstore(NEW);
                item_id := rec -> TG_ARGV[1];
                EXECUTE format(update_audit_log_cmd, TG_ARGV[0])
                    USING
                        NEW.group_id,
                        item_id,
                        regexp_replace(lower(TG_RELNAME), '_\d+$', ''),
                        TG_TABLE_SCHEMA,
                        TG_OP,
                        NEW.modified_by,
                        rec,
                        hstore(OLD);
            ELSIF (TG_OP = 'DELETE') THEN
                rec := hstore(OLD);
                item_id := rec -> TG_ARGV[1];
                EXECUTE format(delete_audit_log_cmd, TG_ARGV[0])
                    USING
                        OLD.group_id,
                        item_id,
                        regexp_replace(lower(TG_RELNAME), '_\d+$', ''),
                        TG_TABLE_SCHEMA,
                        TG_OP,
                        'system',
                        rec;
            END IF;

            RETURN NULL;
        END;
        $_$;


--
-- TOC entry 459 (class 1255 OID 17770)
-- Name: write_event_log(); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.write_event_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
            DECLARE
                id              UUID;
                id_timestamp    BIGINT;
                routing_key     TEXT;
                updated_row     RECORD;
                row_json        JSONB;
                group_id        INT4;
                insert_event_log_cmd TEXT := $$
                    INSERT INTO %s (
                        id,
                        timestamp,
                        action_name,
                        data,
                        group_id,
                        table_name,
                        routing_key
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7);
                    $$;
            BEGIN
                -- Generate a new uuid and extract its timestamp
                id = uuid_generate_v1();
                id_timestamp = udm.get_uuid_v1_timestamp(id);
                -- Create routing key from table and operation
                routing_key := 'udm_row_change'
                               '.'::TEXT || regexp_replace(lower(TG_TABLE_NAME::TEXT), '_\d+$', '') ||
                               '.'::TEXT || lower(TG_OP::TEXT);
                -- Store the updated row
                IF (TG_OP = 'DELETE') THEN
                    updated_row := OLD;
                ELSIF (TG_OP = 'UPDATE') THEN
                    updated_row := NEW;
                ELSIF (TG_OP = 'INSERT') THEN
                    updated_row := NEW;
                END IF;
                row_json := row_to_json(updated_row);
                group_id := updated_row.group_id;
                -- Change 'events' to the desired channel/exchange name
                EXECUTE format(insert_event_log_cmd, TG_ARGV[0])
                    USING id, id_timestamp, TG_OP, row_json, group_id, TG_TABLE_NAME, routing_key;
                RETURN NULL;
            END;
        $_$;


--
-- TOC entry 460 (class 1255 OID 17771)
-- Name: write_social_media_event_log(); Type: FUNCTION; Schema: udm; Owner: -
--

CREATE FUNCTION udm.write_social_media_event_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
            DECLARE
                id              UUID;
                author_id       UUID;
                id_timestamp    BIGINT;
                routing_key     TEXT;
                updated_row     RECORD;
                row_json        JSONB;
                group_id        INT4;
                table_name      TEXT;
                insert_event_log_cmd TEXT := $$
                    INSERT INTO %s (
                        id,
                        author_id,
                        timestamp,
                        action_name,
                        data,
                        group_id,
                        table_name,
                        routing_key
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8);
                    $$;
            BEGIN
                -- Generate a new uuid and extract its timestamp
                id = uuid_generate_v1();
                id_timestamp = udm.get_uuid_v1_timestamp(id);

                table_name = regexp_replace(lower(TG_TABLE_NAME::TEXT), '_\d+$', '');

                -- Create routing key from table and operation
                routing_key := 'udm'
                               '.'::TEXT || lower(TG_TABLE_SCHEMA) ||
                               '.'::TEXT || table_name ||
                               '.'::TEXT || lower(TG_OP::TEXT);

                -- Store the updated row
                IF (TG_OP = 'DELETE') THEN
                    updated_row := OLD;
                ELSIF (TG_OP = 'UPDATE') THEN
                    updated_row := NEW;
                ELSIF (TG_OP = 'INSERT') THEN
                    updated_row := NEW;
                END IF;
                row_json := row_to_json(updated_row);
                group_id := updated_row.group_id;

                IF (table_name = 'social_media_entities') THEN
                    author_id := updated_row.id;
                ELSE
                    author_id := updated_row.author_id;
                END IF;

                -- Change 'events' to the desired channel/exchange name
                EXECUTE format(insert_event_log_cmd, TG_ARGV[0])
                    USING id, author_id, id_timestamp, TG_OP, row_json, group_id, TG_TABLE_NAME, routing_key;

                RETURN NULL;
            END;
        $_$;


--
-- TOC entry 461 (class 1255 OID 17772)
-- Name: create_custom_field(text, text, integer); Type: FUNCTION; Schema: users; Owner: -
--

CREATE FUNCTION users.create_custom_field(field_name text, type text, group_id integer, OUT custom_field_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    term_id INT;
    type_id INT;
    type_name TEXT;
BEGIN
    SELECT
        CASE WHEN type = 'article' THEN 9
            WHEN type = 'entity' THEN 10
            WHEN type = 'excerpt' THEN 11
            WHEN type = 'social_media' THEN 9  -- this is intentional as the ID here is deprecated.
        END
        INTO type_id;
    SELECT
        CASE WHEN type = 'social_media' THEN 'social_media~!~post'
             ELSE type
        END
        INTO type_name;
    INSERT INTO udm.terms (name, type_id, owner_id, group_id)
        VALUES (field_name, type_id, group_id, group_id)
        RETURNING id INTO term_id;
    INSERT INTO users.custom_fields(group_id, subject_type, name, parent_field_id)
        VALUES (group_id, type_name, field_name, term_id)
        RETURNING id INTO custom_field_id;
END;
$$;


--
-- TOC entry 462 (class 1255 OID 17773)
-- Name: create_custom_field_tree(text[], text, integer); Type: FUNCTION; Schema: users; Owner: -
--

CREATE FUNCTION users.create_custom_field_tree(field_names text[], type text, group_id integer, OUT custom_field_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    term_id INT;
    parent_custom_field_id INT;
    field_name TEXT;
    type_name TEXT;
BEGIN
    -- first field is a regular field.  Store the custom_field_id so we can return
    -- the top parent field id.
    SELECT users.create_custom_field(field_names[1], type, group_id)
        INTO custom_field_id;

    -- store the parent_custom_field_id so we can loop over it.
    SELECT custom_field_id
        INTO parent_custom_field_id;
    
    SELECT
        CASE WHEN type = 'social_media' THEN 'social_media~!~post'
             ELSE type
        END
        INTO type_name;

    FOREACH field_name IN ARRAY field_names[2:]
    LOOP
        INSERT INTO users.custom_fields(group_id, subject_type, name, parent_field_lookup_id)
            VALUES (group_id, type_name, field_name, parent_custom_field_id)
            RETURNING id INTO parent_custom_field_id;
    END LOOP;
END;
$$;


--
-- TOC entry 463 (class 1255 OID 17774)
-- Name: create_customer_group(text); Type: FUNCTION; Schema: users; Owner: -
--

CREATE FUNCTION users.create_customer_group(customer_name text, OUT customer_id integer, OUT group_id integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN
  SELECT * FROM users.create_customer_group(customer_name, customer_name) INTO customer_id, group_id;
END;
$$;


--
-- TOC entry 455 (class 1255 OID 17775)
-- Name: create_customer_group(text, text); Type: FUNCTION; Schema: users; Owner: -
--

CREATE FUNCTION users.create_customer_group(customer_name text, group_name text, OUT customer_id integer, OUT group_id integer) RETURNS record
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO users.customers (name) VALUES (customer_name) RETURNING id INTO customer_id;
  INSERT INTO users.groups (name) VALUES (group_name) RETURNING id INTO group_id;
  INSERT INTO users.customers_groups (customer_id, group_id) VALUES (customer_id, group_id);
END;
$$;


--
-- TOC entry 464 (class 1255 OID 17776)
-- Name: migrate_locations(integer); Type: FUNCTION; Schema: users; Owner: -
--

CREATE FUNCTION users.migrate_locations(group_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    location_ids jsonb;
    location_id INT;
    _parent_field_id INT;
    geoname TEXT;
    _group_id INT = group_id;
    counter INT = 0;
BEGIN
    SELECT config 
        FROM users.group_config 
        WHERE type_id = 6 AND group_config.group_id = _group_id
        INTO location_ids;

    SELECT custom_fields.parent_field_id 
        FROM users.custom_fields 
        WHERE name = 'Quote Location' AND custom_fields.group_id = _group_id
        INTO _parent_field_id;

    FOR location_id IN SELECT jsonb_array_elements_text(location_ids)
    LOOP
        counter := counter + 1;
        SELECT name 
            FROM geonames.geonames
            WHERE id = location_id
            INTO geoname;
        INSERT INTO udm.terms (parent_id, name, type_id, owner_id, group_id, 
                reference_id, reference_schema, reference_table)
            VALUES (_parent_field_id, geoname, 11, _group_id, _group_id,
                location_id, 'geonames', 'geonames')
            ON CONFLICT DO NOTHING;
    END LOOP;
    RAISE NOTICE 'Total rows affected: %', counter;
END;
$$;


--
-- TOC entry 2451 (class 3600 OID 17777)
-- Name: simple_arabic_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_arabic_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'arabic' );


--
-- TOC entry 2452 (class 3600 OID 17778)
-- Name: simple_bulgarian_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_bulgarian_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'bulgarian' );


--
-- TOC entry 2453 (class 3600 OID 17779)
-- Name: simple_danish_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_danish_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'danish' );


--
-- TOC entry 2454 (class 3600 OID 17780)
-- Name: simple_dutch_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_dutch_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'dutch' );


--
-- TOC entry 2455 (class 3600 OID 17781)
-- Name: simple_english_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_english_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'english' );


--
-- TOC entry 2456 (class 3600 OID 17782)
-- Name: simple_finnish_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_finnish_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'finnish' );


--
-- TOC entry 2457 (class 3600 OID 17783)
-- Name: simple_french_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_french_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'french' );


--
-- TOC entry 2458 (class 3600 OID 17784)
-- Name: simple_german_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_german_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'german' );


--
-- TOC entry 2459 (class 3600 OID 17785)
-- Name: simple_hungarian_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_hungarian_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'hungarian' );


--
-- TOC entry 2460 (class 3600 OID 17786)
-- Name: simple_italian_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_italian_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'italian' );


--
-- TOC entry 2461 (class 3600 OID 17787)
-- Name: simple_norwegian_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_norwegian_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'norwegian' );


--
-- TOC entry 2462 (class 3600 OID 17788)
-- Name: simple_polish_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_polish_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'polish' );


--
-- TOC entry 2463 (class 3600 OID 17789)
-- Name: simple_portuguese_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_portuguese_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'portuguese' );


--
-- TOC entry 2464 (class 3600 OID 17790)
-- Name: simple_romanian_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_romanian_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'romanian' );


--
-- TOC entry 2465 (class 3600 OID 17791)
-- Name: simple_russian_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_russian_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'russian' );


--
-- TOC entry 2466 (class 3600 OID 17792)
-- Name: simple_spanish_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_spanish_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'spanish' );


--
-- TOC entry 2467 (class 3600 OID 17793)
-- Name: simple_swedish_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_swedish_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'swedish' );


--
-- TOC entry 2468 (class 3600 OID 17794)
-- Name: simple_turkish_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_turkish_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'turkish' );


--
-- TOC entry 2469 (class 3600 OID 17795)
-- Name: simple_ukrainian_stop; Type: TEXT SEARCH DICTIONARY; Schema: public; Owner: -
--

CREATE TEXT SEARCH DICTIONARY public.simple_ukrainian_stop (
    TEMPLATE = pg_catalog.simple,
    stopwords = 'ukrainian' );


--
-- TOC entry 2499 (class 3602 OID 17796)
-- Name: simple_arabic; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_arabic (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR asciiword WITH public.simple_arabic_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR word WITH public.simple_arabic_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR hword_part WITH public.simple_arabic_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR hword_asciipart WITH public.simple_arabic_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR asciihword WITH public.simple_arabic_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_arabic
    ADD MAPPING FOR hword WITH public.simple_arabic_stop;


--
-- TOC entry 2500 (class 3602 OID 17797)
-- Name: simple_bulgarian; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_bulgarian (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR asciiword WITH public.simple_bulgarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR word WITH public.simple_bulgarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR hword_part WITH public.simple_bulgarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR hword_asciipart WITH public.simple_bulgarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR asciihword WITH public.simple_bulgarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_bulgarian
    ADD MAPPING FOR hword WITH public.simple_bulgarian_stop;


--
-- TOC entry 2501 (class 3602 OID 17798)
-- Name: simple_danish; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_danish (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR asciiword WITH public.simple_danish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR word WITH public.simple_danish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR hword_part WITH public.simple_danish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR hword_asciipart WITH public.simple_danish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR asciihword WITH public.simple_danish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_danish
    ADD MAPPING FOR hword WITH public.simple_danish_stop;


--
-- TOC entry 2502 (class 3602 OID 17799)
-- Name: simple_dutch; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_dutch (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR asciiword WITH public.simple_dutch_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR word WITH public.simple_dutch_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR hword_part WITH public.simple_dutch_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR hword_asciipart WITH public.simple_dutch_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR asciihword WITH public.simple_dutch_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_dutch
    ADD MAPPING FOR hword WITH public.simple_dutch_stop;


--
-- TOC entry 2503 (class 3602 OID 17800)
-- Name: simple_english; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_english (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR asciiword WITH public.simple_english_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR word WITH public.simple_english_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR hword_part WITH public.simple_english_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR hword_asciipart WITH public.simple_english_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR asciihword WITH public.simple_english_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_english
    ADD MAPPING FOR hword WITH public.simple_english_stop;


--
-- TOC entry 2504 (class 3602 OID 17801)
-- Name: simple_finnish; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_finnish (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR asciiword WITH public.simple_finnish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR word WITH public.simple_finnish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR hword_part WITH public.simple_finnish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR hword_asciipart WITH public.simple_finnish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR asciihword WITH public.simple_finnish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_finnish
    ADD MAPPING FOR hword WITH public.simple_finnish_stop;


--
-- TOC entry 2505 (class 3602 OID 17802)
-- Name: simple_french; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_french (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR asciiword WITH public.simple_french_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR word WITH public.simple_french_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR hword_part WITH public.simple_french_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR hword_asciipart WITH public.simple_french_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR asciihword WITH public.simple_french_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_french
    ADD MAPPING FOR hword WITH public.simple_french_stop;


--
-- TOC entry 2506 (class 3602 OID 17803)
-- Name: simple_german; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_german (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR asciiword WITH public.simple_german_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR word WITH public.simple_german_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR hword_part WITH public.simple_german_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR hword_asciipart WITH public.simple_german_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR asciihword WITH public.simple_german_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_german
    ADD MAPPING FOR hword WITH public.simple_german_stop;


--
-- TOC entry 2507 (class 3602 OID 17804)
-- Name: simple_hungarian; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_hungarian (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR asciiword WITH public.simple_hungarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR word WITH public.simple_hungarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR hword_part WITH public.simple_hungarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR hword_asciipart WITH public.simple_hungarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR asciihword WITH public.simple_hungarian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_hungarian
    ADD MAPPING FOR hword WITH public.simple_hungarian_stop;


--
-- TOC entry 2508 (class 3602 OID 17805)
-- Name: simple_italian; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_italian (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR asciiword WITH public.simple_italian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR word WITH public.simple_italian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR hword_part WITH public.simple_italian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR hword_asciipart WITH public.simple_italian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR asciihword WITH public.simple_italian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_italian
    ADD MAPPING FOR hword WITH public.simple_italian_stop;


--
-- TOC entry 2509 (class 3602 OID 17806)
-- Name: simple_norwegian; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_norwegian (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR asciiword WITH public.simple_norwegian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR word WITH public.simple_norwegian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR hword_part WITH public.simple_norwegian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR hword_asciipart WITH public.simple_norwegian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR asciihword WITH public.simple_norwegian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_norwegian
    ADD MAPPING FOR hword WITH public.simple_norwegian_stop;


--
-- TOC entry 2510 (class 3602 OID 17807)
-- Name: simple_polish; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_polish (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR asciiword WITH public.simple_polish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR word WITH public.simple_polish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR hword_part WITH public.simple_polish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR hword_asciipart WITH public.simple_polish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR asciihword WITH public.simple_polish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_polish
    ADD MAPPING FOR hword WITH public.simple_polish_stop;


--
-- TOC entry 2511 (class 3602 OID 17808)
-- Name: simple_portuguese; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_portuguese (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR asciiword WITH public.simple_portuguese_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR word WITH public.simple_portuguese_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR hword_part WITH public.simple_portuguese_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR hword_asciipart WITH public.simple_portuguese_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR asciihword WITH public.simple_portuguese_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_portuguese
    ADD MAPPING FOR hword WITH public.simple_portuguese_stop;


--
-- TOC entry 2512 (class 3602 OID 17809)
-- Name: simple_romanian; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_romanian (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR asciiword WITH public.simple_romanian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR word WITH public.simple_romanian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR hword_part WITH public.simple_romanian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR hword_asciipart WITH public.simple_romanian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR asciihword WITH public.simple_romanian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_romanian
    ADD MAPPING FOR hword WITH public.simple_romanian_stop;


--
-- TOC entry 2513 (class 3602 OID 17810)
-- Name: simple_russian; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_russian (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR asciiword WITH public.simple_russian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR word WITH public.simple_russian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR hword_part WITH public.simple_russian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR hword_asciipart WITH public.simple_russian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR asciihword WITH public.simple_russian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_russian
    ADD MAPPING FOR hword WITH public.simple_russian_stop;


--
-- TOC entry 2514 (class 3602 OID 17811)
-- Name: simple_simple; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_simple (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR word WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR hword_part WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_simple
    ADD MAPPING FOR hword WITH simple;


--
-- TOC entry 2515 (class 3602 OID 17812)
-- Name: simple_spanish; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_spanish (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR asciiword WITH public.simple_spanish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR word WITH public.simple_spanish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR hword_part WITH public.simple_spanish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR hword_asciipart WITH public.simple_spanish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR asciihword WITH public.simple_spanish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_spanish
    ADD MAPPING FOR hword WITH public.simple_spanish_stop;


--
-- TOC entry 2516 (class 3602 OID 17813)
-- Name: simple_swedish; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_swedish (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR asciiword WITH public.simple_swedish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR word WITH public.simple_swedish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR hword_part WITH public.simple_swedish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR hword_asciipart WITH public.simple_swedish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR asciihword WITH public.simple_swedish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_swedish
    ADD MAPPING FOR hword WITH public.simple_swedish_stop;


--
-- TOC entry 2517 (class 3602 OID 17814)
-- Name: simple_turkish; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_turkish (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR asciiword WITH public.simple_turkish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR word WITH public.simple_turkish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR hword_part WITH public.simple_turkish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR hword_asciipart WITH public.simple_turkish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR asciihword WITH public.simple_turkish_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_turkish
    ADD MAPPING FOR hword WITH public.simple_turkish_stop;


--
-- TOC entry 2518 (class 3602 OID 17815)
-- Name: simple_ukrainian; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: -
--

CREATE TEXT SEARCH CONFIGURATION public.simple_ukrainian (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR asciiword WITH public.simple_ukrainian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR word WITH public.simple_ukrainian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR hword_part WITH public.simple_ukrainian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR hword_asciipart WITH public.simple_ukrainian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR asciihword WITH public.simple_ukrainian_stop;

ALTER TEXT SEARCH CONFIGURATION public.simple_ukrainian
    ADD MAPPING FOR hword WITH public.simple_ukrainian_stop;


SET default_table_access_method = heap;

--
-- TOC entry 223 (class 1259 OID 17816)
-- Name: ethnic; Type: TABLE; Schema: cameo; Owner: -
--

CREATE TABLE cameo.ethnic (
    id text NOT NULL,
    name text NOT NULL
);


--
-- TOC entry 224 (class 1259 OID 17821)
-- Name: religion; Type: TABLE; Schema: cameo; Owner: -
--

CREATE TABLE cameo.religion (
    id text NOT NULL,
    name text NOT NULL,
    alternate_names text,
    notes text
);


--
-- TOC entry 225 (class 1259 OID 17826)
-- Name: events; Type: TABLE; Schema: events; Owner: -
--

CREATE TABLE events.events (
    id character varying NOT NULL,
    originating_namespace character varying NOT NULL,
    originating_id character varying NOT NULL,
    group_id integer,
    actor1 jsonb,
    actor2 jsonb,
    action jsonb,
    occurred timestamp with time zone NOT NULL,
    source character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 226 (class 1259 OID 17833)
-- Name: alternate_names; Type: TABLE; Schema: geonames; Owner: -
--

CREATE TABLE geonames.alternate_names (
    id integer NOT NULL,
    originating_id integer,
    geoname_id integer NOT NULL,
    isolanguage character varying(7),
    name character varying(400),
    is_preferred_name boolean,
    is_short_name boolean,
    is_colloquial boolean,
    is_historic boolean
);


--
-- TOC entry 227 (class 1259 OID 17836)
-- Name: alternate_names_id_seq; Type: SEQUENCE; Schema: geonames; Owner: -
--

CREATE SEQUENCE geonames.alternate_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4185 (class 0 OID 0)
-- Dependencies: 227
-- Name: alternate_names_id_seq; Type: SEQUENCE OWNED BY; Schema: geonames; Owner: -
--

ALTER SEQUENCE geonames.alternate_names_id_seq OWNED BY geonames.alternate_names.id;


--
-- TOC entry 228 (class 1259 OID 17837)
-- Name: boundaries; Type: TABLE; Schema: geonames; Owner: -
--

CREATE TABLE geonames.boundaries (
    geoname_id integer NOT NULL,
    originating_id integer,
    geojson json
);


--
-- TOC entry 229 (class 1259 OID 17842)
-- Name: country_info; Type: TABLE; Schema: geonames; Owner: -
--

CREATE TABLE geonames.country_info (
    iso_alpha2 character(2),
    iso_alpha3 character(3),
    iso_numeric integer,
    fips_code character varying(3),
    name character varying(200),
    capital character varying(200),
    areainsqkm numeric,
    population integer,
    continent character varying(2),
    tld character varying(10),
    currencycode character varying(3),
    currencyname character varying(20),
    phone character varying(20),
    postalcode character varying(100),
    postalcoderegex character varying(200),
    languages character varying(200),
    geoname_id integer NOT NULL,
    neighbors character varying(50),
    equivfipscode character varying(3)
);


--
-- TOC entry 230 (class 1259 OID 17847)
-- Name: feature_codes; Type: TABLE; Schema: geonames; Owner: -
--

CREATE TABLE geonames.feature_codes (
    class character(1) NOT NULL,
    code character varying(10) NOT NULL,
    value character varying(255) NOT NULL,
    description character varying(255) NOT NULL
);


--
-- TOC entry 231 (class 1259 OID 17852)
-- Name: geonames; Type: TABLE; Schema: geonames; Owner: -
--

CREATE TABLE geonames.geonames (
    id integer NOT NULL,
    originating_id integer,
    group_id integer,
    name character varying(200),
    asciiname character varying(200),
    latitude numeric,
    longitude numeric,
    fclass character(1),
    fcode character varying(10),
    country character(2),
    cc2 character varying(200),
    admin1 character varying(20),
    admin2 character varying(80),
    admin3 character varying(20),
    admin4 character varying(20),
    population bigint,
    elevation integer,
    gtopo30 integer,
    timezone character varying(40),
    modified date
);


--
-- TOC entry 232 (class 1259 OID 17857)
-- Name: geonames_id_seq; Type: SEQUENCE; Schema: geonames; Owner: -
--

CREATE SEQUENCE geonames.geonames_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4186 (class 0 OID 0)
-- Dependencies: 232
-- Name: geonames_id_seq; Type: SEQUENCE OWNED BY; Schema: geonames; Owner: -
--

ALTER SEQUENCE geonames.geonames_id_seq OWNED BY geonames.geonames.id;


--
-- TOC entry 233 (class 1259 OID 17858)
-- Name: article_instance_last_modified; Type: TABLE; Schema: nma; Owner: -
--

CREATE TABLE nma.article_instance_last_modified (
    article_instance_id bigint NOT NULL,
    group_id integer NOT NULL,
    last_modified_at timestamp without time zone DEFAULT now() NOT NULL,
    last_modified_by text NOT NULL
);


--
-- TOC entry 234 (class 1259 OID 17864)
-- Name: article_instance_metadata; Type: TABLE; Schema: nma; Owner: -
--

CREATE TABLE nma.article_instance_metadata (
    article_instance_id integer NOT NULL,
    group_id integer NOT NULL,
    user_id character varying(255) DEFAULT 'Unassigned'::character varying NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 235 (class 1259 OID 17875)
-- Name: article_instance_statuses; Type: TABLE; Schema: nma; Owner: -
--

CREATE TABLE nma.article_instance_statuses (
    id integer NOT NULL,
    name character varying NOT NULL
);


--
-- TOC entry 236 (class 1259 OID 17880)
-- Name: metadata_counts; Type: TABLE; Schema: nma; Owner: -
--

CREATE TABLE nma.metadata_counts (
    group_id integer NOT NULL,
    user_id character varying(255) NOT NULL,
    status_id integer NOT NULL,
    count integer NOT NULL
);


--
-- TOC entry 237 (class 1259 OID 17889)
-- Name: goose_db_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.goose_db_version (
    id integer NOT NULL,
    version_id bigint NOT NULL,
    is_applied boolean NOT NULL,
    tstamp timestamp without time zone DEFAULT now()
);


--
-- TOC entry 238 (class 1259 OID 17893)
-- Name: goose_db_version_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.goose_db_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4187 (class 0 OID 0)
-- Dependencies: 238
-- Name: goose_db_version_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.goose_db_version_id_seq OWNED BY public.goose_db_version.id;


--
-- TOC entry 290 (class 1259 OID 19124)
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id integer NOT NULL
);


--
-- TOC entry 289 (class 1259 OID 19123)
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4188 (class 0 OID 0)
-- Dependencies: 289
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- TOC entry 292 (class 1259 OID 19149)
-- Name: msg_excerpt; Type: TABLE; Schema: queue; Owner: -
--

CREATE TABLE queue.msg_excerpt (
    id integer NOT NULL,
    excerpt_id integer NOT NULL,
    action character varying(50),
    created_at timestamp without time zone
);


--
-- TOC entry 291 (class 1259 OID 19148)
-- Name: msg_excerpt_id_seq; Type: SEQUENCE; Schema: queue; Owner: -
--

CREATE SEQUENCE queue.msg_excerpt_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4189 (class 0 OID 0)
-- Dependencies: 291
-- Name: msg_excerpt_id_seq; Type: SEQUENCE OWNED BY; Schema: queue; Owner: -
--

ALTER SEQUENCE queue.msg_excerpt_id_seq OWNED BY queue.msg_excerpt.id;


--
-- TOC entry 239 (class 1259 OID 17894)
-- Name: entities; Type: TABLE; Schema: social_media; Owner: -
--

CREATE TABLE social_media.entities (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    group_id integer NOT NULL,
    data jsonb,
    originating_namespace text,
    originating_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    fields jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- TOC entry 240 (class 1259 OID 17905)
-- Name: link_types; Type: TABLE; Schema: social_media; Owner: -
--

CREATE TABLE social_media.link_types (
    id integer NOT NULL,
    name text NOT NULL,
    description text
);


--
-- TOC entry 241 (class 1259 OID 17910)
-- Name: links; Type: TABLE; Schema: social_media; Owner: -
--

CREATE TABLE social_media.links (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    author_id uuid NOT NULL,
    social_media_id uuid NOT NULL,
    link text NOT NULL,
    link_type_id integer NOT NULL,
    title text,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL
);

ALTER TABLE ONLY social_media.links REPLICA IDENTITY FULL;


--
-- TOC entry 242 (class 1259 OID 17920)
-- Name: post_named_entities; Type: TABLE; Schema: social_media; Owner: -
--

CREATE TABLE social_media.post_named_entities (
    post_named_entity_id bigint NOT NULL,
    post_id uuid NOT NULL,
    count smallint NOT NULL,
    type text NOT NULL,
    value text NOT NULL
);


--
-- TOC entry 243 (class 1259 OID 17925)
-- Name: post_named_entities_post_named_entity_id_seq; Type: SEQUENCE; Schema: social_media; Owner: -
--

CREATE SEQUENCE social_media.post_named_entities_post_named_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4190 (class 0 OID 0)
-- Dependencies: 243
-- Name: post_named_entities_post_named_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: social_media; Owner: -
--

ALTER SEQUENCE social_media.post_named_entities_post_named_entity_id_seq OWNED BY social_media.post_named_entities.post_named_entity_id;


--
-- TOC entry 244 (class 1259 OID 17926)
-- Name: posts; Type: TABLE; Schema: social_media; Owner: -
--

CREATE TABLE social_media.posts (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    author_id uuid NOT NULL,
    group_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    data jsonb NOT NULL,
    content text,
    tsv tsvector,
    lang_639_1 character varying(7),
    parent_id uuid,
    publication_time timestamp with time zone NOT NULL,
    originating_namespace text,
    originating_id text,
    assigned_to_id text DEFAULT 'Unassigned'::text NOT NULL,
    status_id integer DEFAULT 1 NOT NULL,
    fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    ml_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    english_translation text,
    translation_tsv tsvector,
    translation_engine character varying
);


--
-- TOC entry 245 (class 1259 OID 17940)
-- Name: statuses; Type: TABLE; Schema: social_media; Owner: -
--

CREATE TABLE social_media.statuses (
    id integer NOT NULL,
    name text NOT NULL,
    description text
);


--
-- TOC entry 246 (class 1259 OID 17945)
-- Name: article_instance_audit_log; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_instance_audit_log (
    group_id integer NOT NULL,
    schemaname text NOT NULL,
    tablename text NOT NULL,
    article_instance_id integer NOT NULL,
    operation text NOT NULL,
    user_id text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    new_val public.hstore,
    old_val public.hstore
);


--
-- TOC entry 247 (class 1259 OID 17951)
-- Name: article_instance_fields; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_instance_fields (
    article_instance_id integer NOT NULL,
    group_id integer NOT NULL,
    data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    ml_data jsonb DEFAULT '{}'::jsonb
);


--
-- TOC entry 248 (class 1259 OID 17962)
-- Name: article_instance_metadata; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_instance_metadata (
    article_instance_id integer NOT NULL,
    group_id integer NOT NULL,
    type_id integer NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 249 (class 1259 OID 17970)
-- Name: article_instance_metadata_types; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_instance_metadata_types (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255) NOT NULL
);


--
-- TOC entry 250 (class 1259 OID 17975)
-- Name: article_instance_text; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_instance_text (
    article_instance_id integer NOT NULL,
    data text NOT NULL,
    lang_639_1 character varying(7),
    tsv tsvector,
    owner_id integer NOT NULL,
    group_id integer NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL
);


--
-- TOC entry 251 (class 1259 OID 17982)
-- Name: article_instances; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_instances (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    owner_id integer NOT NULL,
    group_id integer NOT NULL,
    artifact character varying(255),
    origin_id integer NOT NULL,
    parent_article_instance_id integer,
    publication_time timestamp with time zone,
    title character varying,
    organization_id bigint,
    originating_namespace character varying,
    originating_id text,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    location_id integer
);


--
-- TOC entry 252 (class 1259 OID 17992)
-- Name: article_instances_authors; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_instances_authors (
    article_instance_id integer NOT NULL,
    author_id bigint NOT NULL,
    group_id integer NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    article_archived boolean DEFAULT false NOT NULL
);


--
-- TOC entry 253 (class 1259 OID 18000)
-- Name: article_instances_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.article_instances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4191 (class 0 OID 0)
-- Dependencies: 253
-- Name: article_instances_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.article_instances_id_seq OWNED BY udm.article_instances.id;


--
-- TOC entry 254 (class 1259 OID 18001)
-- Name: article_named_entities; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_named_entities (
    article_named_entity_id integer NOT NULL,
    article_id integer NOT NULL,
    count smallint NOT NULL,
    type text NOT NULL,
    value text NOT NULL
);


--
-- TOC entry 255 (class 1259 OID 18006)
-- Name: article_named_entities_article_named_entity_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.article_named_entities_article_named_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4192 (class 0 OID 0)
-- Dependencies: 255
-- Name: article_named_entities_article_named_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.article_named_entities_article_named_entity_id_seq OWNED BY udm.article_named_entities.article_named_entity_id;


--
-- TOC entry 256 (class 1259 OID 18007)
-- Name: article_texts; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.article_texts (
    article_text_id uuid DEFAULT public.uuid_generate_v1mc() NOT NULL,
    article_id integer NOT NULL,
    group_id integer NOT NULL,
    original boolean NOT NULL,
    title text,
    body text NOT NULL,
    lang_639_1 character varying NOT NULL,
    tsv tsvector GENERATED ALWAYS AS (udm.body_to_tsvector((lang_639_1)::text, body)) STORED,
    translation_engine character varying,
    created_by character varying DEFAULT 'system'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by character varying DEFAULT 'system'::character varying NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 257 (class 1259 OID 18018)
-- Name: entities; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.entities (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    data jsonb NOT NULL,
    url character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    owner_id integer NOT NULL,
    group_id integer NOT NULL,
    originating_namespace character varying,
    originating_id text,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    type_ids jsonb
);


--
-- TOC entry 258 (class 1259 OID 18028)
-- Name: entities_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.entities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4193 (class 0 OID 0)
-- Dependencies: 258
-- Name: entities_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.entities_id_seq OWNED BY udm.entities.id;


--
-- TOC entry 259 (class 1259 OID 18029)
-- Name: entity_alternate_names; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.entity_alternate_names (
    id bigint NOT NULL,
    entity_id bigint NOT NULL,
    name character varying(400) NOT NULL,
    group_id integer NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 260 (class 1259 OID 18038)
-- Name: entity_alternate_names_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.entity_alternate_names_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4194 (class 0 OID 0)
-- Dependencies: 260
-- Name: entity_alternate_names_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.entity_alternate_names_id_seq OWNED BY udm.entity_alternate_names.id;


--
-- TOC entry 261 (class 1259 OID 18039)
-- Name: entity_counts; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.entity_counts (
    entity_id bigint NOT NULL,
    group_id integer NOT NULL,
    author_count integer DEFAULT 0 NOT NULL,
    source_count integer DEFAULT 0 NOT NULL
);


--
-- TOC entry 262 (class 1259 OID 18044)
-- Name: entity_fields; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.entity_fields (
    entity_id bigint NOT NULL,
    group_id integer NOT NULL,
    data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    ml_data jsonb DEFAULT '{}'::jsonb
);


--
-- TOC entry 263 (class 1259 OID 18055)
-- Name: entity_predicate_types; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.entity_predicate_types (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255) NOT NULL
);


--
-- TOC entry 264 (class 1259 OID 18060)
-- Name: entity_relations; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.entity_relations (
    subject_id bigint NOT NULL,
    object_id bigint NOT NULL,
    predicate_id integer NOT NULL,
    during daterange,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    owner_id integer NOT NULL,
    group_id integer NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL
);


--
-- TOC entry 265 (class 1259 OID 18069)
-- Name: entity_types; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.entity_types (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255) NOT NULL
);


--
-- TOC entry 266 (class 1259 OID 18074)
-- Name: excerpt_fields; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.excerpt_fields (
    excerpt_id bigint NOT NULL,
    group_id integer NOT NULL,
    data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    ml_data jsonb DEFAULT '{}'::jsonb
);


--
-- TOC entry 267 (class 1259 OID 18085)
-- Name: excerpts; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.excerpts (
    id bigint NOT NULL,
    owner_id integer NOT NULL,
    group_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    article_instance_id integer NOT NULL,
    "offset" integer,
    length integer,
    data text NOT NULL,
    source_id bigint,
    lang_639_1 character varying(7),
    tsv tsvector,
    originating_namespace character varying,
    originating_id text,
    geoname_id integer,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    latitude numeric,
    longitude numeric,
    placename character varying(255),
    occurred timestamp with time zone
);


--
-- TOC entry 268 (class 1259 OID 18095)
-- Name: excerpts_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.excerpts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4195 (class 0 OID 0)
-- Dependencies: 268
-- Name: excerpts_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.excerpts_id_seq OWNED BY udm.excerpts.id;


--
-- TOC entry 269 (class 1259 OID 18096)
-- Name: origins; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.origins (
    id integer NOT NULL,
    name character varying(255) NOT NULL
);


--
-- TOC entry 270 (class 1259 OID 18099)
-- Name: reach; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.reach (
    id integer NOT NULL,
    entity_id bigint NOT NULL,
    demographic_id integer NOT NULL,
    score integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    owner_id integer NOT NULL,
    group_id integer NOT NULL,
    originating_namespace character varying,
    originating_id text,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    CONSTRAINT score_0 CHECK ((score >= 0)),
    CONSTRAINT score_100 CHECK ((score <= 100))
);


--
-- TOC entry 271 (class 1259 OID 18110)
-- Name: reach_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.reach_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4196 (class 0 OID 0)
-- Dependencies: 271
-- Name: reach_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.reach_id_seq OWNED BY udm.reach.id;


--
-- TOC entry 272 (class 1259 OID 18111)
-- Name: sentiments; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.sentiments (
    id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    owner_id integer NOT NULL,
    group_id integer NOT NULL,
    value integer,
    towards_id integer,
    excerpt_id bigint NOT NULL,
    originating_namespace character varying,
    originating_id text,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    ml_value integer,
    ml_towards_id integer,
    CONSTRAINT value_100 CHECK ((value <= 100)),
    CONSTRAINT value_neg_100 CHECK ((value >= '-100'::integer))
);


--
-- TOC entry 273 (class 1259 OID 18122)
-- Name: sentiments_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.sentiments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4197 (class 0 OID 0)
-- Dependencies: 273
-- Name: sentiments_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.sentiments_id_seq OWNED BY udm.sentiments.id;


--
-- TOC entry 274 (class 1259 OID 18123)
-- Name: term_types; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.term_types (
    id integer NOT NULL,
    name character varying(255) NOT NULL
);


--
-- TOC entry 275 (class 1259 OID 18126)
-- Name: terms; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.terms (
    id integer NOT NULL,
    parent_id integer,
    type_id integer NOT NULL,
    entity_id bigint,
    name character varying(255) NOT NULL,
    description text,
    owner_id integer NOT NULL,
    group_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    originating_namespace character varying,
    originating_id text,
    archived boolean DEFAULT false NOT NULL,
    reference_id text,
    reference_schema text,
    reference_table text,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL
);


--
-- TOC entry 276 (class 1259 OID 18136)
-- Name: terms_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4198 (class 0 OID 0)
-- Dependencies: 276
-- Name: terms_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.terms_id_seq OWNED BY udm.terms.id;


--
-- TOC entry 277 (class 1259 OID 18137)
-- Name: video_asset_hosts; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.video_asset_hosts (
    id smallint NOT NULL,
    name text NOT NULL
);


--
-- TOC entry 278 (class 1259 OID 18142)
-- Name: videos; Type: TABLE; Schema: udm; Owner: -
--

CREATE TABLE udm.videos (
    id bigint NOT NULL,
    parent_id bigint,
    group_id integer NOT NULL,
    entity_id bigint,
    fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    ml_fields jsonb DEFAULT '{}'::jsonb NOT NULL,
    asset_host_id smallint,
    stream_id text,
    thumbnail_id text,
    title text,
    duration_ms integer DEFAULT 0 NOT NULL,
    originating_namespace text,
    originating_id text,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    approved boolean DEFAULT false NOT NULL,
    created_by text DEFAULT 'system'::text NOT NULL,
    modified_by text DEFAULT 'system'::text NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    CONSTRAINT videos_check CHECK ((parent_id <> id)),
    CONSTRAINT videos_check1 CHECK ((((asset_host_id IS NULL) AND (stream_id IS NULL) AND (thumbnail_id IS NULL)) OR ((asset_host_id IS NOT NULL) AND ((stream_id IS NOT NULL) OR (thumbnail_id IS NOT NULL))))),
    CONSTRAINT videos_duration_ms_check CHECK ((duration_ms >= 0))
);


--
-- TOC entry 279 (class 1259 OID 18160)
-- Name: videos_id_seq; Type: SEQUENCE; Schema: udm; Owner: -
--

CREATE SEQUENCE udm.videos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4199 (class 0 OID 0)
-- Dependencies: 279
-- Name: videos_id_seq; Type: SEQUENCE OWNED BY; Schema: udm; Owner: -
--

ALTER SEQUENCE udm.videos_id_seq OWNED BY udm.videos.id;


--
-- TOC entry 280 (class 1259 OID 18161)
-- Name: custom_fields; Type: TABLE; Schema: users; Owner: -
--

CREATE TABLE users.custom_fields (
    id integer NOT NULL,
    group_id integer NOT NULL,
    subject_type character varying NOT NULL,
    name character varying NOT NULL,
    parent_field_id integer,
    parent_field_lookup_id integer,
    mandatory boolean DEFAULT false NOT NULL,
    default_value integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    multi boolean DEFAULT false NOT NULL,
    CONSTRAINT either_field_or_lookup CHECK ((((parent_field_id IS NOT NULL) AND (parent_field_lookup_id IS NULL)) OR ((parent_field_id IS NULL) AND (parent_field_lookup_id IS NOT NULL))))
);


--
-- TOC entry 281 (class 1259 OID 18171)
-- Name: custom_fields_id_seq; Type: SEQUENCE; Schema: users; Owner: -
--

CREATE SEQUENCE users.custom_fields_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4200 (class 0 OID 0)
-- Dependencies: 281
-- Name: custom_fields_id_seq; Type: SEQUENCE OWNED BY; Schema: users; Owner: -
--

ALTER SEQUENCE users.custom_fields_id_seq OWNED BY users.custom_fields.id;


--
-- TOC entry 282 (class 1259 OID 18172)
-- Name: customers; Type: TABLE; Schema: users; Owner: -
--

CREATE TABLE users.customers (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    modified_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 283 (class 1259 OID 18177)
-- Name: customers_groups; Type: TABLE; Schema: users; Owner: -
--

CREATE TABLE users.customers_groups (
    customer_id integer NOT NULL,
    group_id integer NOT NULL
);


--
-- TOC entry 284 (class 1259 OID 18180)
-- Name: customers_id_seq; Type: SEQUENCE; Schema: users; Owner: -
--

CREATE SEQUENCE users.customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4201 (class 0 OID 0)
-- Dependencies: 284
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: users; Owner: -
--

ALTER SEQUENCE users.customers_id_seq OWNED BY users.customers.id;


--
-- TOC entry 285 (class 1259 OID 18181)
-- Name: group_config; Type: TABLE; Schema: users; Owner: -
--

CREATE TABLE users.group_config (
    group_id integer NOT NULL,
    type_id integer NOT NULL,
    config jsonb NOT NULL
);


--
-- TOC entry 286 (class 1259 OID 18186)
-- Name: group_config_types; Type: TABLE; Schema: users; Owner: -
--

CREATE TABLE users.group_config_types (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255) NOT NULL
);


--
-- TOC entry 287 (class 1259 OID 18191)
-- Name: groups; Type: TABLE; Schema: users; Owner: -
--

CREATE TABLE users.groups (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp(0) without time zone DEFAULT now() NOT NULL,
    modified_at timestamp(0) without time zone DEFAULT now() NOT NULL
);


--
-- TOC entry 288 (class 1259 OID 18196)
-- Name: groups_id_seq; Type: SEQUENCE; Schema: users; Owner: -
--

CREATE SEQUENCE users.groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4202 (class 0 OID 0)
-- Dependencies: 288
-- Name: groups_id_seq; Type: SEQUENCE OWNED BY; Schema: users; Owner: -
--

ALTER SEQUENCE users.groups_id_seq OWNED BY users.groups.id;


--
-- TOC entry 3672 (class 2604 OID 18197)
-- Name: alternate_names id; Type: DEFAULT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.alternate_names ALTER COLUMN id SET DEFAULT nextval('geonames.alternate_names_id_seq'::regclass);


--
-- TOC entry 3673 (class 2604 OID 18198)
-- Name: geonames id; Type: DEFAULT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.geonames ALTER COLUMN id SET DEFAULT nextval('geonames.geonames_id_seq'::regclass);


--
-- TOC entry 3681 (class 2604 OID 18199)
-- Name: goose_db_version id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goose_db_version ALTER COLUMN id SET DEFAULT nextval('public.goose_db_version_id_seq'::regclass);


--
-- TOC entry 3805 (class 2604 OID 19127)
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- TOC entry 3806 (class 2604 OID 19152)
-- Name: msg_excerpt id; Type: DEFAULT; Schema: queue; Owner: -
--

ALTER TABLE ONLY queue.msg_excerpt ALTER COLUMN id SET DEFAULT nextval('queue.msg_excerpt_id_seq'::regclass);


--
-- TOC entry 3694 (class 2604 OID 18200)
-- Name: post_named_entities post_named_entity_id; Type: DEFAULT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.post_named_entities ALTER COLUMN post_named_entity_id SET DEFAULT nextval('social_media.post_named_entities_post_named_entity_id_seq'::regclass);


--
-- TOC entry 3716 (class 2604 OID 18761)
-- Name: article_instances id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instances ALTER COLUMN id SET DEFAULT nextval('udm.article_instances_id_seq'::regclass);


--
-- TOC entry 3725 (class 2604 OID 18827)
-- Name: article_named_entities article_named_entity_id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_named_entities ALTER COLUMN article_named_entity_id SET DEFAULT nextval('udm.article_named_entities_article_named_entity_id_seq'::regclass);


--
-- TOC entry 3732 (class 2604 OID 18203)
-- Name: entities id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entities ALTER COLUMN id SET DEFAULT nextval('udm.entities_id_seq'::regclass);


--
-- TOC entry 3738 (class 2604 OID 18204)
-- Name: entity_alternate_names id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_alternate_names ALTER COLUMN id SET DEFAULT nextval('udm.entity_alternate_names_id_seq'::regclass);


--
-- TOC entry 3761 (class 2604 OID 18205)
-- Name: excerpts id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.excerpts ALTER COLUMN id SET DEFAULT nextval('udm.excerpts_id_seq'::regclass);


--
-- TOC entry 3767 (class 2604 OID 18206)
-- Name: reach id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.reach ALTER COLUMN id SET DEFAULT nextval('udm.reach_id_seq'::regclass);


--
-- TOC entry 3772 (class 2604 OID 18207)
-- Name: sentiments id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.sentiments ALTER COLUMN id SET DEFAULT nextval('udm.sentiments_id_seq'::regclass);


--
-- TOC entry 3777 (class 2604 OID 18208)
-- Name: terms id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.terms ALTER COLUMN id SET DEFAULT nextval('udm.terms_id_seq'::regclass);


--
-- TOC entry 3783 (class 2604 OID 18209)
-- Name: videos id; Type: DEFAULT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.videos ALTER COLUMN id SET DEFAULT nextval('udm.videos_id_seq'::regclass);


--
-- TOC entry 3794 (class 2604 OID 18210)
-- Name: custom_fields id; Type: DEFAULT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.custom_fields ALTER COLUMN id SET DEFAULT nextval('users.custom_fields_id_seq'::regclass);


--
-- TOC entry 3799 (class 2604 OID 18211)
-- Name: customers id; Type: DEFAULT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.customers ALTER COLUMN id SET DEFAULT nextval('users.customers_id_seq'::regclass);


--
-- TOC entry 3802 (class 2604 OID 18212)
-- Name: groups id; Type: DEFAULT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.groups ALTER COLUMN id SET DEFAULT nextval('users.groups_id_seq'::regclass);


--
-- TOC entry 3816 (class 2606 OID 18214)
-- Name: ethnic ethnic_pkey; Type: CONSTRAINT; Schema: cameo; Owner: -
--

ALTER TABLE ONLY cameo.ethnic
    ADD CONSTRAINT ethnic_pkey PRIMARY KEY (id);


--
-- TOC entry 3818 (class 2606 OID 18216)
-- Name: religion religion_pkey; Type: CONSTRAINT; Schema: cameo; Owner: -
--

ALTER TABLE ONLY cameo.religion
    ADD CONSTRAINT religion_pkey PRIMARY KEY (id);


--
-- TOC entry 3820 (class 2606 OID 18218)
-- Name: events events_pkey; Type: CONSTRAINT; Schema: events; Owner: -
--

ALTER TABLE ONLY events.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- TOC entry 3823 (class 2606 OID 18220)
-- Name: alternate_names alternate_names_pkey; Type: CONSTRAINT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.alternate_names
    ADD CONSTRAINT alternate_names_pkey PRIMARY KEY (geoname_id, id);


--
-- TOC entry 3827 (class 2606 OID 18222)
-- Name: boundaries boundaries_pkey; Type: CONSTRAINT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.boundaries
    ADD CONSTRAINT boundaries_pkey PRIMARY KEY (geoname_id);


--
-- TOC entry 3829 (class 2606 OID 18224)
-- Name: country_info country_info_pkey; Type: CONSTRAINT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.country_info
    ADD CONSTRAINT country_info_pkey PRIMARY KEY (geoname_id);


--
-- TOC entry 3831 (class 2606 OID 18226)
-- Name: feature_codes feature_codes_pkey; Type: CONSTRAINT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.feature_codes
    ADD CONSTRAINT feature_codes_pkey PRIMARY KEY (class, code);


--
-- TOC entry 3834 (class 2606 OID 18228)
-- Name: geonames geonames_pkey; Type: CONSTRAINT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.geonames
    ADD CONSTRAINT geonames_pkey PRIMARY KEY (id);


--
-- TOC entry 3837 (class 2606 OID 18230)
-- Name: article_instance_last_modified article_instance_last_modified_pkey; Type: CONSTRAINT; Schema: nma; Owner: -
--

ALTER TABLE ONLY nma.article_instance_last_modified
    ADD CONSTRAINT article_instance_last_modified_pkey PRIMARY KEY (article_instance_id, group_id);


--
-- TOC entry 3839 (class 2606 OID 18941)
-- Name: article_instance_metadata article_instance_metadata_pkey; Type: CONSTRAINT; Schema: nma; Owner: -
--

ALTER TABLE ONLY nma.article_instance_metadata
    ADD CONSTRAINT article_instance_metadata_pkey PRIMARY KEY (article_instance_id, group_id);


--
-- TOC entry 3841 (class 2606 OID 18234)
-- Name: article_instance_statuses article_instance_statuses_pkey; Type: CONSTRAINT; Schema: nma; Owner: -
--

ALTER TABLE ONLY nma.article_instance_statuses
    ADD CONSTRAINT article_instance_statuses_pkey PRIMARY KEY (id);


--
-- TOC entry 3843 (class 2606 OID 18236)
-- Name: metadata_counts metadata_counts_pkey; Type: CONSTRAINT; Schema: nma; Owner: -
--

ALTER TABLE ONLY nma.metadata_counts
    ADD CONSTRAINT metadata_counts_pkey PRIMARY KEY (group_id, user_id, status_id);


--
-- TOC entry 3845 (class 2606 OID 18240)
-- Name: goose_db_version goose_db_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.goose_db_version
    ADD CONSTRAINT goose_db_version_pkey PRIMARY KEY (id);


--
-- TOC entry 3982 (class 2606 OID 19129)
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- TOC entry 3984 (class 2606 OID 19154)
-- Name: msg_excerpt msg_excerpt_pkey; Type: CONSTRAINT; Schema: queue; Owner: -
--

ALTER TABLE ONLY queue.msg_excerpt
    ADD CONSTRAINT msg_excerpt_pkey PRIMARY KEY (id);


--
-- TOC entry 3848 (class 2606 OID 18242)
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id);


--
-- TOC entry 3853 (class 2606 OID 18244)
-- Name: link_types link_types_pkey; Type: CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.link_types
    ADD CONSTRAINT link_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3855 (class 2606 OID 18246)
-- Name: links links_pkey; Type: CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.links
    ADD CONSTRAINT links_pkey PRIMARY KEY (id, author_id);


--
-- TOC entry 3858 (class 2606 OID 18248)
-- Name: post_named_entities post_named_entities_pkey; Type: CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.post_named_entities
    ADD CONSTRAINT post_named_entities_pkey PRIMARY KEY (post_id, post_named_entity_id);


--
-- TOC entry 3863 (class 2606 OID 18250)
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id, author_id);


--
-- TOC entry 3867 (class 2606 OID 18252)
-- Name: statuses statuses_pkey; Type: CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.statuses
    ADD CONSTRAINT statuses_pkey PRIMARY KEY (id);


--
-- TOC entry 3872 (class 2606 OID 18679)
-- Name: article_instance_fields article_instance_fields_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instance_fields
    ADD CONSTRAINT article_instance_fields_pkey PRIMARY KEY (article_instance_id, group_id);


--
-- TOC entry 3874 (class 2606 OID 19004)
-- Name: article_instance_metadata article_instance_metadata_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instance_metadata
    ADD CONSTRAINT article_instance_metadata_pkey PRIMARY KEY (article_instance_id, group_id);


--
-- TOC entry 3877 (class 2606 OID 18258)
-- Name: article_instance_metadata_types article_instance_metadata_types_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instance_metadata_types
    ADD CONSTRAINT article_instance_metadata_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3879 (class 2606 OID 19036)
-- Name: article_instance_text article_instance_text_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instance_text
    ADD CONSTRAINT article_instance_text_pkey PRIMARY KEY (article_instance_id, group_id);


--
-- TOC entry 3888 (class 2606 OID 18804)
-- Name: article_instances_authors article_instances_authors_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instances_authors
    ADD CONSTRAINT article_instances_authors_pkey PRIMARY KEY (article_instance_id, author_id, group_id);


--
-- TOC entry 3884 (class 2606 OID 19038)
-- Name: article_instances article_instances_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instances
    ADD CONSTRAINT article_instances_pkey PRIMARY KEY (group_id, id);


--
-- TOC entry 3891 (class 2606 OID 18829)
-- Name: article_named_entities article_named_entities_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_named_entities
    ADD CONSTRAINT article_named_entities_pkey PRIMARY KEY (article_id, article_named_entity_id);


--
-- TOC entry 3894 (class 2606 OID 18268)
-- Name: article_texts article_texts_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_texts
    ADD CONSTRAINT article_texts_pkey PRIMARY KEY (article_text_id, group_id);


--
-- TOC entry 3898 (class 2606 OID 18270)
-- Name: entities entities_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entities
    ADD CONSTRAINT entities_pkey PRIMARY KEY (id, group_id);


--
-- TOC entry 3904 (class 2606 OID 18272)
-- Name: entity_alternate_names entity_alternate_names_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_alternate_names
    ADD CONSTRAINT entity_alternate_names_pkey PRIMARY KEY (id, group_id);


--
-- TOC entry 3907 (class 2606 OID 18274)
-- Name: entity_counts entity_counts_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_counts
    ADD CONSTRAINT entity_counts_pkey PRIMARY KEY (entity_id, group_id);


--
-- TOC entry 3910 (class 2606 OID 18276)
-- Name: entity_fields entity_fields_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_fields
    ADD CONSTRAINT entity_fields_pkey PRIMARY KEY (entity_id, group_id);


--
-- TOC entry 3912 (class 2606 OID 18278)
-- Name: entity_predicate_types entity_predicate_types_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_predicate_types
    ADD CONSTRAINT entity_predicate_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3915 (class 2606 OID 18280)
-- Name: entity_relations entity_relations_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_relations
    ADD CONSTRAINT entity_relations_pkey PRIMARY KEY (subject_id, predicate_id, object_id, group_id);


--
-- TOC entry 3918 (class 2606 OID 18282)
-- Name: entity_types entity_types_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_types
    ADD CONSTRAINT entity_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3923 (class 2606 OID 19086)
-- Name: excerpt_fields excerpt_fields_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.excerpt_fields
    ADD CONSTRAINT excerpt_fields_pkey PRIMARY KEY (excerpt_id, group_id);


--
-- TOC entry 3929 (class 2606 OID 18742)
-- Name: excerpts excerpts_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.excerpts
    ADD CONSTRAINT excerpts_pkey PRIMARY KEY (id, group_id, article_instance_id);


--
-- TOC entry 3933 (class 2606 OID 18288)
-- Name: origins origins_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.origins
    ADD CONSTRAINT origins_pkey PRIMARY KEY (id);


--
-- TOC entry 3935 (class 2606 OID 18291)
-- Name: reach reach_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.reach
    ADD CONSTRAINT reach_pkey PRIMARY KEY (id, group_id);


--
-- TOC entry 3939 (class 2606 OID 18293)
-- Name: sentiments sentiments_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.sentiments
    ADD CONSTRAINT sentiments_pkey PRIMARY KEY (id, group_id);


--
-- TOC entry 3942 (class 2606 OID 18295)
-- Name: term_types term_types_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.term_types
    ADD CONSTRAINT term_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3944 (class 2606 OID 18297)
-- Name: terms terms_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.terms
    ADD CONSTRAINT terms_pkey PRIMARY KEY (id, group_id);


--
-- TOC entry 3950 (class 2606 OID 18299)
-- Name: video_asset_hosts video_asset_hosts_name_key; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.video_asset_hosts
    ADD CONSTRAINT video_asset_hosts_name_key UNIQUE (name);


--
-- TOC entry 3952 (class 2606 OID 18301)
-- Name: video_asset_hosts video_asset_hosts_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.video_asset_hosts
    ADD CONSTRAINT video_asset_hosts_pkey PRIMARY KEY (id);


--
-- TOC entry 3959 (class 2606 OID 18303)
-- Name: videos videos_asset_host_id_stream_id_group_id_key; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.videos
    ADD CONSTRAINT videos_asset_host_id_stream_id_group_id_key UNIQUE (asset_host_id, stream_id, group_id);


--
-- TOC entry 3961 (class 2606 OID 18305)
-- Name: videos videos_asset_host_id_thumbnail_id_group_id_key; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.videos
    ADD CONSTRAINT videos_asset_host_id_thumbnail_id_group_id_key UNIQUE (asset_host_id, thumbnail_id, group_id);


--
-- TOC entry 3966 (class 2606 OID 18307)
-- Name: videos videos_pkey; Type: CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.videos
    ADD CONSTRAINT videos_pkey PRIMARY KEY (id, group_id);


--
-- TOC entry 3970 (class 2606 OID 18309)
-- Name: custom_fields custom_fields_pkey; Type: CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.custom_fields
    ADD CONSTRAINT custom_fields_pkey PRIMARY KEY (id, group_id);


--
-- TOC entry 3974 (class 2606 OID 18311)
-- Name: customers_groups customers_groups_pkey; Type: CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.customers_groups
    ADD CONSTRAINT customers_groups_pkey PRIMARY KEY (customer_id, group_id);


--
-- TOC entry 3972 (class 2606 OID 18313)
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- TOC entry 3976 (class 2606 OID 18315)
-- Name: group_config group_config_pkey; Type: CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.group_config
    ADD CONSTRAINT group_config_pkey PRIMARY KEY (group_id, type_id);


--
-- TOC entry 3978 (class 2606 OID 18317)
-- Name: group_config_types group_config_types_pkey; Type: CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.group_config_types
    ADD CONSTRAINT group_config_types_pkey PRIMARY KEY (id);


--
-- TOC entry 3980 (class 2606 OID 18319)
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- TOC entry 3821 (class 1259 OID 18320)
-- Name: alternate_names_orig_idx; Type: INDEX; Schema: geonames; Owner: -
--

CREATE INDEX alternate_names_orig_idx ON geonames.alternate_names USING btree (originating_id);


--
-- TOC entry 3825 (class 1259 OID 18321)
-- Name: boundaries_info_orig_idx; Type: INDEX; Schema: geonames; Owner: -
--

CREATE INDEX boundaries_info_orig_idx ON geonames.boundaries USING btree (originating_id);


--
-- TOC entry 3832 (class 1259 OID 18322)
-- Name: geonames_orig_idx; Type: INDEX; Schema: geonames; Owner: -
--

CREATE INDEX geonames_orig_idx ON geonames.geonames USING btree (originating_id);


--
-- TOC entry 3824 (class 1259 OID 18323)
-- Name: trgm_idx_alternate_names_name; Type: INDEX; Schema: geonames; Owner: -
--

CREATE INDEX trgm_idx_alternate_names_name ON geonames.alternate_names USING gin (name public.gin_trgm_ops);


--
-- TOC entry 3835 (class 1259 OID 18324)
-- Name: trgm_idx_geonames_name; Type: INDEX; Schema: geonames; Owner: -
--

CREATE INDEX trgm_idx_geonames_name ON geonames.geonames USING gin (name public.gin_trgm_ops);


--
-- TOC entry 3860 (class 1259 OID 18325)
-- Name: created_at_idx; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX created_at_idx ON social_media.posts USING brin (created_at);


--
-- TOC entry 3846 (class 1259 OID 18326)
-- Name: entities_name; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX entities_name ON social_media.entities USING btree (name);


--
-- TOC entry 3856 (class 1259 OID 18327)
-- Name: links_social_media_author; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX links_social_media_author ON social_media.links USING btree (social_media_id, author_id);


--
-- TOC entry 3859 (class 1259 OID 18328)
-- Name: post_named_entities_post_id_type_value_uindex; Type: INDEX; Schema: social_media; Owner: -
--

CREATE UNIQUE INDEX post_named_entities_post_id_type_value_uindex ON social_media.post_named_entities USING btree (post_id, type, value);


--
-- TOC entry 3861 (class 1259 OID 18329)
-- Name: post_origination_idx; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX post_origination_idx ON social_media.posts USING btree (originating_namespace, originating_id);


--
-- TOC entry 3864 (class 1259 OID 18330)
-- Name: posts_publication_time; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX posts_publication_time ON social_media.posts USING btree (publication_time);


--
-- TOC entry 3849 (class 1259 OID 18331)
-- Name: social_media_entity_data_idx; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX social_media_entity_data_idx ON social_media.entities USING gin (data);


--
-- TOC entry 3850 (class 1259 OID 18332)
-- Name: social_media_entity_fields_idx; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX social_media_entity_fields_idx ON social_media.entities USING gin (fields);


--
-- TOC entry 3851 (class 1259 OID 18333)
-- Name: social_media_entity_origination_idx; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX social_media_entity_origination_idx ON social_media.entities USING btree (originating_namespace, originating_id);


--
-- TOC entry 3865 (class 1259 OID 18334)
-- Name: social_media_idx; Type: INDEX; Schema: social_media; Owner: -
--

CREATE INDEX social_media_idx ON social_media.posts USING gin (data, fields, tsv);


--
-- TOC entry 3892 (class 1259 OID 18710)
-- Name: article_id_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_id_idx ON udm.article_texts USING btree (article_id, group_id);


--
-- TOC entry 3868 (class 1259 OID 18694)
-- Name: article_instance_audit_log_article_instance_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_instance_audit_log_article_instance_idx ON udm.article_instance_audit_log USING btree (article_instance_id, group_id);


--
-- TOC entry 3869 (class 1259 OID 18337)
-- Name: article_instance_fields_gin; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_instance_fields_gin ON udm.article_instance_fields USING gin (((ml_data || data)));


--
-- TOC entry 3870 (class 1259 OID 18680)
-- Name: article_instance_fields_modified_at_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_instance_fields_modified_at_idx ON udm.article_instance_fields USING btree (article_instance_id, modified_at);


--
-- TOC entry 3881 (class 1259 OID 18339)
-- Name: article_instance_modified_at_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_instance_modified_at_idx ON udm.article_instances USING btree (modified_at);


--
-- TOC entry 3882 (class 1259 OID 18340)
-- Name: article_instance_organization_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_instance_organization_idx ON udm.article_instances USING btree (organization_id);


--
-- TOC entry 3880 (class 1259 OID 18341)
-- Name: article_instance_text_text_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_instance_text_text_idx ON udm.article_instance_text USING gin (tsv);


--
-- TOC entry 3886 (class 1259 OID 18342)
-- Name: article_instances_authors_author_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_instances_authors_author_idx ON udm.article_instances_authors USING btree (author_id);


--
-- TOC entry 3889 (class 1259 OID 18819)
-- Name: article_named_entities_article_id_type_value_uindex; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX article_named_entities_article_id_type_value_uindex ON udm.article_named_entities USING btree (article_id, type, value);


--
-- TOC entry 3895 (class 1259 OID 18344)
-- Name: article_texts_tsv_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX article_texts_tsv_idx ON udm.article_texts USING gin (tsv);


--
-- TOC entry 3901 (class 1259 OID 18345)
-- Name: entity_alt_name_uniq; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX entity_alt_name_uniq ON udm.entity_alternate_names USING btree (group_id, lower(btrim((name)::text)));


--
-- TOC entry 3902 (class 1259 OID 18346)
-- Name: entity_alternate_names_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX entity_alternate_names_idx ON udm.entity_alternate_names USING btree (entity_id);


--
-- TOC entry 3899 (class 1259 OID 18347)
-- Name: entity_data_gin; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX entity_data_gin ON udm.entities USING gin (data);


--
-- TOC entry 3908 (class 1259 OID 18348)
-- Name: entity_fields_gin; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX entity_fields_gin ON udm.entity_fields USING gin (((ml_data || data)));


--
-- TOC entry 3920 (class 1259 OID 18349)
-- Name: excerpt_fields_gin; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX excerpt_fields_gin ON udm.excerpt_fields USING gin (((ml_data || data)));


--
-- TOC entry 3921 (class 1259 OID 19087)
-- Name: excerpt_fields_modified_at_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX excerpt_fields_modified_at_idx ON udm.excerpt_fields USING btree (excerpt_id, modified_at);


--
-- TOC entry 3924 (class 1259 OID 18351)
-- Name: excerpt_geoname_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX excerpt_geoname_idx ON udm.excerpts USING btree (geoname_id) WHERE (geoname_id IS NOT NULL);


--
-- TOC entry 3925 (class 1259 OID 18352)
-- Name: excerpt_id_uniq_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX excerpt_id_uniq_idx ON udm.excerpts USING btree (id, group_id);


--
-- TOC entry 3926 (class 1259 OID 18353)
-- Name: excerpt_source_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX excerpt_source_idx ON udm.excerpts USING btree (source_id);


--
-- TOC entry 3927 (class 1259 OID 18743)
-- Name: excerpts_article_instance_modified_at_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX excerpts_article_instance_modified_at_idx ON udm.excerpts USING btree (article_instance_id, group_id, modified_at);


--
-- TOC entry 3930 (class 1259 OID 18355)
-- Name: excerpts_text_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX excerpts_text_idx ON udm.excerpts USING gin (tsv);


--
-- TOC entry 3936 (class 1259 OID 18356)
-- Name: sentiment_excerpt_unq; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX sentiment_excerpt_unq ON udm.sentiments USING btree (group_id, excerpt_id);


--
-- TOC entry 3937 (class 1259 OID 18357)
-- Name: sentiments_modified_at_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX sentiments_modified_at_idx ON udm.sentiments USING btree (excerpt_id, modified_at);


--
-- TOC entry 3945 (class 1259 OID 18358)
-- Name: terms_references_unq; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX terms_references_unq ON udm.terms USING btree (group_id, parent_id, reference_schema, reference_table, reference_id) WHERE ((reference_id IS NOT NULL) AND (reference_schema IS NOT NULL) AND (reference_table IS NOT NULL));


--
-- TOC entry 3900 (class 1259 OID 18359)
-- Name: tgrm_entity_name_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX tgrm_entity_name_idx ON udm.entities USING gin (name public.gin_trgm_ops);


--
-- TOC entry 3905 (class 1259 OID 18360)
-- Name: trgm_entity_alternate_names_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX trgm_entity_alternate_names_idx ON udm.entity_alternate_names USING gin (name public.gin_trgm_ops);


--
-- TOC entry 3875 (class 1259 OID 18924)
-- Name: udm_article_metadata_modified_at_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX udm_article_metadata_modified_at_idx ON udm.article_instance_metadata USING btree (article_instance_id, modified_at);


--
-- TOC entry 3953 (class 1259 OID 18362)
-- Name: udm_videos_data_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX udm_videos_data_idx ON udm.videos USING gin (data);


--
-- TOC entry 3954 (class 1259 OID 18363)
-- Name: udm_videos_fields_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX udm_videos_fields_idx ON udm.videos USING gin (((ml_fields || fields)));


--
-- TOC entry 3955 (class 1259 OID 18364)
-- Name: udm_videos_originating_uniq_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX udm_videos_originating_uniq_idx ON udm.videos USING btree (originating_namespace, originating_id, group_id) WHERE (parent_id IS NULL);


--
-- TOC entry 3896 (class 1259 OID 18711)
-- Name: uniq_article_texts_by_group_article_lang; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX uniq_article_texts_by_group_article_lang ON udm.article_texts USING btree (group_id, article_id, lang_639_1);


--
-- TOC entry 3885 (class 1259 OID 18366)
-- Name: unique_article_instances_by_origination; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_article_instances_by_origination ON udm.article_instances USING btree (originating_namespace, originating_id, group_id);


--
-- TOC entry 3913 (class 1259 OID 18367)
-- Name: unique_entity_predicate_types_by_name; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_entity_predicate_types_by_name ON udm.entity_predicate_types USING btree (name);


--
-- TOC entry 3916 (class 1259 OID 18368)
-- Name: unique_entity_relations_by_subject_predicate_object; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_entity_relations_by_subject_predicate_object ON udm.entity_relations USING btree (subject_id, predicate_id, object_id, group_id);


--
-- TOC entry 3919 (class 1259 OID 18369)
-- Name: unique_entity_types_by_name; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_entity_types_by_name ON udm.entity_types USING btree (name);


--
-- TOC entry 3931 (class 1259 OID 18370)
-- Name: unique_excerpts_by_origination; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_excerpts_by_origination ON udm.excerpts USING btree (originating_namespace, originating_id, group_id);


--
-- TOC entry 3940 (class 1259 OID 18371)
-- Name: unique_sentiments_by_origination; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_sentiments_by_origination ON udm.sentiments USING btree (originating_namespace, originating_id, group_id);


--
-- TOC entry 3946 (class 1259 OID 18372)
-- Name: unique_terms_name_owner; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_terms_name_owner ON udm.terms USING btree (name, type_id, group_id) WHERE (parent_id IS NULL);


--
-- TOC entry 3947 (class 1259 OID 18373)
-- Name: unique_terms_name_parent_owner; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_terms_name_parent_owner ON udm.terms USING btree (name, type_id, parent_id, group_id) WHERE (parent_id IS NOT NULL);


--
-- TOC entry 3948 (class 1259 OID 18374)
-- Name: unique_terms_originating_info; Type: INDEX; Schema: udm; Owner: -
--

CREATE UNIQUE INDEX unique_terms_originating_info ON udm.terms USING btree (originating_namespace, originating_id, type_id, group_id);


--
-- TOC entry 3956 (class 1259 OID 18375)
-- Name: videos_approved_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX videos_approved_idx ON udm.videos USING btree (approved, parent_id, group_id);


--
-- TOC entry 3957 (class 1259 OID 18376)
-- Name: videos_archived_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX videos_archived_idx ON udm.videos USING btree (archived);


--
-- TOC entry 3962 (class 1259 OID 18377)
-- Name: videos_data_created_at_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX videos_data_created_at_idx ON udm.videos USING btree (udm.text_to_timestamptz((data ->> 'created_at'::text), 'YYYY-MM-DD"T"HH24:MI:SSZ'::text), parent_id, group_id);


--
-- TOC entry 3963 (class 1259 OID 18378)
-- Name: videos_data_detected_at_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX videos_data_detected_at_idx ON udm.videos USING btree (udm.text_to_timestamptz((data ->> 'detected_at'::text), 'YYYY-MM-DD"T"HH24:MI:SSZ'::text), parent_id, group_id);


--
-- TOC entry 3964 (class 1259 OID 18379)
-- Name: videos_data_parent_originating_id_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX videos_data_parent_originating_id_idx ON udm.videos USING btree (((data ->> 'parent_originating_id'::text)), parent_id, group_id);


--
-- TOC entry 3967 (class 1259 OID 18380)
-- Name: videos_title_trgm_idx; Type: INDEX; Schema: udm; Owner: -
--

CREATE INDEX videos_title_trgm_idx ON udm.videos USING gin (title public.gin_trgm_ops);


--
-- TOC entry 3968 (class 1259 OID 18381)
-- Name: custom_field_uniq; Type: INDEX; Schema: users; Owner: -
--

CREATE UNIQUE INDEX custom_field_uniq ON users.custom_fields USING btree (group_id, subject_type, name);


--
-- TOC entry 4014 (class 2620 OID 18382)
-- Name: entities update_modified_at; Type: TRIGGER; Schema: social_media; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON social_media.entities FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4015 (class 2620 OID 18383)
-- Name: links update_modified_at; Type: TRIGGER; Schema: social_media; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON social_media.links FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4016 (class 2620 OID 18384)
-- Name: posts update_modified_at; Type: TRIGGER; Schema: social_media; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON social_media.posts FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4024 (class 2620 OID 19182)
-- Name: excerpt_fields msg_excerpt_fields_trg; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER msg_excerpt_fields_trg AFTER INSERT OR UPDATE ON udm.excerpt_fields FOR EACH ROW EXECUTE FUNCTION udm.msg_excerpt_fields();


--
-- TOC entry 4026 (class 2620 OID 19160)
-- Name: excerpts msg_excerpt_trg; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER msg_excerpt_trg AFTER INSERT OR UPDATE ON udm.excerpts FOR EACH ROW EXECUTE FUNCTION udm.msg_excerpt();


--
-- TOC entry 4029 (class 2620 OID 19166)
-- Name: sentiments msg_sentiments_trg; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER msg_sentiments_trg AFTER INSERT OR UPDATE ON udm.sentiments FOR EACH ROW EXECUTE FUNCTION udm.msg_excerpt();


--
-- TOC entry 4020 (class 2620 OID 18385)
-- Name: entity_alternate_names update_entity_names_modtime; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_entity_names_modtime BEFORE UPDATE ON udm.entity_alternate_names FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4017 (class 2620 OID 18386)
-- Name: article_instance_fields update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.article_instance_fields FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4018 (class 2620 OID 18387)
-- Name: article_instances update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.article_instances FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4019 (class 2620 OID 18388)
-- Name: entities update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.entities FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4021 (class 2620 OID 18389)
-- Name: entity_alternate_names update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.entity_alternate_names FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4022 (class 2620 OID 18390)
-- Name: entity_fields update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.entity_fields FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4023 (class 2620 OID 18391)
-- Name: entity_relations update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.entity_relations FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4025 (class 2620 OID 18392)
-- Name: excerpt_fields update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.excerpt_fields FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4027 (class 2620 OID 18393)
-- Name: excerpts update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.excerpts FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4028 (class 2620 OID 18394)
-- Name: reach update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.reach FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4030 (class 2620 OID 18395)
-- Name: sentiments update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.sentiments FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4031 (class 2620 OID 18396)
-- Name: terms update_modified_at; Type: TRIGGER; Schema: udm; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON udm.terms FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4032 (class 2620 OID 18397)
-- Name: custom_fields update_modified_at; Type: TRIGGER; Schema: users; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON users.custom_fields FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4033 (class 2620 OID 18398)
-- Name: customers update_modified_at; Type: TRIGGER; Schema: users; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON users.customers FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 4034 (class 2620 OID 18399)
-- Name: groups update_modified_at; Type: TRIGGER; Schema: users; Owner: -
--

CREATE TRIGGER update_modified_at BEFORE UPDATE ON users.groups FOR EACH ROW EXECUTE FUNCTION public.update_modified_column();


--
-- TOC entry 3985 (class 2606 OID 18400)
-- Name: alternate_names fk_alternate_names_geoname_1; Type: FK CONSTRAINT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.alternate_names
    ADD CONSTRAINT fk_alternate_names_geoname_1 FOREIGN KEY (geoname_id) REFERENCES geonames.geonames(id) ON DELETE CASCADE;


--
-- TOC entry 3986 (class 2606 OID 18405)
-- Name: boundaries fk_boundries_geoname_1; Type: FK CONSTRAINT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.boundaries
    ADD CONSTRAINT fk_boundries_geoname_1 FOREIGN KEY (geoname_id) REFERENCES geonames.geonames(id) ON DELETE CASCADE;


--
-- TOC entry 3987 (class 2606 OID 18410)
-- Name: country_info fk_country_info_geoname_1; Type: FK CONSTRAINT; Schema: geonames; Owner: -
--

ALTER TABLE ONLY geonames.country_info
    ADD CONSTRAINT fk_country_info_geoname_1 FOREIGN KEY (geoname_id) REFERENCES geonames.geonames(id) ON DELETE CASCADE;


--
-- TOC entry 3988 (class 2606 OID 19059)
-- Name: article_instance_metadata article_instance_statuses_article_instance_id_fkey; Type: FK CONSTRAINT; Schema: nma; Owner: -
--

ALTER TABLE ONLY nma.article_instance_metadata
    ADD CONSTRAINT article_instance_statuses_article_instance_id_fkey FOREIGN KEY (group_id, article_instance_id) REFERENCES udm.article_instances(group_id, id) NOT VALID;


--
-- TOC entry 3989 (class 2606 OID 18420)
-- Name: links fk_social_media; Type: FK CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.links
    ADD CONSTRAINT fk_social_media FOREIGN KEY (social_media_id, author_id) REFERENCES social_media.posts(id, author_id) ON DELETE CASCADE;


--
-- TOC entry 3990 (class 2606 OID 18425)
-- Name: links links_link_type_id_fkey; Type: FK CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.links
    ADD CONSTRAINT links_link_type_id_fkey FOREIGN KEY (link_type_id) REFERENCES social_media.link_types(id);


--
-- TOC entry 3991 (class 2606 OID 18430)
-- Name: posts posts_author_id_fkey; Type: FK CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.posts
    ADD CONSTRAINT posts_author_id_fkey FOREIGN KEY (author_id) REFERENCES social_media.entities(id) ON DELETE CASCADE;


--
-- TOC entry 3992 (class 2606 OID 18435)
-- Name: posts posts_status_id_fkey; Type: FK CONSTRAINT; Schema: social_media; Owner: -
--

ALTER TABLE ONLY social_media.posts
    ADD CONSTRAINT posts_status_id_fkey FOREIGN KEY (status_id) REFERENCES social_media.statuses(id);


--
-- TOC entry 3994 (class 2606 OID 19064)
-- Name: article_instance_metadata article_instance_id,group_id; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instance_metadata
    ADD CONSTRAINT "article_instance_id,group_id" FOREIGN KEY (type_id) REFERENCES udm.article_instance_metadata_types(id) NOT VALID;


--
-- TOC entry 3995 (class 2606 OID 19049)
-- Name: article_instance_metadata article_instance_metadata_article_instance_id_fkey; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instance_metadata
    ADD CONSTRAINT article_instance_metadata_article_instance_id_fkey FOREIGN KEY (group_id, article_instance_id) REFERENCES udm.article_instances(group_id, id) NOT VALID;


--
-- TOC entry 3996 (class 2606 OID 19044)
-- Name: article_instances_authors article_instances_authors_article_instance_id_fkey; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instances_authors
    ADD CONSTRAINT article_instances_authors_article_instance_id_fkey FOREIGN KEY (group_id, article_instance_id) REFERENCES udm.article_instances(group_id, id) NOT VALID;


--
-- TOC entry 3997 (class 2606 OID 18460)
-- Name: article_instances_authors article_instances_authors_author_id_fkey; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instances_authors
    ADD CONSTRAINT article_instances_authors_author_id_fkey FOREIGN KEY (author_id, group_id) REFERENCES udm.entities(id, group_id) ON DELETE CASCADE;


--
-- TOC entry 3999 (class 2606 OID 18465)
-- Name: entity_counts entity_counts_entity_id_fkey; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_counts
    ADD CONSTRAINT entity_counts_entity_id_fkey FOREIGN KEY (entity_id, group_id) REFERENCES udm.entities(id, group_id) ON DELETE CASCADE;


--
-- TOC entry 3998 (class 2606 OID 18470)
-- Name: entity_alternate_names fk_altnames_entity_id; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_alternate_names
    ADD CONSTRAINT fk_altnames_entity_id FOREIGN KEY (entity_id, group_id) REFERENCES udm.entities(id, group_id) ON DELETE CASCADE;


--
-- TOC entry 3993 (class 2606 OID 19054)
-- Name: article_instance_fields fk_article_instance; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.article_instance_fields
    ADD CONSTRAINT fk_article_instance FOREIGN KEY (group_id, article_instance_id) REFERENCES udm.article_instances(group_id, id) NOT VALID;


--
-- TOC entry 4002 (class 2606 OID 19039)
-- Name: excerpts fk_article_instance_id; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.excerpts
    ADD CONSTRAINT fk_article_instance_id FOREIGN KEY (group_id, article_instance_id) REFERENCES udm.article_instances(group_id, id) NOT VALID;


--
-- TOC entry 4000 (class 2606 OID 18485)
-- Name: entity_fields fk_entity; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.entity_fields
    ADD CONSTRAINT fk_entity FOREIGN KEY (entity_id, group_id) REFERENCES udm.entities(id, group_id) ON DELETE CASCADE;


--
-- TOC entry 4004 (class 2606 OID 18490)
-- Name: sentiments fk_excerpt_id; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.sentiments
    ADD CONSTRAINT fk_excerpt_id FOREIGN KEY (excerpt_id, group_id) REFERENCES udm.excerpts(id, group_id) ON DELETE CASCADE;


--
-- TOC entry 4001 (class 2606 OID 19088)
-- Name: excerpt_fields fk_excerpt_id; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.excerpt_fields
    ADD CONSTRAINT fk_excerpt_id FOREIGN KEY (excerpt_id, group_id) REFERENCES udm.excerpts(id, group_id) ON DELETE CASCADE;


--
-- TOC entry 4005 (class 2606 OID 18726)
-- Name: sentiments fk_ml_towards_id; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.sentiments
    ADD CONSTRAINT fk_ml_towards_id FOREIGN KEY (ml_towards_id, group_id) REFERENCES udm.terms(id, group_id);


--
-- TOC entry 4003 (class 2606 OID 18505)
-- Name: excerpts fk_source_id; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.excerpts
    ADD CONSTRAINT fk_source_id FOREIGN KEY (source_id, group_id) REFERENCES udm.entities(id, group_id);


--
-- TOC entry 4006 (class 2606 OID 18953)
-- Name: sentiments fk_towards_id; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.sentiments
    ADD CONSTRAINT fk_towards_id FOREIGN KEY (towards_id, group_id) REFERENCES udm.terms(id, group_id);


--
-- TOC entry 4007 (class 2606 OID 18515)
-- Name: videos videos_asset_host_id_fkey; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.videos
    ADD CONSTRAINT videos_asset_host_id_fkey FOREIGN KEY (asset_host_id) REFERENCES udm.video_asset_hosts(id);


--
-- TOC entry 4008 (class 2606 OID 18520)
-- Name: videos videos_entity_id_group_id_fkey; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.videos
    ADD CONSTRAINT videos_entity_id_group_id_fkey FOREIGN KEY (entity_id, group_id) REFERENCES udm.entities(id, group_id) ON DELETE RESTRICT;


--
-- TOC entry 4009 (class 2606 OID 18525)
-- Name: videos videos_parent_id_group_id_fkey; Type: FK CONSTRAINT; Schema: udm; Owner: -
--

ALTER TABLE ONLY udm.videos
    ADD CONSTRAINT videos_parent_id_group_id_fkey FOREIGN KEY (parent_id, group_id) REFERENCES udm.videos(id, group_id) ON DELETE RESTRICT;


--
-- TOC entry 4012 (class 2606 OID 18530)
-- Name: customers_groups fk_customers_groups_customers_1; Type: FK CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.customers_groups
    ADD CONSTRAINT fk_customers_groups_customers_1 FOREIGN KEY (customer_id) REFERENCES users.customers(id) ON DELETE CASCADE;


--
-- TOC entry 4013 (class 2606 OID 18535)
-- Name: customers_groups fk_customers_groups_groups_1; Type: FK CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.customers_groups
    ADD CONSTRAINT fk_customers_groups_groups_1 FOREIGN KEY (group_id) REFERENCES users.groups(id) ON DELETE CASCADE;


--
-- TOC entry 4010 (class 2606 OID 18540)
-- Name: custom_fields fk_parent_field; Type: FK CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.custom_fields
    ADD CONSTRAINT fk_parent_field FOREIGN KEY (parent_field_id, group_id) REFERENCES udm.terms(id, group_id);


--
-- TOC entry 4011 (class 2606 OID 18545)
-- Name: custom_fields fk_parent_field_lookup; Type: FK CONSTRAINT; Schema: users; Owner: -
--

ALTER TABLE ONLY users.custom_fields
    ADD CONSTRAINT fk_parent_field_lookup FOREIGN KEY (parent_field_lookup_id, group_id) REFERENCES users.custom_fields(id, group_id);


-- Completed on 2023-06-28 15:12:11

--
-- PostgreSQL database dump complete
--

