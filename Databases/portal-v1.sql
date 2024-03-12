--
-- PostgreSQL database dump
--

-- Dumped from database version 11.18
-- Dumped by pg_dump version 14.3

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
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: azure_superuser
--

CREATE SCHEMA public;

--
-- TOC entry 4481 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: azure_superuser
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

--
-- TOC entry 200 (class 1259 OID 69002)
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


--
-- TOC entry 201 (class 1259 OID 69005)
-- Name: apscheduler_jobs; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.apscheduler_jobs (
    id character varying(191) NOT NULL,
    next_run_time double precision,
    job_state bytea NOT NULL
);


--
-- TOC entry 202 (class 1259 OID 69011)
-- Name: contaur_filter; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.contaur_filter (
    filter_id integer NOT NULL,
    id character varying(255) NOT NULL,
    preset_id integer NOT NULL,
    field character varying(255) NOT NULL,
    "isIncluded" boolean NOT NULL,
    label character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    value character varying(255) NOT NULL
);


--
-- TOC entry 203 (class 1259 OID 69017)
-- Name: contaur_filter_filter_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.contaur_filter_filter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4482 (class 0 OID 0)
-- Dependencies: 203
-- Name: contaur_filter_filter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.contaur_filter_filter_id_seq OWNED BY public.contaur_filter.filter_id;


--
-- TOC entry 204 (class 1259 OID 69019)
-- Name: contaur_filter_preset; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.contaur_filter_preset (
    id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying(255) NOT NULL
);


--
-- TOC entry 205 (class 1259 OID 69022)
-- Name: contaur_filter_preset_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.contaur_filter_preset_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4483 (class 0 OID 0)
-- Dependencies: 205
-- Name: contaur_filter_preset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.contaur_filter_preset_id_seq OWNED BY public.contaur_filter_preset.id;


--
-- TOC entry 206 (class 1259 OID 69024)
-- Name: custom_facets; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.custom_facets (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    owner integer NOT NULL,
    date_created timestamp without time zone NOT NULL,
    date_modified timestamp without time zone NOT NULL,
    source_id character varying(255) NOT NULL,
    project character varying(255) NOT NULL,
    query_value text NOT NULL,
    query_attribute text
);


--
-- TOC entry 207 (class 1259 OID 69030)
-- Name: custom_facets_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.custom_facets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4484 (class 0 OID 0)
-- Dependencies: 207
-- Name: custom_facets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.custom_facets_id_seq OWNED BY public.custom_facets.id;


--
-- TOC entry 208 (class 1259 OID 69032)
-- Name: dashboards; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.dashboards (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    owner integer NOT NULL,
    date_created timestamp without time zone NOT NULL,
    date_modified timestamp without time zone NOT NULL,
    project character varying(255) NOT NULL,
    data json
);


--
-- TOC entry 209 (class 1259 OID 69038)
-- Name: dashboards_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.dashboards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4485 (class 0 OID 0)
-- Dependencies: 209
-- Name: dashboards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.dashboards_id_seq OWNED BY public.dashboards.id;


--
-- TOC entry 210 (class 1259 OID 69040)
-- Name: datasources; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.datasources (
    name character varying(255) NOT NULL,
    roles json NOT NULL,
    config json NOT NULL,
    date_created timestamp without time zone NOT NULL,
    date_modified timestamp without time zone,
    project character varying(255) NOT NULL,
    users json,
    owner character varying(255)
);


--
-- TOC entry 211 (class 1259 OID 69046)
-- Name: ingestion_rule_prefixes; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.ingestion_rule_prefixes (
    id integer NOT NULL,
    group_id integer NOT NULL,
    data text,
    date_modified timestamp without time zone
);


--
-- TOC entry 212 (class 1259 OID 69052)
-- Name: ingestion_rule_prefixes_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.ingestion_rule_prefixes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4486 (class 0 OID 0)
-- Dependencies: 212
-- Name: ingestion_rule_prefixes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.ingestion_rule_prefixes_id_seq OWNED BY public.ingestion_rule_prefixes.id;


--
-- TOC entry 213 (class 1259 OID 69054)
-- Name: ingestion_rules; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.ingestion_rules (
    id integer NOT NULL,
    author integer NOT NULL,
    rule_id integer NOT NULL,
    rule_data text,
    date_created timestamp without time zone NOT NULL,
    group_id integer NOT NULL,
    name character varying(255) NOT NULL
);


--
-- TOC entry 214 (class 1259 OID 69060)
-- Name: ingestion_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.ingestion_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4487 (class 0 OID 0)
-- Dependencies: 214
-- Name: ingestion_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.ingestion_rules_id_seq OWNED BY public.ingestion_rules.id;


--
-- TOC entry 215 (class 1259 OID 69062)
-- Name: map_layer_types; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.map_layer_types (
    id integer NOT NULL,
    type character varying(255) NOT NULL
);


--
-- TOC entry 216 (class 1259 OID 69065)
-- Name: map_layer_types_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.map_layer_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4488 (class 0 OID 0)
-- Dependencies: 216
-- Name: map_layer_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.map_layer_types_id_seq OWNED BY public.map_layer_types.id;


--
-- TOC entry 217 (class 1259 OID 69067)
-- Name: map_layers; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.map_layers (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    project character varying(255) NOT NULL,
    data json NOT NULL,
    style json NOT NULL,
    type_id integer NOT NULL,
    created_at timestamp without time zone,
    created_by integer NOT NULL
);


--
-- TOC entry 218 (class 1259 OID 69073)
-- Name: map_layers_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.map_layers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4489 (class 0 OID 0)
-- Dependencies: 218
-- Name: map_layers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.map_layers_id_seq OWNED BY public.map_layers.id;


--
-- TOC entry 219 (class 1259 OID 69075)
-- Name: projects; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.projects (
    name character varying(255) NOT NULL,
    roles json NOT NULL,
    config json NOT NULL,
    date_created timestamp without time zone NOT NULL,
    date_modified timestamp without time zone
);


--
-- TOC entry 246 (class 1259 OID 387499)
-- Name: quick_help; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.quick_help (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying NOT NULL,
    "parentID" integer,
    icon character varying(255),
    anchor character varying(255),
    "isVertical" boolean
);


--
-- TOC entry 245 (class 1259 OID 387497)
-- Name: quick_help_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.quick_help_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4490 (class 0 OID 0)
-- Dependencies: 245
-- Name: quick_help_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.quick_help_id_seq OWNED BY public.quick_help.id;


--
-- TOC entry 220 (class 1259 OID 69081)
-- Name: rb_reports; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.rb_reports (
    report_id integer NOT NULL,
    category character varying(255),
    name character varying(255),
    date timestamp without time zone,
    description text,
    sticky boolean,
    tags text,
    file bytea,
    thumbnail_lg bytea,
    thumbnail_md bytea,
    thumbnail_sm bytea,
    thumbnail_xs bytea,
    sec_mark_id integer NOT NULL,
    project character varying(255)
);


--
-- TOC entry 221 (class 1259 OID 69087)
-- Name: rb_reports_report_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.rb_reports_report_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4491 (class 0 OID 0)
-- Dependencies: 221
-- Name: rb_reports_report_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.rb_reports_report_id_seq OWNED BY public.rb_reports.report_id;


--
-- TOC entry 222 (class 1259 OID 69089)
-- Name: rb_rfi; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.rb_rfi (
    rfi_id integer NOT NULL,
    name character varying(255),
    subject character varying(255),
    email character varying(255),
    organization character varying(255),
    date timestamp without time zone,
    status boolean,
    request text,
    responses text,
    product_links text,
    sec_mark_id integer NOT NULL
);


--
-- TOC entry 223 (class 1259 OID 69095)
-- Name: rb_rfi_rfi_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.rb_rfi_rfi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4492 (class 0 OID 0)
-- Dependencies: 223
-- Name: rb_rfi_rfi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.rb_rfi_rfi_id_seq OWNED BY public.rb_rfi.rfi_id;


--
-- TOC entry 224 (class 1259 OID 69097)
-- Name: rb_saved_queries; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.rb_saved_queries (
    id integer NOT NULL,
    owner integer,
    groups text,
    project character varying(255),
    raw text,
    sec_mark_id integer
);


--
-- TOC entry 225 (class 1259 OID 69103)
-- Name: rb_saved_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.rb_saved_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4493 (class 0 OID 0)
-- Dependencies: 225
-- Name: rb_saved_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.rb_saved_queries_id_seq OWNED BY public.rb_saved_queries.id;


--
-- TOC entry 226 (class 1259 OID 69105)
-- Name: rb_ui_branding; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.rb_ui_branding (
    branding_id integer NOT NULL,
    contents bytea,
    label character varying(255),
    meta text,
    created timestamp without time zone,
    updated timestamp without time zone,
    sec_mark_id integer NOT NULL
);


--
-- TOC entry 227 (class 1259 OID 69111)
-- Name: rb_ui_branding_branding_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.rb_ui_branding_branding_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4494 (class 0 OID 0)
-- Dependencies: 227
-- Name: rb_ui_branding_branding_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.rb_ui_branding_branding_id_seq OWNED BY public.rb_ui_branding.branding_id;


--
-- TOC entry 244 (class 1259 OID 387489)
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.refresh_tokens (
    user_id character varying NOT NULL,
    created_at timestamp with time zone NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    token character varying NOT NULL
);


--
-- TOC entry 228 (class 1259 OID 69113)
-- Name: saved_visualizations; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.saved_visualizations (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    owner integer NOT NULL,
    date_created timestamp without time zone NOT NULL,
    project character varying(255) NOT NULL,
    data json
);


--
-- TOC entry 229 (class 1259 OID 69119)
-- Name: saved_visualizations_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.saved_visualizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4495 (class 0 OID 0)
-- Dependencies: 229
-- Name: saved_visualizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.saved_visualizations_id_seq OWNED BY public.saved_visualizations.id;


--
-- TOC entry 230 (class 1259 OID 69121)
-- Name: sl_audit; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.sl_audit (
    id integer NOT NULL,
    action character varying(255) NOT NULL,
    source_ip character varying(255),
    username character varying(50) NOT NULL,
    session_id integer,
    target_hostname character varying(255) NOT NULL,
    succeeded boolean,
    start_time timestamp without time zone NOT NULL,
    stop_time timestamp without time zone NOT NULL,
    details text,
    sec_mark_id integer NOT NULL
);


--
-- TOC entry 231 (class 1259 OID 69127)
-- Name: sl_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.sl_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4496 (class 0 OID 0)
-- Dependencies: 231
-- Name: sl_audit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.sl_audit_id_seq OWNED BY public.sl_audit.id;


--
-- TOC entry 232 (class 1259 OID 69129)
-- Name: sl_error; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.sl_error (
    id integer NOT NULL,
    source_ip character varying(255),
    username character varying(50),
    session_id integer,
    target_hostname character varying(255),
    date_time timestamp without time zone NOT NULL,
    page text,
    stacktrace text NOT NULL,
    sec_mark_id integer NOT NULL
);


--
-- TOC entry 233 (class 1259 OID 69135)
-- Name: sl_error_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.sl_error_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4497 (class 0 OID 0)
-- Dependencies: 233
-- Name: sl_error_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.sl_error_id_seq OWNED BY public.sl_error.id;


--
-- TOC entry 234 (class 1259 OID 69137)
-- Name: sl_sec_mark; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.sl_sec_mark (
    db_id integer NOT NULL,
    classification character varying(2) NOT NULL,
    owner_producers text,
    dissems text,
    rel_tos text
);


--
-- TOC entry 235 (class 1259 OID 69143)
-- Name: sl_sec_mark_db_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.sl_sec_mark_db_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4498 (class 0 OID 0)
-- Dependencies: 235
-- Name: sl_sec_mark_db_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.sl_sec_mark_db_id_seq OWNED BY public.sl_sec_mark.db_id;


--
-- TOC entry 236 (class 1259 OID 69145)
-- Name: sl_sessions; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.sl_sessions (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    created_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone,
    sec_mark_id integer
);


--
-- TOC entry 237 (class 1259 OID 69148)
-- Name: sl_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.sl_sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4499 (class 0 OID 0)
-- Dependencies: 237
-- Name: sl_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.sl_sessions_id_seq OWNED BY public.sl_sessions.id;


--
-- TOC entry 238 (class 1259 OID 69150)
-- Name: sl_translation; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.sl_translation (
    db_id integer NOT NULL,
    lang_from character varying(2) NOT NULL,
    lang_to character varying(2) NOT NULL,
    original_text text NOT NULL,
    translation text,
    sec_mark_id integer NOT NULL
);


--
-- TOC entry 239 (class 1259 OID 69156)
-- Name: sl_translation_db_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.sl_translation_db_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4500 (class 0 OID 0)
-- Dependencies: 239
-- Name: sl_translation_db_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.sl_translation_db_id_seq OWNED BY public.sl_translation.db_id;


--
-- TOC entry 240 (class 1259 OID 69158)
-- Name: sl_users; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.sl_users (
    db_id integer NOT NULL,
    username character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    us_citizen boolean,
    _active boolean,
    roles text,
    attrs text,
    sec_mark_id integer,
    workspaces text,
    projects text
);


--
-- TOC entry 241 (class 1259 OID 69164)
-- Name: sl_users_db_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.sl_users_db_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4501 (class 0 OID 0)
-- Dependencies: 241
-- Name: sl_users_db_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.sl_users_db_id_seq OWNED BY public.sl_users.db_id;


--
-- TOC entry 242 (class 1259 OID 69166)
-- Name: workspaces; Type: TABLE; Schema: public; Owner: portal
--

CREATE TABLE public.workspaces (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    roles json NOT NULL,
    config json NOT NULL,
    date_created timestamp without time zone NOT NULL,
    date_modified timestamp without time zone
);


--
-- TOC entry 243 (class 1259 OID 69172)
-- Name: workspaces_id_seq; Type: SEQUENCE; Schema: public; Owner: portal
--

CREATE SEQUENCE public.workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- TOC entry 4502 (class 0 OID 0)
-- Dependencies: 243
-- Name: workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: portal
--

ALTER SEQUENCE public.workspaces_id_seq OWNED BY public.workspaces.id;


--
-- TOC entry 4261 (class 2604 OID 69174)
-- Name: contaur_filter filter_id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.contaur_filter ALTER COLUMN filter_id SET DEFAULT nextval('public.contaur_filter_filter_id_seq'::regclass);


--
-- TOC entry 4262 (class 2604 OID 69175)
-- Name: contaur_filter_preset id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.contaur_filter_preset ALTER COLUMN id SET DEFAULT nextval('public.contaur_filter_preset_id_seq'::regclass);


--
-- TOC entry 4263 (class 2604 OID 69176)
-- Name: custom_facets id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.custom_facets ALTER COLUMN id SET DEFAULT nextval('public.custom_facets_id_seq'::regclass);


--
-- TOC entry 4264 (class 2604 OID 69177)
-- Name: dashboards id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.dashboards ALTER COLUMN id SET DEFAULT nextval('public.dashboards_id_seq'::regclass);


--
-- TOC entry 4265 (class 2604 OID 69178)
-- Name: ingestion_rule_prefixes id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.ingestion_rule_prefixes ALTER COLUMN id SET DEFAULT nextval('public.ingestion_rule_prefixes_id_seq'::regclass);


--
-- TOC entry 4266 (class 2604 OID 69179)
-- Name: ingestion_rules id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.ingestion_rules ALTER COLUMN id SET DEFAULT nextval('public.ingestion_rules_id_seq'::regclass);


--
-- TOC entry 4267 (class 2604 OID 69180)
-- Name: map_layer_types id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.map_layer_types ALTER COLUMN id SET DEFAULT nextval('public.map_layer_types_id_seq'::regclass);


--
-- TOC entry 4268 (class 2604 OID 69181)
-- Name: map_layers id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.map_layers ALTER COLUMN id SET DEFAULT nextval('public.map_layers_id_seq'::regclass);


--
-- TOC entry 4281 (class 2604 OID 387502)
-- Name: quick_help id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.quick_help ALTER COLUMN id SET DEFAULT nextval('public.quick_help_id_seq'::regclass);


--
-- TOC entry 4269 (class 2604 OID 69182)
-- Name: rb_reports report_id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_reports ALTER COLUMN report_id SET DEFAULT nextval('public.rb_reports_report_id_seq'::regclass);


--
-- TOC entry 4270 (class 2604 OID 69183)
-- Name: rb_rfi rfi_id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_rfi ALTER COLUMN rfi_id SET DEFAULT nextval('public.rb_rfi_rfi_id_seq'::regclass);


--
-- TOC entry 4271 (class 2604 OID 69184)
-- Name: rb_saved_queries id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_saved_queries ALTER COLUMN id SET DEFAULT nextval('public.rb_saved_queries_id_seq'::regclass);


--
-- TOC entry 4272 (class 2604 OID 69185)
-- Name: rb_ui_branding branding_id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_ui_branding ALTER COLUMN branding_id SET DEFAULT nextval('public.rb_ui_branding_branding_id_seq'::regclass);


--
-- TOC entry 4273 (class 2604 OID 69186)
-- Name: saved_visualizations id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.saved_visualizations ALTER COLUMN id SET DEFAULT nextval('public.saved_visualizations_id_seq'::regclass);


--
-- TOC entry 4274 (class 2604 OID 69187)
-- Name: sl_audit id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_audit ALTER COLUMN id SET DEFAULT nextval('public.sl_audit_id_seq'::regclass);


--
-- TOC entry 4275 (class 2604 OID 69188)
-- Name: sl_error id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_error ALTER COLUMN id SET DEFAULT nextval('public.sl_error_id_seq'::regclass);


--
-- TOC entry 4276 (class 2604 OID 69189)
-- Name: sl_sec_mark db_id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_sec_mark ALTER COLUMN db_id SET DEFAULT nextval('public.sl_sec_mark_db_id_seq'::regclass);


--
-- TOC entry 4277 (class 2604 OID 69190)
-- Name: sl_sessions id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_sessions ALTER COLUMN id SET DEFAULT nextval('public.sl_sessions_id_seq'::regclass);


--
-- TOC entry 4278 (class 2604 OID 69191)
-- Name: sl_translation db_id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_translation ALTER COLUMN db_id SET DEFAULT nextval('public.sl_translation_db_id_seq'::regclass);


--
-- TOC entry 4279 (class 2604 OID 69192)
-- Name: sl_users db_id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_users ALTER COLUMN db_id SET DEFAULT nextval('public.sl_users_db_id_seq'::regclass);


--
-- TOC entry 4280 (class 2604 OID 69193)
-- Name: workspaces id; Type: DEFAULT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.workspaces ALTER COLUMN id SET DEFAULT nextval('public.workspaces_id_seq'::regclass);


--
-- TOC entry 4283 (class 2606 OID 320340)
-- Name: apscheduler_jobs apscheduler_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.apscheduler_jobs
    ADD CONSTRAINT apscheduler_jobs_pkey PRIMARY KEY (id);


--
-- TOC entry 4286 (class 2606 OID 320342)
-- Name: contaur_filter contaur_filter_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.contaur_filter
    ADD CONSTRAINT contaur_filter_pkey PRIMARY KEY (filter_id);


--
-- TOC entry 4288 (class 2606 OID 320344)
-- Name: contaur_filter_preset contaur_filter_preset_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.contaur_filter_preset
    ADD CONSTRAINT contaur_filter_preset_pkey PRIMARY KEY (id);


--
-- TOC entry 4290 (class 2606 OID 320346)
-- Name: custom_facets custom_facets_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.custom_facets
    ADD CONSTRAINT custom_facets_pkey PRIMARY KEY (id);


--
-- TOC entry 4292 (class 2606 OID 320348)
-- Name: dashboards dashboards_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.dashboards
    ADD CONSTRAINT dashboards_pkey PRIMARY KEY (id);


--
-- TOC entry 4294 (class 2606 OID 320350)
-- Name: datasources datasources_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.datasources
    ADD CONSTRAINT datasources_pkey PRIMARY KEY (name);


--
-- TOC entry 4296 (class 2606 OID 320352)
-- Name: ingestion_rule_prefixes ingestion_rule_prefixes_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.ingestion_rule_prefixes
    ADD CONSTRAINT ingestion_rule_prefixes_pkey PRIMARY KEY (id);


--
-- TOC entry 4298 (class 2606 OID 320354)
-- Name: ingestion_rules ingestion_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.ingestion_rules
    ADD CONSTRAINT ingestion_rules_pkey PRIMARY KEY (id);


--
-- TOC entry 4300 (class 2606 OID 320356)
-- Name: map_layer_types map_layer_types_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.map_layer_types
    ADD CONSTRAINT map_layer_types_pkey PRIMARY KEY (id);


--
-- TOC entry 4302 (class 2606 OID 320358)
-- Name: map_layers map_layers_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.map_layers
    ADD CONSTRAINT map_layers_pkey PRIMARY KEY (id);


--
-- TOC entry 4304 (class 2606 OID 320360)
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (name);


--
-- TOC entry 4336 (class 2606 OID 387507)
-- Name: quick_help quick_help_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.quick_help
    ADD CONSTRAINT quick_help_pkey PRIMARY KEY (id);


--
-- TOC entry 4306 (class 2606 OID 320362)
-- Name: rb_reports rb_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_reports
    ADD CONSTRAINT rb_reports_pkey PRIMARY KEY (report_id);


--
-- TOC entry 4308 (class 2606 OID 320364)
-- Name: rb_rfi rb_rfi_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_rfi
    ADD CONSTRAINT rb_rfi_pkey PRIMARY KEY (rfi_id);


--
-- TOC entry 4311 (class 2606 OID 320366)
-- Name: rb_saved_queries rb_saved_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_saved_queries
    ADD CONSTRAINT rb_saved_queries_pkey PRIMARY KEY (id);


--
-- TOC entry 4314 (class 2606 OID 320368)
-- Name: rb_ui_branding rb_ui_branding_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_ui_branding
    ADD CONSTRAINT rb_ui_branding_pkey PRIMARY KEY (branding_id);


--
-- TOC entry 4334 (class 2606 OID 387496)
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4316 (class 2606 OID 320370)
-- Name: saved_visualizations saved_visualizations_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.saved_visualizations
    ADD CONSTRAINT saved_visualizations_pkey PRIMARY KEY (id);


--
-- TOC entry 4318 (class 2606 OID 320372)
-- Name: sl_audit sl_audit_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_audit
    ADD CONSTRAINT sl_audit_pkey PRIMARY KEY (id);


--
-- TOC entry 4320 (class 2606 OID 320378)
-- Name: sl_error sl_error_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_error
    ADD CONSTRAINT sl_error_pkey PRIMARY KEY (id);


--
-- TOC entry 4322 (class 2606 OID 320380)
-- Name: sl_sec_mark sl_sec_mark_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_sec_mark
    ADD CONSTRAINT sl_sec_mark_pkey PRIMARY KEY (db_id);


--
-- TOC entry 4324 (class 2606 OID 320385)
-- Name: sl_sessions sl_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_sessions
    ADD CONSTRAINT sl_sessions_pkey PRIMARY KEY (id);


--
-- TOC entry 4326 (class 2606 OID 320387)
-- Name: sl_translation sl_translation_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_translation
    ADD CONSTRAINT sl_translation_pkey PRIMARY KEY (db_id);


--
-- TOC entry 4328 (class 2606 OID 320389)
-- Name: sl_users sl_users_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_users
    ADD CONSTRAINT sl_users_pkey PRIMARY KEY (db_id);


--
-- TOC entry 4330 (class 2606 OID 320391)
-- Name: sl_users sl_users_username_key; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_users
    ADD CONSTRAINT sl_users_username_key UNIQUE (username);


--
-- TOC entry 4332 (class 2606 OID 320393)
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- TOC entry 4284 (class 1259 OID 320394)
-- Name: ix_apscheduler_jobs_next_run_time; Type: INDEX; Schema: public; Owner: portal
--

CREATE INDEX ix_apscheduler_jobs_next_run_time ON public.apscheduler_jobs USING btree (next_run_time);


--
-- TOC entry 4309 (class 1259 OID 387508)
-- Name: rb_saved_queries_owner; Type: INDEX; Schema: public; Owner: portal
--

CREATE INDEX rb_saved_queries_owner ON public.rb_saved_queries USING btree (owner);


--
-- TOC entry 4312 (class 1259 OID 387509)
-- Name: rb_saved_query_groups; Type: INDEX; Schema: public; Owner: portal
--

CREATE INDEX rb_saved_query_groups ON public.rb_saved_queries USING gin (((groups)::jsonb));


--
-- TOC entry 4337 (class 2606 OID 320395)
-- Name: contaur_filter contaur_filter_preset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.contaur_filter
    ADD CONSTRAINT contaur_filter_preset_id_fkey FOREIGN KEY (preset_id) REFERENCES public.contaur_filter_preset(id) ON DELETE CASCADE;


--
-- TOC entry 4338 (class 2606 OID 320400)
-- Name: contaur_filter_preset contaur_filter_preset_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.contaur_filter_preset
    ADD CONSTRAINT contaur_filter_preset_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.sl_users(db_id) ON DELETE CASCADE;


--
-- TOC entry 4339 (class 2606 OID 320405)
-- Name: custom_facets custom_facets_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.custom_facets
    ADD CONSTRAINT custom_facets_owner_fkey FOREIGN KEY (owner) REFERENCES public.sl_users(db_id) ON DELETE CASCADE;


--
-- TOC entry 4340 (class 2606 OID 320410)
-- Name: datasources datasources_project_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.datasources
    ADD CONSTRAINT datasources_project_fkey FOREIGN KEY (project) REFERENCES public.projects(name) ON DELETE CASCADE;


--
-- TOC entry 4343 (class 2606 OID 320415)
-- Name: rb_reports fk_sec_mark; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_reports
    ADD CONSTRAINT fk_sec_mark FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;


--
-- TOC entry 4344 (class 2606 OID 320420)
-- Name: rb_rfi fk_sec_mark; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_rfi
    ADD CONSTRAINT fk_sec_mark FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;


--
-- TOC entry 4345 (class 2606 OID 320425)
-- Name: rb_saved_queries fk_sec_mark; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_saved_queries
    ADD CONSTRAINT fk_sec_mark FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;


--
-- TOC entry 4341 (class 2606 OID 320430)
-- Name: map_layers map_layers_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.map_layers
    ADD CONSTRAINT map_layers_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.sl_users(db_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4342 (class 2606 OID 320435)
-- Name: map_layers map_layers_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.map_layers
    ADD CONSTRAINT map_layers_type_id_fkey FOREIGN KEY (type_id) REFERENCES public.map_layer_types(id);


--
-- TOC entry 4346 (class 2606 OID 320440)
-- Name: rb_saved_queries rb_saved_queries_owner_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_saved_queries
    ADD CONSTRAINT rb_saved_queries_owner_fkey FOREIGN KEY (owner) REFERENCES public.sl_users(db_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4347 (class 2606 OID 320445)
-- Name: rb_ui_branding rb_ui_branding_sec_mark_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.rb_ui_branding
    ADD CONSTRAINT rb_ui_branding_sec_mark_id_fkey FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;


--
-- TOC entry 4348 (class 2606 OID 320450)
-- Name: sl_audit sl_audit_sec_mark_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_audit
    ADD CONSTRAINT sl_audit_sec_mark_id_fkey FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;


--
-- TOC entry 4349 (class 2606 OID 320456)
-- Name: sl_error sl_error_sec_mark_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_error
    ADD CONSTRAINT sl_error_sec_mark_id_fkey FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;


--
-- TOC entry 4350 (class 2606 OID 320461)
-- Name: sl_sessions sl_sessions_sec_mark_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_sessions
    ADD CONSTRAINT sl_sessions_sec_mark_id_fkey FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;


--
-- TOC entry 4351 (class 2606 OID 320466)
-- Name: sl_translation sl_translation_sec_mark_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_translation
    ADD CONSTRAINT sl_translation_sec_mark_id_fkey FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;


--
-- TOC entry 4352 (class 2606 OID 320471)
-- Name: sl_users sl_users_sec_mark_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: portal
--

ALTER TABLE ONLY public.sl_users
    ADD CONSTRAINT sl_users_sec_mark_id_fkey FOREIGN KEY (sec_mark_id) REFERENCES public.sl_sec_mark(db_id) ON DELETE CASCADE;

INSERT INTO public.sl_users (db_id, username, name, email, us_citizen, _active, roles, attrs, sec_mark_id, workspaces, projects) 
    VALUES (1, 'portaladmin', 'Portal Admin', 'example@afs.com', true, true,	'["admin", "analyst", "user"]', '{"accountCreatedAt": {"__type__": "datetime", "year": 2023, "month": 8, "day": 28, "hour": 20, "minute": 33, "second": 32, "microsecond": 717043}}', null, '[]', '[]')
