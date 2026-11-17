-- Generado por Oracle SQL Developer Data Modeler 24.3.1.351.0831
--   en:        2026-11-10 16:41:10 COT
--   sitio:      Oracle Database 21c
--   tipo:      Oracle Database 21c



-- Para borrar todas las tablas del esquema y poder re-ejecutar el DDL
-- desde cero. 
DECLARE
    TYPE t_tablas IS TABLE OF VARCHAR2(30);
 
    v_tablas t_tablas := t_tablas(
        -- Nivel 1: tablas hijas que nadie referencia
        'REPRODUCTIONS',
        'REPRODUCTION_PROGRESS',
        'RECOMMENDATIONS',
        'FAVORITES',
        'DOWNLOADS',
        'PAYMENTS',
        'AVAILABILITY',
        'CAPTIONS',
        'CLASSIFICATIONS',
        'PARTICIPATIONS',
        -- Nivel 2: episodios y subtipos de titulo
        'EPISODES',
        'MOVIES',
        'DOCUMENTARIES',
        'TV_SHOWS',
        -- Nivel 3: perfiles, metodos de pago y codigos promocionales
        'PROFILES',
        'PAYMENT_METHODS',
        'PROMO_CODES',
        -- Nivel 4: suscripciones
        'SUBSCRIPTIONS',
        -- Nivel 5: usuarios y planes
        'USERS',
        'PLANS',
        -- Nivel 6: tablas maestras (no dependen de ninguna)
        'TITLES',
        'COUNTRIES',
        'GENRES',
        'LANGUAGES',
        'ACTORS'
    );
BEGIN
    FOR i IN 1 .. v_tablas.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || v_tablas(i) || ' PURGE';
        EXCEPTION
            WHEN OTHERS THEN
                -- -942: la tabla no existe; cualquier otro error se propaga
                IF SQLCODE != -942 THEN
                    RAISE;
                END IF;
        END;
    END LOOP;
END;
/

/* ---------------------------------------------------------------------
   1. TABLAS MAESTRAS
   --------------------------------------------------------------------- */

-- Países donde opera Vyntra (Colombia, México, Ecuador, Perú). HU-1.6
CREATE TABLE COUNTRIES (
    id           VARCHAR2(10) NOT NULL,
    name_country VARCHAR2(30) NOT NULL,
    code         VARCHAR2(2)  NOT NULL
);
ALTER TABLE COUNTRIES ADD CONSTRAINT COUNTRY_PK    PRIMARY KEY (id);
ALTER TABLE COUNTRIES ADD CONSTRAINT COUNTRIES__UN UNIQUE (code);

-- Idiomas disponibles para subtítulos
CREATE TABLE LANGUAGES (
    id   VARCHAR2(10) NOT NULL,
    name VARCHAR2(20) NOT NULL,
    code VARCHAR2(10) NOT NULL
);
ALTER TABLE LANGUAGES ADD CONSTRAINT LANGUAGE_PK   PRIMARY KEY (id);
ALTER TABLE LANGUAGES ADD CONSTRAINT LANGUAGES__UN UNIQUE (code);

-- Géneros para clasificar el catálogo. HU-2.4
CREATE TABLE GENRES (
    id         VARCHAR2(10) NOT NULL,
    name_genre VARCHAR2(20) NOT NULL
);
ALTER TABLE GENRES ADD CONSTRAINT GENRE_PK   PRIMARY KEY (id);
ALTER TABLE GENRES ADD CONSTRAINT GENRES__UN UNIQUE (name_genre);

-- Actores que participan en los títulos. HU-2.3
CREATE TABLE ACTORS (
    id          VARCHAR2(10)  NOT NULL,
    name        VARCHAR2(100) NOT NULL,
    nationality VARCHAR2(20)  NOT NULL
);
ALTER TABLE ACTORS ADD CONSTRAINT ACTOR_PK PRIMARY KEY (id);

-- Planes de suscripción: Básico, Estándar y Premium
CREATE TABLE PLANS (
    id               INTEGER       NOT NULL,
    price            NUMBER(12,2)  NOT NULL,
    name             VARCHAR2(20)  NOT NULL,
    max_screens      NUMBER(1)     NOT NULL,
    max_quality      NUMBER(4)     NOT NULL,
    offline_download CHAR(1)       NOT NULL
);
ALTER TABLE PLANS ADD CONSTRAINT PLAN_PK PRIMARY KEY (id);


/* ---------------------------------------------------------------------
   2. CATÁLOGO DE CONTENIDO
   TITLES es el supertipo; MOVIES, DOCUMENTARIES y TV_SHOWS son sus
   subtipos (comparten la misma PK). EPISODES depende de TV_SHOWS.
   --------------------------------------------------------------------- */

-- Datos comunes de todo título del catálogo. HU-2.1
CREATE TABLE TITLES (
    id           VARCHAR2(10)   NOT NULL,
    title_name   VARCHAR2(400)  NOT NULL,
    type         CHAR(1)        NOT NULL,
    release_year NUMBER(4)      NOT NULL,
    synopsis     VARCHAR2(4000) NOT NULL,
    age_rating   VARCHAR2(4)    NOT NULL,
    origin       CHAR(1)        NOT NULL
);
ALTER TABLE TITLES ADD CONSTRAINT TITLE_PK PRIMARY KEY (id);

-- Subtipo película
CREATE TABLE MOVIES (
    TITLES_id       VARCHAR2(10) NOT NULL,
    duration_minute NUMBER(3)    NOT NULL
);
ALTER TABLE MOVIES ADD CONSTRAINT MOVIE_PK PRIMARY KEY (TITLES_id);

-- Subtipo documental
CREATE TABLE DOCUMENTARIES (
    TITLES_id       VARCHAR2(10) NOT NULL,
    duration_minute NUMBER(3)    NOT NULL
);
ALTER TABLE DOCUMENTARIES ADD CONSTRAINT DOCUMENTARY_PK PRIMARY KEY (TITLES_id);

-- Subtipo serie (la duración está en cada episodio)
CREATE TABLE TV_SHOWS (
    TITLES_id VARCHAR2(10) NOT NULL
);
ALTER TABLE TV_SHOWS ADD CONSTRAINT TV_SHOW_PK PRIMARY KEY (TITLES_id);

-- Episodios de una serie, identificados por temporada y número. HU-2.2
CREATE TABLE EPISODES (
    name_episode    VARCHAR2(50) NOT NULL,
    season_number   NUMBER(2)    NOT NULL,
    season_episode  NUMBER(3)    NOT NULL,
    TITLE_id        VARCHAR2(10) NOT NULL,
    duration_minute NUMBER(3)    NOT NULL
);
ALTER TABLE EPISODES ADD CONSTRAINT EPISODE_PK
    PRIMARY KEY (TITLE_id, season_number, season_episode);

-- Relación N:M entre títulos y géneros. HU-2.4
CREATE TABLE CLASSIFICATIONS (
    GENRE_id VARCHAR2(10) NOT NULL,
    TITLE_id VARCHAR2(10) NOT NULL
);
ALTER TABLE CLASSIFICATIONS ADD CONSTRAINT CLASSIFICATION_PK
    PRIMARY KEY (GENRE_id, TITLE_id);

-- Relación N:M entre títulos y actores, con el personaje interpretado. HU-2.3
CREATE TABLE PARTICIPATIONS (
    character VARCHAR2(50) NOT NULL,
    TITLE_id  VARCHAR2(10) NOT NULL,
    ACTOR_id  VARCHAR2(10) NOT NULL
);
ALTER TABLE PARTICIPATIONS ADD CONSTRAINT PARTICIPATION_PK
    PRIMARY KEY (TITLE_id, ACTOR_id);

-- Subtítulos disponibles por título e idioma
CREATE TABLE CAPTIONS (
    available   CHAR(1)      NOT NULL,
    LANGUAGE_id VARCHAR2(10) NOT NULL,
    TITLE_id    VARCHAR2(10) NOT NULL
);
ALTER TABLE CAPTIONS ADD CONSTRAINT CAPTION_PK PRIMARY KEY (LANGUAGE_id, TITLE_id);

-- Países en los que cada título está disponible y desde cuándo. HU-2.5
CREATE TABLE AVAILABILITY (
    TITLE_id       VARCHAR2(10) NOT NULL,
    COUNTRY_id     VARCHAR2(10) NOT NULL,
    available_date DATE         NOT NULL
);
ALTER TABLE AVAILABILITY ADD CONSTRAINT AVAILABILITY_PK
    PRIMARY KEY (TITLE_id, COUNTRY_id);


/* ---------------------------------------------------------------------
   3. USUARIOS, SUSCRIPCIONES Y PERFILES
   --------------------------------------------------------------------- */

-- Titular de la cuenta. HU-1.1, HU-1.6
CREATE TABLE USERS (
    id                INTEGER       NOT NULL,
    full_name         VARCHAR2(100) NOT NULL,
    email             VARCHAR2(100) NOT NULL,
    password_hash     VARCHAR2(255) NOT NULL,
    registration_date DATE,
    COUNTRY_id        VARCHAR2(10)  NOT NULL
);
ALTER TABLE USERS ADD CONSTRAINT USER_PK       PRIMARY KEY (id);
ALTER TABLE USERS ADD CONSTRAINT USER_email_UN UNIQUE (email);

-- Contrato estable entre un usuario y un plan (no se recrea en cada
-- ciclo de facturación; los cobros se registran en PAYMENTS). HU-4.x
CREATE TABLE SUBSCRIPTIONS (
    id                INTEGER NOT NULL,
    start_date        DATE    NOT NULL,
    state             CHAR(1) NOT NULL,
    end_date          DATE,
    auto_renew        CHAR(1) NOT NULL,
    cancellation_date DATE,
    USER_id           INTEGER NOT NULL,
    PLAN_id           INTEGER NOT NULL
);
ALTER TABLE SUBSCRIPTIONS ADD CONSTRAINT SUBSCRIPTION_PK PRIMARY KEY (id);

-- Perfiles creados bajo una suscripción (estándar o infantil). HU-1.2
CREATE TABLE PROFILES (
    id              INTEGER      NOT NULL,
    name            VARCHAR2(20) NOT NULL,
    profile_type    CHAR(1)      NOT NULL,
    SUBSCRIPTION_id INTEGER      NOT NULL
);
ALTER TABLE PROFILES ADD CONSTRAINT PROFILE_PK PRIMARY KEY (id);


/* ---------------------------------------------------------------------
   4. PAGOS
   --------------------------------------------------------------------- */

-- Tarjetas de crédito/débito registradas por el usuario. HU-4.8
CREATE TABLE PAYMENT_METHODS (
    id                 VARCHAR2(16)  NOT NULL,
    card_type          VARCHAR2(6)   NOT NULL,
    card_number_masked VARCHAR2(16)  NOT NULL,
    cardholder_name    VARCHAR2(100) NOT NULL,
    expiration_date    DATE          NOT NULL,
    is_default         CHAR(1)       NOT NULL,
    state              CHAR(1)       NOT NULL,
    USER_id            INTEGER       NOT NULL
);
ALTER TABLE PAYMENT_METHODS ADD CONSTRAINT PAYMENT_METHOD_PK PRIMARY KEY (id);

-- Códigos promocionales aplicables al pago. HU-4.10
CREATE TABLE PROMO_CODES (
    id             VARCHAR2(10) NOT NULL,
    code           VARCHAR2(8)  NOT NULL,
    discount_type  VARCHAR2(15) NOT NULL,
    discount_value NUMBER(12,2) NOT NULL,
    valid_from     DATE         NOT NULL,
    valid_to       DATE         NOT NULL,
    max_uses       NUMBER(3)    NOT NULL,
    uses_count     NUMBER(3)    NOT NULL,
    state          CHAR(1)      NOT NULL
);
ALTER TABLE PROMO_CODES ADD CONSTRAINT PROMO_CODE_PK   PRIMARY KEY (id);
ALTER TABLE PROMO_CODES ADD CONSTRAINT PROMO_CODES__UN UNIQUE (code);

-- Cobro de un periodo de una suscripción. Guarda el plan facturado en ese
-- momento para el reporte de ingresos por plan (HU-5.8).
CREATE TABLE PAYMENTS (
    id                   VARCHAR2(10) NOT NULL,
    amount               NUMBER(12,2) NOT NULL,
    billing_period_start DATE         NOT NULL,
    billing_period_end   DATE         NOT NULL,
    payment_date         DATE         NOT NULL,
    invoice_number       NUMBER(10)   NOT NULL,
    state                CHAR(1)      NOT NULL,
    SUBSCRIPTION_id      INTEGER      NOT NULL,
    PAYMENT_METHODS_id   VARCHAR2(16) NOT NULL,
    PROMO_CODE_id        VARCHAR2(10),
    PLANS_id             INTEGER      NOT NULL
);
ALTER TABLE PAYMENTS ADD CONSTRAINT PAYMENT_PK   PRIMARY KEY (id);
ALTER TABLE PAYMENTS ADD CONSTRAINT PAYMENTS__UN UNIQUE (invoice_number);


/* ---------------------------------------------------------------------
   5. ACTIVIDAD DEL PERFIL
   --------------------------------------------------------------------- */

-- Cada sesión de reproducción de un perfil. Para series se indica la
-- temporada y el episodio. Base de "más vistos" y "usuarios activos".
-- HU-3.1, HU-3.2, HU-5.3, HU-5.5, HU-5.6
CREATE TABLE REPRODUCTIONS (
    id                   VARCHAR2(10) NOT NULL,
    start_date           DATE         NOT NULL,
    end_date             DATE,
    quality_reproduction NUMBER(4)    NOT NULL,
    season_number        NUMBER(2),
    season_episode       NUMBER(3),
    PROFILE_id           INTEGER      NOT NULL,
    TITLE_id             VARCHAR2(10) NOT NULL
);
ALTER TABLE REPRODUCTIONS ADD CONSTRAINT REPRODUCTION_PK PRIMARY KEY (id);

-- Último punto de reproducción por perfil y título ("continuar viendo").
-- Hay una sola fila por perfil y título; en series guarda el último
-- episodio visto. HU-3.3
CREATE TABLE REPRODUCTION_PROGRESS (
    id                VARCHAR2(10) NOT NULL,
    position_seconds  NUMBER(5)    NOT NULL,
    percentage_viewed NUMBER(5,2)  NOT NULL,
    season_number     NUMBER(2),
    season_episode    NUMBER(3),
    update_date       DATE         NOT NULL,
    finished          CHAR(1)      NOT NULL,
    PROFILE_id        INTEGER      NOT NULL,
    TITLE_id          VARCHAR2(10) NOT NULL
);
ALTER TABLE REPRODUCTION_PROGRESS ADD CONSTRAINT REPRODUCTION_PROGRESS_PK
    PRIMARY KEY (id);
ALTER TABLE REPRODUCTION_PROGRESS ADD CONSTRAINT REPRODUCTION_PROGRESS__UN
    UNIQUE (PROFILE_id, TITLE_id);

-- Descargas offline (solo plan Premium). Un perfil puede volver a
-- descargar el mismo título en otra fecha.
CREATE TABLE DOWNLOADS (
    download_date   DATE         NOT NULL,
    expiration_date DATE         NOT NULL,
    state           CHAR(1)      NOT NULL,
    TITLES_id       VARCHAR2(10) NOT NULL,
    PROFILES_id     INTEGER      NOT NULL
);
ALTER TABLE DOWNLOADS ADD CONSTRAINT DOWNLOAD_PK
    PRIMARY KEY (TITLES_id, PROFILES_id, download_date);

-- Títulos marcados como favoritos por cada perfil
CREATE TABLE FAVORITES (
    date_added DATE         NOT NULL,
    PROFILE_id INTEGER      NOT NULL,
    TITLE_id   VARCHAR2(10) NOT NULL
);
ALTER TABLE FAVORITES ADD CONSTRAINT FAVORITE_PK PRIMARY KEY (PROFILE_id, TITLE_id);

-- Recomendaciones generadas para cada perfil. HU-5.1, HU-5.2, HU-5.4
CREATE TABLE RECOMMENDATIONS (
    id              VARCHAR2(10) NOT NULL,
    relevance_score NUMBER(5,2)  NOT NULL,
    generated_date  DATE         NOT NULL,
    PROFILE_id      INTEGER      NOT NULL,
    TITLE_id        VARCHAR2(10) NOT NULL
);
ALTER TABLE RECOMMENDATIONS ADD CONSTRAINT RECOMMENDATION_PK PRIMARY KEY (id);


/* ---------------------------------------------------------------------
   6. LLAVES FORÁNEAS
   Se crean al final para no depender del orden de creación de tablas.
   --------------------------------------------------------------------- */

-- Catálogo
ALTER TABLE MOVIES          ADD CONSTRAINT MOVIE_TITLE_FK
    FOREIGN KEY (TITLES_id)   REFERENCES TITLES (id);
ALTER TABLE DOCUMENTARIES   ADD CONSTRAINT DOCUMENTARY_TITLE_FK
    FOREIGN KEY (TITLES_id)   REFERENCES TITLES (id);
ALTER TABLE TV_SHOWS        ADD CONSTRAINT TV_SHOW_TITLE_FK
    FOREIGN KEY (TITLES_id)   REFERENCES TITLES (id);
ALTER TABLE EPISODES        ADD CONSTRAINT EPISODES_TV_SHOWS_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TV_SHOWS (TITLES_id);
ALTER TABLE CLASSIFICATIONS ADD CONSTRAINT CLASSIFICATION_GENRE_FK
    FOREIGN KEY (GENRE_id)    REFERENCES GENRES (id);
ALTER TABLE CLASSIFICATIONS ADD CONSTRAINT CLASSIFICATION_TITLE_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TITLES (id);
ALTER TABLE PARTICIPATIONS  ADD CONSTRAINT PARTICIPATION_ACTOR_FK
    FOREIGN KEY (ACTOR_id)    REFERENCES ACTORS (id);
ALTER TABLE PARTICIPATIONS  ADD CONSTRAINT PARTICIPATION_TITLE_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TITLES (id);
ALTER TABLE CAPTIONS        ADD CONSTRAINT CAPTION_LANGUAGE_FK
    FOREIGN KEY (LANGUAGE_id) REFERENCES LANGUAGES (id);
ALTER TABLE CAPTIONS        ADD CONSTRAINT CAPTION_TITLE_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TITLES (id);
ALTER TABLE AVAILABILITY    ADD CONSTRAINT AVAILABILITY_COUNTRY_FK
    FOREIGN KEY (COUNTRY_id)  REFERENCES COUNTRIES (id);
ALTER TABLE AVAILABILITY    ADD CONSTRAINT AVAILABILITY_TITLE_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TITLES (id);

-- Usuarios, suscripciones y perfiles
ALTER TABLE USERS           ADD CONSTRAINT USER_COUNTRY_FK
    FOREIGN KEY (COUNTRY_id)      REFERENCES COUNTRIES (id);
ALTER TABLE SUBSCRIPTIONS   ADD CONSTRAINT SUBSCRIPTION_USER_FK
    FOREIGN KEY (USER_id)         REFERENCES USERS (id);
ALTER TABLE SUBSCRIPTIONS   ADD CONSTRAINT SUBSCRIPTION_PLAN_FK
    FOREIGN KEY (PLAN_id)         REFERENCES PLANS (id);
ALTER TABLE PROFILES        ADD CONSTRAINT PROFILE_SUBSCRIPTION_FK
    FOREIGN KEY (SUBSCRIPTION_id) REFERENCES SUBSCRIPTIONS (id);

-- Pagos
ALTER TABLE PAYMENT_METHODS ADD CONSTRAINT PAYMENT_METHOD_USER_FK
    FOREIGN KEY (USER_id)            REFERENCES USERS (id);
ALTER TABLE PAYMENTS        ADD CONSTRAINT PAYMENT_SUBSCRIPTION_FK
    FOREIGN KEY (SUBSCRIPTION_id)    REFERENCES SUBSCRIPTIONS (id);
ALTER TABLE PAYMENTS        ADD CONSTRAINT PAYMENT_PAYMENT_METHOD_FK
    FOREIGN KEY (PAYMENT_METHODS_id) REFERENCES PAYMENT_METHODS (id);
ALTER TABLE PAYMENTS        ADD CONSTRAINT PAYMENT_PROMO_CODE_FK
    FOREIGN KEY (PROMO_CODE_id)      REFERENCES PROMO_CODES (id);
ALTER TABLE PAYMENTS        ADD CONSTRAINT PAYMENTS_PLANS_FK
    FOREIGN KEY (PLANS_id)           REFERENCES PLANS (id);

-- Actividad del perfil
ALTER TABLE REPRODUCTIONS         ADD CONSTRAINT REPRODUCTION_PROFILE_FK
    FOREIGN KEY (PROFILE_id)  REFERENCES PROFILES (id);
ALTER TABLE REPRODUCTIONS         ADD CONSTRAINT REPRODUCTION_TITLE_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TITLES (id);
ALTER TABLE REPRODUCTION_PROGRESS ADD CONSTRAINT REPR_PROGRESS_PROFILE_FK
    FOREIGN KEY (PROFILE_id)  REFERENCES PROFILES (id);
ALTER TABLE REPRODUCTION_PROGRESS ADD CONSTRAINT REPRODUCTION_PROGRESS_TITLE_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TITLES (id);
ALTER TABLE DOWNLOADS             ADD CONSTRAINT DOWNLOADS_PROFILES_FK
    FOREIGN KEY (PROFILES_id) REFERENCES PROFILES (id);
ALTER TABLE DOWNLOADS             ADD CONSTRAINT DOWNLOADS_TITLES_FK
    FOREIGN KEY (TITLES_id)   REFERENCES TITLES (id);
ALTER TABLE FAVORITES             ADD CONSTRAINT FAVORITE_PROFILE_FK
    FOREIGN KEY (PROFILE_id)  REFERENCES PROFILES (id);
ALTER TABLE FAVORITES             ADD CONSTRAINT FAVORITE_TITLE_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TITLES (id);
ALTER TABLE RECOMMENDATIONS       ADD CONSTRAINT RECOMMENDATION_PROFILE_FK
    FOREIGN KEY (PROFILE_id)  REFERENCES PROFILES (id);
ALTER TABLE RECOMMENDATIONS       ADD CONSTRAINT RECOMMENDATION_TITLE_FK
    FOREIGN KEY (TITLE_id)    REFERENCES TITLES (id);
