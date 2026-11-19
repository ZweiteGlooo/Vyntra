-- =====================================================================
-- PROYECTO : Vyntra - Plataforma de streaming
-- CURSO    : Sistemas Intensivos en Datos (2026-2)
-- ENTREGA  : Final - Script DDL
-- MOTOR    : Oracle Database 21c
-- DESCRIPCION: Crea las 25 tablas de Vyntra: catalogo de contenido,
--   cuentas y perfiles, suscripciones y pagos, y actividad de los perfiles
--   (reproducciones, progreso, descargas, favoritos, recomendaciones).
--   Modelo generado con Oracle SQL Developer Data Modeler y ajustado a mano
--   (ver seccion "AJUSTES MANUALES" al final del script).
-- CONVENCION: campos CHAR(1) booleanos usan 'S' (si) / 'N' (no).
-- =====================================================================

-- Generado por Oracle SQL Developer Data Modeler 24.3.1.351.0831
--   en:        2026-11-18 14:57:56 COT
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

-- predefined type, no DDL - MDSYS.SDO_GEOMETRY

-- predefined type, no DDL - XMLTYPE

-- ACTORS: Actores que participan en los titulos del catalogo.
CREATE TABLE ACTORS 
    ( 
     id          VARCHAR2 (10)  NOT NULL , 
     name        VARCHAR2 (100)  NOT NULL , 
     nationality VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE ACTORS 
    ADD CONSTRAINT ACTOR_PK PRIMARY KEY ( id ) ;

-- AVAILABILITY: Disponibilidad de cada titulo por pais a partir de una fecha (licencias regionales).
CREATE TABLE AVAILABILITY 
    ( 
     TITLE_id       VARCHAR2 (10)  NOT NULL , 
     COUNTRY_id     VARCHAR2 (10)  NOT NULL , 
     available_date DATE  NOT NULL 
    ) 
;

ALTER TABLE AVAILABILITY 
    ADD CONSTRAINT AVAILABILITY_PK PRIMARY KEY ( TITLE_id, COUNTRY_id ) ;

-- CAPTIONS: Subtitulos disponibles por titulo e idioma. available: S = habilitado, N = deshabilitado.
CREATE TABLE CAPTIONS 
    ( 
     available   CHAR (1)  NOT NULL , 
     LANGUAGE_id VARCHAR2 (10)  NOT NULL , 
     TITLE_id    VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE CAPTIONS 
    ADD CONSTRAINT CAPTION_PK PRIMARY KEY ( LANGUAGE_id, TITLE_id ) ;

-- CLASSIFICATIONS: Relacion N:M entre titulos y generos.
CREATE TABLE CLASSIFICATIONS 
    ( 
     GENRE_id VARCHAR2 (10)  NOT NULL , 
     TITLE_id VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE CLASSIFICATIONS 
    ADD CONSTRAINT CLASSIFICATION_PK PRIMARY KEY ( GENRE_id, TITLE_id ) ;

-- COUNTRIES: Paises donde opera Vyntra. code = codigo ISO de 2 letras (CO, MX, EC, PE).
CREATE TABLE COUNTRIES 
    ( 
     id           VARCHAR2 (10)  NOT NULL , 
     name_country VARCHAR2 (30)  NOT NULL , 
     code         VARCHAR2 (2)  NOT NULL 
    ) 
;

ALTER TABLE COUNTRIES 
    ADD CONSTRAINT COUNTRY_PK PRIMARY KEY ( id ) ;

ALTER TABLE COUNTRIES 
    ADD CONSTRAINT COUNTRIES__UN UNIQUE ( code ) ;

-- DOCUMENTARIES: Subtipo de TITLES: documentales, con su duracion.
CREATE TABLE DOCUMENTARIES 
    ( 
     TITLES_id       VARCHAR2 (10)  NOT NULL , 
     duration_minute NUMBER (3)  NOT NULL 
    ) 
;

ALTER TABLE DOCUMENTARIES 
    ADD 
    CHECK (DURATION_MINUTE > 0) 
;

ALTER TABLE DOCUMENTARIES 
    ADD CONSTRAINT DOCUMENTARY_PK PRIMARY KEY ( TITLES_id ) ;

-- DOWNLOADS: Descargas offline por perfil. state: A = activa, E = expirada, B = borrada.
CREATE TABLE DOWNLOADS 
    ( 
     download_date   DATE  NOT NULL , 
     expiration_date DATE  NOT NULL , 
     state           CHAR (1)  NOT NULL , 
     TITLES_id       VARCHAR2 (10)  NOT NULL , 
     PROFILES_id     INTEGER  NOT NULL 
    ) 
;

ALTER TABLE DOWNLOADS 
    ADD CONSTRAINT DOWNLOAD_PK PRIMARY KEY ( TITLES_id, PROFILES_id, download_date ) ;

-- EPISODES: Episodios de las series, identificados por serie + temporada + numero de episodio.
CREATE TABLE EPISODES 
    ( 
     name_episode    VARCHAR2 (50)  NOT NULL , 
     season_number   NUMBER (2)  NOT NULL , 
     season_episode  NUMBER (3)  NOT NULL , 
     TITLE_id        VARCHAR2 (10)  NOT NULL , 
     duration_minute NUMBER (3)  NOT NULL 
    ) 
;

ALTER TABLE EPISODES 
    ADD 
    CHECK (SEASON_NUMBER >= 1) 
;

ALTER TABLE EPISODES 
    ADD 
    CHECK (SEASON_EPISODE >= 1) 
;

ALTER TABLE EPISODES 
    ADD 
    CHECK (DURATION_MINUTE > 0) 
;

ALTER TABLE EPISODES 
    ADD CONSTRAINT EPISODE_PK PRIMARY KEY ( TITLE_id, season_number, season_episode ) ;

-- FAVORITES: Titulos marcados como favoritos por cada perfil.
CREATE TABLE FAVORITES 
    ( 
     date_added DATE  NOT NULL , 
     PROFILE_id INTEGER  NOT NULL , 
     TITLE_id   VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE FAVORITES 
    ADD CONSTRAINT FAVORITE_PK PRIMARY KEY ( PROFILE_id, TITLE_id ) ;

-- GENRES: Generos del catalogo (accion, drama, comedia...).
CREATE TABLE GENRES 
    ( 
     id         VARCHAR2 (10)  NOT NULL , 
     name_genre VARCHAR2 (20)  NOT NULL 
    ) 
;

ALTER TABLE GENRES 
    ADD CONSTRAINT GENRE_PK PRIMARY KEY ( id ) ;

ALTER TABLE GENRES 
    ADD CONSTRAINT GENRES__UN UNIQUE ( name_genre ) ;

-- LANGUAGES: Idiomas disponibles para subtitulos.
CREATE TABLE LANGUAGES 
    ( 
     id   VARCHAR2 (10)  NOT NULL , 
     name VARCHAR2 (20)  NOT NULL , 
     code VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE LANGUAGES 
    ADD CONSTRAINT LANGUAGE_PK PRIMARY KEY ( id ) ;

ALTER TABLE LANGUAGES 
    ADD CONSTRAINT LANGUAGES__UN UNIQUE ( code ) ;

-- MOVIES: Subtipo de TITLES: peliculas, con su duracion.
CREATE TABLE MOVIES 
    ( 
     TITLES_id       VARCHAR2 (10)  NOT NULL , 
     duration_minute NUMBER (3)  NOT NULL 
    ) 
;

ALTER TABLE MOVIES 
    ADD 
    CHECK (DURATION_MINUTE > 0) 
;

ALTER TABLE MOVIES 
    ADD CONSTRAINT MOVIE_PK PRIMARY KEY ( TITLES_id ) ;

-- PARTICIPATIONS: Relacion N:M entre titulos y actores, con el personaje interpretado.
CREATE TABLE PARTICIPATIONS 
    ( 
     character VARCHAR2 (50)  NOT NULL , 
     TITLE_id  VARCHAR2 (10)  NOT NULL , 
     ACTOR_id  VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE PARTICIPATIONS 
    ADD CONSTRAINT PARTICIPATION_PK PRIMARY KEY ( TITLE_id, ACTOR_id ) ;

-- PAYMENT_METHODS: Tarjetas registradas por el usuario. card_type: CREDITO / DEBITO. Solo se guarda el numero enmascarado.
-- is_default: S / N. state: A = activo, I = inactivo.
CREATE TABLE PAYMENT_METHODS 
    ( 
     id                 VARCHAR2 (6)  NOT NULL , 
     card_type          VARCHAR2 (7)  NOT NULL , 
     card_number_masked VARCHAR2 (16)  NOT NULL , 
     cardholder_name    VARCHAR2 (100)  NOT NULL , 
     expiration_date    DATE  NOT NULL , 
     is_default         CHAR (1)  NOT NULL , 
     state              CHAR (1)  NOT NULL , 
     USER_id            INTEGER  NOT NULL 
    ) 
;

ALTER TABLE PAYMENT_METHODS 
    ADD CONSTRAINT PAYMENT_METHOD_PK PRIMARY KEY ( id ) ;

-- PAYMENTS: Cobro de un periodo de facturacion de una suscripcion. state: P = pendiente, A = aprobado, R = rechazado.
-- PLANS_id guarda el plan facturado en ese periodo (historico si el usuario cambia de plan).
CREATE TABLE PAYMENTS 
    ( 
     id                   VARCHAR2 (10)  NOT NULL , 
     amount               NUMBER (12,2)  NOT NULL , 
     billing_period_start DATE  NOT NULL , 
     billing_period_end   DATE  NOT NULL , 
     payment_date         DATE  NOT NULL , 
     invoice_number       NUMBER (10)  NOT NULL , 
     state                CHAR (1)  NOT NULL , 
     SUBSCRIPTION_id      INTEGER  NOT NULL , 
     PAYMENT_METHODS_id   VARCHAR2 (6)  NOT NULL , 
     PROMO_CODE_id        VARCHAR2 (10) , 
     PLANS_id             INTEGER  NOT NULL 
    ) 
;

ALTER TABLE PAYMENTS 
    ADD 
    CHECK (AMOUNT >= 1) 
;

ALTER TABLE PAYMENTS 
    ADD CONSTRAINT PAYMENT_PK PRIMARY KEY ( id ) ;

ALTER TABLE PAYMENTS 
    ADD CONSTRAINT PAYMENTS__UN UNIQUE ( invoice_number ) ;

-- PLANS: Planes de suscripcion (Basico, Estandar, Premium). max_quality en lineas (480/720/1080/2160).
-- offline_download: S / N.
CREATE TABLE PLANS 
    ( 
     id               INTEGER  NOT NULL , 
     price            NUMBER (12,2)  NOT NULL , 
     name             VARCHAR2 (20)  NOT NULL , 
     max_screens      NUMBER (1)  NOT NULL , 
     max_quality      NUMBER (4)  NOT NULL , 
     offline_download CHAR (1)  NOT NULL 
    ) 
;

ALTER TABLE PLANS 
    ADD CONSTRAINT PLAN_PK PRIMARY KEY ( id ) ;

-- PROFILES: Perfiles creados bajo una suscripcion. profile_type: E = estandar, I = infantil.
CREATE TABLE PROFILES 
    ( 
     id              INTEGER  NOT NULL , 
     name            VARCHAR2 (20)  NOT NULL , 
     profile_type    CHAR (1)  NOT NULL , 
     SUBSCRIPTION_id INTEGER  NOT NULL 
    ) 
;

ALTER TABLE PROFILES 
    ADD CONSTRAINT PROFILE_PK PRIMARY KEY ( id ) ;

-- PROMO_CODES: Codigos promocionales aplicables a pagos. discount_type: PORCENTAJE / VALOR_FIJO.
-- state: A = activo, I = inactivo.
CREATE TABLE PROMO_CODES 
    ( 
     id             VARCHAR2 (10)  NOT NULL , 
     code           VARCHAR2 (8)  NOT NULL , 
     discount_type  VARCHAR2 (15)  NOT NULL , 
     discount_value NUMBER (12,2)  NOT NULL , 
     valid_from     DATE  NOT NULL , 
     valid_to       DATE  NOT NULL , 
     max_uses       NUMBER (3)  NOT NULL , 
     uses_count     NUMBER (3)  NOT NULL , 
     state          CHAR (1)  NOT NULL 
    ) 
;

ALTER TABLE PROMO_CODES 
    ADD CONSTRAINT PROMO_CODE_PK PRIMARY KEY ( id ) ;

ALTER TABLE PROMO_CODES 
    ADD CONSTRAINT PROMO_CODES__UN UNIQUE ( code ) ;

-- RECOMMENDATIONS: Recomendaciones de titulos generadas para cada perfil (relevance_score de 0 a 100).
CREATE TABLE RECOMMENDATIONS 
    ( 
     id              VARCHAR2 (10)  NOT NULL , 
     relevance_score NUMBER (5,2)  NOT NULL , 
     generated_date  DATE  NOT NULL , 
     PROFILE_id      INTEGER  NOT NULL , 
     TITLE_id        VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE RECOMMENDATIONS 
    ADD CONSTRAINT RECOMMENDATION_PK PRIMARY KEY ( id ) ;

-- REPRODUCTION_PROGRESS: Punto de "continuar viendo": un registro por perfil y titulo. finished: S / N.
-- Columnas EPISODES_*: solo para series (ultimo episodio visto); NULL en peliculas y documentales.
CREATE TABLE REPRODUCTION_PROGRESS 
    ( 
     id                      VARCHAR2 (10)  NOT NULL , 
     position_seconds        NUMBER (5)  NOT NULL , 
     percentage_viewed       NUMBER (5,2)  NOT NULL , 
     update_date             DATE  NOT NULL , 
     finished                CHAR (1)  NOT NULL , 
     PROFILE_id              INTEGER  NOT NULL , 
     TITLE_id                VARCHAR2 (10)  NOT NULL , 
     EPISODES_TITLE_id       VARCHAR2 (10) , 
     EPISODES_season_number  NUMBER (2) , 
     EPISODES_season_episode NUMBER (3) 
    ) 
;

ALTER TABLE REPRODUCTION_PROGRESS 
    ADD 
    CHECK (position_seconds >= 0) 
;

ALTER TABLE REPRODUCTION_PROGRESS 
    ADD CONSTRAINT REPRODUCTION_PROGRESS_PK PRIMARY KEY ( id ) ;

ALTER TABLE REPRODUCTION_PROGRESS 
    ADD CONSTRAINT REPRODUCTION_PROGRESS__UN UNIQUE ( PROFILE_id , TITLE_id ) ;

-- REPRODUCTIONS: Cada sesion de reproduccion; base del reporte de contenido mas visto.
-- Columnas EPISODES_*: solo para series; NULL en peliculas y documentales.
CREATE TABLE REPRODUCTIONS 
    ( 
     id                      VARCHAR2 (10)  NOT NULL , 
     start_date              DATE  NOT NULL , 
     end_date                DATE , 
     quality_reproduction    NUMBER (4)  NOT NULL , 
     PROFILE_id              INTEGER  NOT NULL , 
     TITLE_id                VARCHAR2 (10)  NOT NULL , 
     EPISODES_TITLE_id       VARCHAR2 (10) , 
     EPISODES_season_number  NUMBER (2) , 
     EPISODES_season_episode NUMBER (3) 
    ) 
;

ALTER TABLE REPRODUCTIONS 
    ADD CONSTRAINT REPRODUCTION_PK PRIMARY KEY ( id ) ;

-- SUBSCRIPTIONS: Contrato estable entre usuario y plan; los cobros van en PAYMENTS.
-- state: A = activa, S = suspendida, C = cancelada. auto_renew: S / N.
CREATE TABLE SUBSCRIPTIONS 
    ( 
     id                INTEGER  NOT NULL , 
     start_date        DATE  NOT NULL , 
     state             CHAR (1)  NOT NULL , 
     end_date          DATE , 
     auto_renew        CHAR (1)  NOT NULL , 
     cancellation_date DATE , 
     USER_id           INTEGER  NOT NULL , 
     PLAN_id           INTEGER  NOT NULL 
    ) 
;

ALTER TABLE SUBSCRIPTIONS 
    ADD CONSTRAINT SUBSCRIPTION_PK PRIMARY KEY ( id ) ;

-- TITLES: Supertipo de todo el contenido. type: M = pelicula, D = documental, S = serie.
-- origin: O = original Vyntra, L = licenciado.
CREATE TABLE TITLES 
    ( 
     id           VARCHAR2 (10)  NOT NULL , 
     title_name   VARCHAR2 (400)  NOT NULL , 
     type         CHAR (1)  NOT NULL , 
     release_year NUMBER (4)  NOT NULL , 
     synopsis     VARCHAR2 (4000)  NOT NULL , 
     age_rating   VARCHAR2 (5)  NOT NULL , 
     origin       CHAR (1)  NOT NULL 
    ) 
;

ALTER TABLE TITLES 
    ADD 
    CHECK (release_year >= 1900) 
;

ALTER TABLE TITLES 
    ADD CONSTRAINT TITLE_PK PRIMARY KEY ( id ) ;

-- TV_SHOWS: Subtipo de TITLES: series (sus episodios estan en EPISODES).
CREATE TABLE TV_SHOWS 
    ( 
     TITLES_id VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE TV_SHOWS 
    ADD CONSTRAINT TV_SHOW_PK PRIMARY KEY ( TITLES_id ) ;

-- USERS: Titulares de cuenta. La contrasena se guarda solo como hash.
CREATE TABLE USERS 
    ( 
     id                INTEGER  NOT NULL , 
     full_name         VARCHAR2 (100)  NOT NULL , 
     email             VARCHAR2 (100)  NOT NULL , 
     password_hash     VARCHAR2 (255)  NOT NULL , 
     registration_date DATE , 
     COUNTRY_id        VARCHAR2 (10)  NOT NULL 
    ) 
;

ALTER TABLE USERS 
    ADD 
    CHECK (email LIKE '%_@_%._%') 
;

ALTER TABLE USERS 
    ADD CONSTRAINT USER_PK PRIMARY KEY ( id ) ;

ALTER TABLE USERS 
    ADD CONSTRAINT USER_email_UN UNIQUE ( email ) ;

ALTER TABLE AVAILABILITY 
    ADD CONSTRAINT AVAILABILITY_COUNTRY_FK FOREIGN KEY 
    ( 
     COUNTRY_id
    ) 
    REFERENCES COUNTRIES 
    ( 
     id
    ) 
;

ALTER TABLE AVAILABILITY 
    ADD CONSTRAINT AVAILABILITY_TITLE_FK FOREIGN KEY 
    ( 
     TITLE_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE CAPTIONS 
    ADD CONSTRAINT CAPTION_LANGUAGE_FK FOREIGN KEY 
    ( 
     LANGUAGE_id
    ) 
    REFERENCES LANGUAGES 
    ( 
     id
    ) 
;

ALTER TABLE CAPTIONS 
    ADD CONSTRAINT CAPTION_TITLE_FK FOREIGN KEY 
    ( 
     TITLE_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE CLASSIFICATIONS 
    ADD CONSTRAINT CLASSIFICATION_GENRE_FK FOREIGN KEY 
    ( 
     GENRE_id
    ) 
    REFERENCES GENRES 
    ( 
     id
    ) 
;

ALTER TABLE CLASSIFICATIONS 
    ADD CONSTRAINT CLASSIFICATION_TITLE_FK FOREIGN KEY 
    ( 
     TITLE_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE DOCUMENTARIES 
    ADD CONSTRAINT DOCUMENTARY_TITLE_FK FOREIGN KEY 
    ( 
     TITLES_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE DOWNLOADS 
    ADD CONSTRAINT DOWNLOADS_PROFILES_FK FOREIGN KEY 
    ( 
     PROFILES_id
    ) 
    REFERENCES PROFILES 
    ( 
     id
    ) 
;

ALTER TABLE DOWNLOADS 
    ADD CONSTRAINT DOWNLOADS_TITLES_FK FOREIGN KEY 
    ( 
     TITLES_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE EPISODES 
    ADD CONSTRAINT EPISODES_TV_SHOWS_FK FOREIGN KEY 
    ( 
     TITLE_id
    ) 
    REFERENCES TV_SHOWS 
    ( 
     TITLES_id
    ) 
;

ALTER TABLE FAVORITES 
    ADD CONSTRAINT FAVORITE_PROFILE_FK FOREIGN KEY 
    ( 
     PROFILE_id
    ) 
    REFERENCES PROFILES 
    ( 
     id
    ) 
;

ALTER TABLE FAVORITES 
    ADD CONSTRAINT FAVORITE_TITLE_FK FOREIGN KEY 
    ( 
     TITLE_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE MOVIES 
    ADD CONSTRAINT MOVIE_TITLE_FK FOREIGN KEY 
    ( 
     TITLES_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE PARTICIPATIONS 
    ADD CONSTRAINT PARTICIPATION_ACTOR_FK FOREIGN KEY 
    ( 
     ACTOR_id
    ) 
    REFERENCES ACTORS 
    ( 
     id
    ) 
;

ALTER TABLE PARTICIPATIONS 
    ADD CONSTRAINT PARTICIPATION_TITLE_FK FOREIGN KEY 
    ( 
     TITLE_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE PAYMENT_METHODS 
    ADD CONSTRAINT PAYMENT_METHOD_USER_FK FOREIGN KEY 
    ( 
     USER_id
    ) 
    REFERENCES USERS 
    ( 
     id
    ) 
;

ALTER TABLE PAYMENTS 
    ADD CONSTRAINT PAYMENT_PAYMENT_METHOD_FK FOREIGN KEY 
    ( 
     PAYMENT_METHODS_id
    ) 
    REFERENCES PAYMENT_METHODS 
    ( 
     id
    ) 
;

ALTER TABLE PAYMENTS 
    ADD CONSTRAINT PAYMENT_PROMO_CODE_FK FOREIGN KEY 
    ( 
     PROMO_CODE_id
    ) 
    REFERENCES PROMO_CODES 
    ( 
     id
    ) 
;

ALTER TABLE PAYMENTS 
    ADD CONSTRAINT PAYMENT_SUBSCRIPTION_FK FOREIGN KEY 
    ( 
     SUBSCRIPTION_id
    ) 
    REFERENCES SUBSCRIPTIONS 
    ( 
     id
    ) 
;

ALTER TABLE PAYMENTS 
    ADD CONSTRAINT PAYMENTS_PLANS_FK FOREIGN KEY 
    ( 
     PLANS_id
    ) 
    REFERENCES PLANS 
    ( 
     id
    ) 
;

ALTER TABLE PROFILES 
    ADD CONSTRAINT PROFILE_SUBSCRIPTION_FK FOREIGN KEY 
    ( 
     SUBSCRIPTION_id
    ) 
    REFERENCES SUBSCRIPTIONS 
    ( 
     id
    ) 
;

ALTER TABLE REPRODUCTION_PROGRESS 
    ADD CONSTRAINT PROGRESS_TV_SHOWS_FK FOREIGN KEY 
    ( 
     EPISODES_TITLE_id,
     EPISODES_season_number,
     EPISODES_season_episode
    ) 
    REFERENCES EPISODES 
    ( 
     TITLE_id,
     season_number,
     season_episode
    ) 
;

ALTER TABLE RECOMMENDATIONS 
    ADD CONSTRAINT RECOMMENDATION_PROFILE_FK FOREIGN KEY 
    ( 
     PROFILE_id
    ) 
    REFERENCES PROFILES 
    ( 
     id
    ) 
;

ALTER TABLE RECOMMENDATIONS 
    ADD CONSTRAINT RECOMMENDATION_TITLE_FK FOREIGN KEY 
    ( 
     TITLE_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE REPRODUCTION_PROGRESS 
    ADD CONSTRAINT REPR_PROGRESS_PROFILE_FK FOREIGN KEY 
    ( 
     PROFILE_id
    ) 
    REFERENCES PROFILES 
    ( 
     id
    ) 
;

ALTER TABLE REPRODUCTIONS 
    ADD CONSTRAINT REPRODUCTION_PROFILE_FK FOREIGN KEY 
    ( 
     PROFILE_id
    ) 
    REFERENCES PROFILES 
    ( 
     id
    ) 
;

ALTER TABLE REPRODUCTIONS 
    ADD CONSTRAINT REPRODUCTION_TITLE_FK FOREIGN KEY 
    ( 
     TITLE_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE REPRODUCTIONS 
    ADD CONSTRAINT REPRODUCTIONS_EPISODES_FK FOREIGN KEY 
    ( 
     EPISODES_TITLE_id,
     EPISODES_season_number,
     EPISODES_season_episode
    ) 
    REFERENCES EPISODES 
    ( 
     TITLE_id,
     season_number,
     season_episode
    ) 
;

ALTER TABLE SUBSCRIPTIONS 
    ADD CONSTRAINT SUBSCRIPTION_PLAN_FK FOREIGN KEY 
    ( 
     PLAN_id
    ) 
    REFERENCES PLANS 
    ( 
     id
    ) 
;

ALTER TABLE SUBSCRIPTIONS 
    ADD CONSTRAINT SUBSCRIPTION_USER_FK FOREIGN KEY 
    ( 
     USER_id
    ) 
    REFERENCES USERS 
    ( 
     id
    ) 
;

ALTER TABLE TV_SHOWS 
    ADD CONSTRAINT TV_SHOW_TITLE_FK FOREIGN KEY 
    ( 
     TITLES_id
    ) 
    REFERENCES TITLES 
    ( 
     id
    ) 
;

ALTER TABLE USERS 
    ADD CONSTRAINT USER_COUNTRY_FK FOREIGN KEY 
    ( 
     COUNTRY_id
    ) 
    REFERENCES COUNTRIES 
    ( 
     id
    ) 
;


-- =====================================================================
-- AJUSTES MANUALES (agregados despues de generar el modelo)
-- =====================================================================

-- FK faltante: el progreso debe apuntar a un titulo existente.
ALTER TABLE REPRODUCTION_PROGRESS 
    ADD CONSTRAINT REPR_PROGRESS_TITLE_FK FOREIGN KEY ( TITLE_id ) REFERENCES TITLES ( id ) ;

-- Si es serie, las 3 columnas de episodio van llenas y el episodio es de la
-- misma serie (EPISODES_TITLE_id = TITLE_id). Si es pelicula o documental,
-- las 3 van en NULL.
ALTER TABLE REPRODUCTIONS 
    ADD CONSTRAINT REPRODUCTION_EPISODE_CK CHECK (
        (EPISODES_TITLE_id IS NULL AND EPISODES_season_number IS NULL AND EPISODES_season_episode IS NULL)
        OR (EPISODES_TITLE_id IS NOT NULL AND EPISODES_TITLE_id = TITLE_id
            AND EPISODES_season_number IS NOT NULL AND EPISODES_season_episode IS NOT NULL) ) ;

ALTER TABLE REPRODUCTION_PROGRESS 
    ADD CONSTRAINT PROGRESS_EPISODE_CK CHECK (
        (EPISODES_TITLE_id IS NULL AND EPISODES_season_number IS NULL AND EPISODES_season_episode IS NULL)
        OR (EPISODES_TITLE_id IS NOT NULL AND EPISODES_TITLE_id = TITLE_id
            AND EPISODES_season_number IS NOT NULL AND EPISODES_season_episode IS NOT NULL) ) ;

-- Dominios de los campos codificados (valores documentados en cada tabla).
ALTER TABLE TITLES          ADD CONSTRAINT TITLE_TYPE_CK           CHECK (type IN ('M','D','S')) ;
ALTER TABLE TITLES          ADD CONSTRAINT TITLE_ORIGIN_CK         CHECK (origin IN ('O','L')) ;
ALTER TABLE CAPTIONS        ADD CONSTRAINT CAPTION_AVAILABLE_CK    CHECK (available IN ('S','N')) ;
ALTER TABLE DOWNLOADS       ADD CONSTRAINT DOWNLOAD_STATE_CK       CHECK (state IN ('A','E','B')) ;
ALTER TABLE PAYMENT_METHODS ADD CONSTRAINT PAYMENT_METHOD_TYPE_CK  CHECK (card_type IN ('CREDITO','DEBITO')) ;
ALTER TABLE PAYMENT_METHODS ADD CONSTRAINT PAYMENT_METHOD_DEF_CK   CHECK (is_default IN ('S','N')) ;
ALTER TABLE PAYMENT_METHODS ADD CONSTRAINT PAYMENT_METHOD_STATE_CK CHECK (state IN ('A','I')) ;
ALTER TABLE PAYMENTS        ADD CONSTRAINT PAYMENT_STATE_CK        CHECK (state IN ('P','A','R')) ;
ALTER TABLE PLANS           ADD CONSTRAINT PLAN_OFFLINE_CK         CHECK (offline_download IN ('S','N')) ;
ALTER TABLE PROFILES        ADD CONSTRAINT PROFILE_TYPE_CK         CHECK (profile_type IN ('E','I')) ;
ALTER TABLE PROMO_CODES     ADD CONSTRAINT PROMO_CODE_TYPE_CK      CHECK (discount_type IN ('PORCENTAJE','VALOR_FIJO')) ;
ALTER TABLE PROMO_CODES     ADD CONSTRAINT PROMO_CODE_STATE_CK     CHECK (state IN ('A','I')) ;
ALTER TABLE REPRODUCTION_PROGRESS ADD CONSTRAINT PROGRESS_FINISHED_CK CHECK (finished IN ('S','N')) ;
ALTER TABLE SUBSCRIPTIONS   ADD CONSTRAINT SUBSCRIPTION_STATE_CK   CHECK (state IN ('A','S','C')) ;
ALTER TABLE SUBSCRIPTIONS   ADD CONSTRAINT SUBSCRIPTION_RENEW_CK   CHECK (auto_renew IN ('S','N')) ;

-- Reglas de fechas y rangos.
ALTER TABLE SUBSCRIPTIONS   ADD CONSTRAINT SUBSCRIPTION_END_CK     CHECK (end_date IS NULL OR end_date >= start_date) ;
ALTER TABLE REPRODUCTIONS   ADD CONSTRAINT REPRODUCTION_DATES_CK   CHECK (end_date IS NULL OR end_date >= start_date) ;
ALTER TABLE PAYMENTS        ADD CONSTRAINT PAYMENT_PERIOD_CK       CHECK (billing_period_end > billing_period_start) ;
ALTER TABLE DOWNLOADS       ADD CONSTRAINT DOWNLOAD_DATES_CK       CHECK (expiration_date > download_date) ;
ALTER TABLE PROMO_CODES     ADD CONSTRAINT PROMO_CODE_DATES_CK     CHECK (valid_to >= valid_from) ;
ALTER TABLE PROMO_CODES     ADD CONSTRAINT PROMO_CODE_USES_CK      CHECK (uses_count BETWEEN 0 AND max_uses) ;
ALTER TABLE REPRODUCTION_PROGRESS ADD CONSTRAINT PROGRESS_PERCENT_CK CHECK (percentage_viewed BETWEEN 0 AND 100) ;


-- Informe de Resumen de Oracle SQL Developer Data Modeler: 
-- 
-- CREATE TABLE                            25
-- CREATE INDEX                             0
-- ALTER TABLE                             73
-- CREATE VIEW                              0
-- ALTER VIEW                               0
-- CREATE PACKAGE                           0
-- CREATE PACKAGE BODY                      0
-- CREATE PROCEDURE                         0
-- CREATE FUNCTION                          0
-- CREATE TRIGGER                           0
-- ALTER TRIGGER                            0
-- CREATE COLLECTION TYPE                   0
-- CREATE STRUCTURED TYPE                   0
-- CREATE STRUCTURED TYPE BODY              0
-- CREATE CLUSTER                           0
-- CREATE CONTEXT                           0
-- CREATE DATABASE                          0
-- CREATE DIMENSION                         0
-- CREATE DIRECTORY                         0
-- CREATE DISK GROUP                        0
-- CREATE ROLE                              0
-- CREATE ROLLBACK SEGMENT                  0
-- CREATE SEQUENCE                          0
-- CREATE MATERIALIZED VIEW                 0
-- CREATE MATERIALIZED VIEW LOG             0
-- CREATE SYNONYM                           0
-- CREATE TABLESPACE                        0
-- CREATE USER                              0
-- 
-- DROP TABLESPACE                          0
-- DROP DATABASE                            0
-- 
-- REDACTION POLICY                         0
-- 
-- ORDS DROP SCHEMA                         0
-- ORDS ENABLE SCHEMA                       0
-- ORDS ENABLE OBJECT                       0
-- 
-- ERRORS                                   0
-- WARNINGS                                 0