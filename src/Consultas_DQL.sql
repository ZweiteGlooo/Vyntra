-- PROYECTO VYNTRA - CONSULTAS DQL (REPORTES)


-- REPORTE 1: USUARIOS REGISTRADOS POR PAIS
-- Descripcion:
-- Consultar la cantidad de usuarios registrados en cada pais
-- donde opera Vyntra, mostrando el nombre del pais y la
-- cantidad de usuarios, ordenados de mayor a menor.
SELECT C.name_country AS PAIS,
       COUNT(U.id) AS CANTIDAD_USUARIOS
FROM COUNTRIES C
INNER JOIN USERS U ON C.id = U.COUNTRY_id
GROUP BY C.name_country
ORDER BY CANTIDAD_USUARIOS DESC;


-- REPORTE 2: PERFILES POR TIPO
-- Descripcion:
-- Consultar la cantidad de perfiles estandar e infantiles
-- creados en Vyntra, agrupados por tipo de perfil.
SELECT CASE
           WHEN P.profile_type = 'E' THEN 'ESTANDAR'
           WHEN P.profile_type = 'I' THEN 'INFANTIL'
       END AS TIPO_PERFIL,
       COUNT(P.id) AS CANTIDAD_PERFILES
FROM PROFILES P
INNER JOIN SUBSCRIPTIONS S ON P.SUBSCRIPTION_id = S.id
GROUP BY P.profile_type
ORDER BY CANTIDAD_PERFILES DESC;


-- REPORTE 3: USUARIOS CON SUS SUSCRIPCIONES
-- Descripcion:
-- Consultar los usuarios que tienen suscripciones registradas,
-- mostrando su nombre, correo, plan contratado y estado
-- de la suscripcion.
SELECT U.full_name AS NOMBRE_USUARIO,
       U.email AS CORREO,
       PL.name AS PLAN,
       S.state AS ESTADO_SUSCRIPCION
FROM USERS U
INNER JOIN SUBSCRIPTIONS S ON U.id = S.USER_id
INNER JOIN PLANS PL ON S.PLAN_id = PL.id
ORDER BY U.full_name;

-- REPORTE 4: USUARIOS SIN PERFILES
-- Descripcion:
-- Consultar los usuarios que tienen suscripciones pero
-- ninguna de estas suscripciones tiene perfiles asociados.

SELECT DISTINCT U.id,
       U.full_name AS NOMBRE_USUARIO,
       U.email AS CORREO
FROM USERS U
INNER JOIN SUBSCRIPTIONS S ON U.id = S.USER_id
LEFT OUTER JOIN PROFILES P ON S.id = P.SUBSCRIPTION_id
WHERE P.id IS NULL
ORDER BY U.full_name;

-- REPORTE 5: PLANES CON MAYOR NUMERO DE SUSCRIPCIONES
-- Descripcion:
-- Consultar la cantidad de suscripciones asociadas a cada
-- plan de Vyntra, ordenando los planes de mayor a menor
-- cantidad de suscripciones.
SELECT PL.name AS PLAN,
       COUNT(S.id) AS CANTIDAD_SUSCRIPCIONES
FROM PLANS PL
INNER JOIN SUBSCRIPTIONS S ON PL.id = S.PLAN_id
GROUP BY PL.name
ORDER BY CANTIDAD_SUSCRIPCIONES DESC;


-- REPORTE 6: CONTENIDOS MAS REPRODUCIDOS
-- Descripcion:
-- Consultar los 10 titulos con mayor cantidad de
-- reproducciones registradas, ordenados de mayor a menor.
SELECT T.title_name AS TITULO,
       COUNT(R.id) AS CANTIDAD_REPRODUCCIONES
FROM TITLES T
INNER JOIN REPRODUCTIONS R ON T.id = R.TITLE_id
GROUP BY T.title_name
ORDER BY CANTIDAD_REPRODUCCIONES DESC
FETCH FIRST 10 ROWS ONLY;


-- REPORTE 7: INGRESOS POR PLAN
-- Descripcion:
-- Consultar el total de ingresos generados por cada plan
-- a partir de los pagos aprobados, mostrando el nombre del
-- plan y el total recaudado, ordenado de mayor a menor.
SELECT PL.name AS PLAN,
       SUM(PA.amount) AS TOTAL_INGRESOS
FROM PLANS PL
INNER JOIN PAYMENTS PA ON PL.id = PA.PLANS_id
WHERE PA.state = 'A'
GROUP BY PL.name
ORDER BY TOTAL_INGRESOS DESC;


-- REPORTE 8: CONTENIDO POR GENERO
-- Descripcion:
-- Consultar la cantidad de titulos asociados a cada genero
-- del catalogo de Vyntra, ordenados de mayor a menor
-- cantidad de titulos.
SELECT G.name_genre AS GENERO,
       COUNT(C.TITLE_id) AS CANTIDAD_TITULOS
FROM GENRES G
INNER JOIN CLASSIFICATIONS C ON G.id = C.GENRE_id
INNER JOIN TITLES T ON C.TITLE_id = T.id
GROUP BY G.name_genre
ORDER BY CANTIDAD_TITULOS DESC;


-- REPORTE 9: PERFILES QUE NO HAN REPRODUCIDO CONTENIDO
-- Descripcion:
-- Consultar los perfiles que no tienen registros de
-- reproduccion, mostrando el nombre del perfil y la
-- suscripcion a la que pertenecen.
SELECT P.name AS NOMBRE_PERFIL,
       P.id AS ID_PERFIL,
       S.id AS ID_SUSCRIPCION
FROM PROFILES P
INNER JOIN SUBSCRIPTIONS S ON P.SUBSCRIPTION_id = S.id
LEFT OUTER JOIN REPRODUCTIONS R ON P.id = R.PROFILE_id
WHERE R.id IS NULL
ORDER BY P.name;


-- REPORTE 10: USUARIOS ACTIVOS MENSUALMENTE
-- Descripcion:
-- Consultar la cantidad de usuarios que realizaron
-- reproducciones en cada mes, considerando usuarios unicos
-- por mes y ordenando los resultados cronologicamente.
SELECT TO_CHAR(R.start_date, 'YYYY-MM') AS MES,
       COUNT(DISTINCT S.USER_id) AS USUARIOS_ACTIVOS
FROM REPRODUCTIONS R
INNER JOIN PROFILES P ON R.PROFILE_id = P.id
INNER JOIN SUBSCRIPTIONS S ON P.SUBSCRIPTION_id = S.id
GROUP BY TO_CHAR(R.start_date, 'YYYY-MM')
ORDER BY MES;

-- REPORTE 11: CONTENIDOS MAS AGREGADOS A FAVORITOS
-- Descripcion:
-- Consultar los titulos que han sido agregados mas veces
-- a la lista de favoritos de los perfiles de Vyntra.
SELECT T.title_name AS TITULO,
       COUNT(F.PROFILE_id) AS VECES_AGREGADO
FROM TITLES T
INNER JOIN FAVORITES F ON T.id = F.TITLE_id
GROUP BY T.title_name
ORDER BY VECES_AGREGADO DESC;

-- REPORTE 12: ACTORES CON MAS PARTICIPACIONES
-- Descripcion:
-- Consultar los actores que han participado en una mayor
-- cantidad de titulos del catalogo de Vyntra.
SELECT A.name AS ACTOR,
       A.nationality AS NACIONALIDAD,
       COUNT(P.TITLE_id) AS CANTIDAD_TITULOS
FROM ACTORS A
INNER JOIN PARTICIPATIONS P ON A.id = P.ACTOR_id
GROUP BY A.name, A.nationality
ORDER BY CANTIDAD_TITULOS DESC
FETCH FIRST 10 ROWS ONLY;

-- REPORTE 13: DISPONIBILIDAD DE CONTENIDO POR PAIS
-- Descripcion:
-- Consultar la cantidad de titulos disponibles en cada
-- pais donde opera Vyntra, mostrando el nombre del pais
-- y la cantidad de contenidos registrados.
SELECT C.name_country AS PAIS,
       COUNT(AV.TITLE_id) AS CANTIDAD_CONTENIDOS
FROM COUNTRIES C
INNER JOIN AVAILABILITY AV ON C.id = AV.COUNTRY_id
GROUP BY C.name_country
ORDER BY CANTIDAD_CONTENIDOS DESC;


-- REPORTE 14: SUBTITULOS DISPONIBLES POR IDIOMA
-- Descripcion:
-- Consultar la cantidad de titulos que tienen subtitulos
-- habilitados en cada idioma disponible en Vyntra.
SELECT L.name AS IDIOMA,
       COUNT(C.TITLE_id) AS CANTIDAD_TITULOS
FROM LANGUAGES L
INNER JOIN CAPTIONS C ON L.id = C.LANGUAGE_id
WHERE C.available = 'S'
GROUP BY L.name
ORDER BY CANTIDAD_TITULOS DESC;


-- REPORTE 15: DESCARGAS POR PERFIL
-- Descripcion:
-- Consultar la cantidad de descargas realizadas por cada
-- perfil, mostrando tambien el nombre del perfil y la
-- cantidad de descargas registradas.
SELECT P.name AS NOMBRE_PERFIL,
       COUNT(D.TITLES_id) AS CANTIDAD_DESCARGAS
FROM PROFILES P
INNER JOIN DOWNLOADS D ON P.id = D.PROFILES_id
GROUP BY P.id, P.name
ORDER BY CANTIDAD_DESCARGAS DESC;


-- REPORTE 16: CODIGOS PROMOCIONALES MAS UTILIZADOS
-- Descripcion:
-- Consultar los codigos promocionales registrados y la
-- cantidad de pagos en los que han sido utilizados,
-- incluyendo aquellos que todavia no tienen pagos asociados.
SELECT PC.code AS CODIGO_PROMOCIONAL,
       PC.uses_count AS USOS_REGISTRADOS,
       COUNT(PA.id) AS PAGOS_ASOCIADOS
FROM PROMO_CODES PC
LEFT OUTER JOIN PAYMENTS PA ON PC.id = PA.PROMO_CODE_id
GROUP BY PC.code, PC.uses_count
ORDER BY PAGOS_ASOCIADOS DESC;


-- REPORTE 17: RECOMENDACIONES POR PERFIL
-- Descripcion:
-- Consultar los titulos recomendados para cada perfil,
-- mostrando el nombre del perfil, el titulo recomendado
-- y su puntuacion de relevancia.
SELECT P.name AS PERFIL,
       T.title_name AS TITULO_RECOMENDADO,
       R.relevance_score AS PUNTUACION
FROM PROFILES P
INNER JOIN RECOMMENDATIONS R ON P.id = R.PROFILE_id
INNER JOIN TITLES T ON R.TITLE_id = T.id
ORDER BY R.relevance_score DESC;


-- REPORTE 18: CONTENIDOS PENDIENTES DE TERMINAR
-- Descripcion:
-- Consultar los titulos que los perfiles tienen pendientes
-- de terminar, mostrando el nombre del perfil, el titulo
-- y el porcentaje de reproduccion completado.
SELECT P.name AS PERFIL,
       T.title_name AS TITULO,
       RP.percentage_viewed AS PORCENTAJE_VISTO
FROM PROFILES P
INNER JOIN REPRODUCTION_PROGRESS RP ON P.id = RP.PROFILE_id
INNER JOIN TITLES T ON RP.TITLE_id = T.id
WHERE RP.finished = 'N'
ORDER BY RP.percentage_viewed DESC;


-- REPORTE 19: PAGOS POR ESTADO
-- Descripcion:
-- Consultar la cantidad de pagos y el valor total
-- correspondiente a cada estado de pago, diferenciando
-- los pagos pendientes, aprobados y rechazados.
SELECT CASE
           WHEN state = 'A' THEN 'APROBADO'
           WHEN state = 'P' THEN 'PENDIENTE'
           WHEN state = 'R' THEN 'RECHAZADO'
       END AS ESTADO_PAGO,
       COUNT(id) AS CANTIDAD_PAGOS,
       SUM(amount) AS VALOR_TOTAL
FROM PAYMENTS
GROUP BY state
ORDER BY CANTIDAD_PAGOS DESC;


-- REPORTE 20: DURACION PROMEDIO POR TIPO DE CONTENIDO
-- Descripcion:
-- Consultar la duracion promedio de las peliculas,
-- documentales y episodios registrados en Vyntra,
-- mostrando el promedio de minutos para cada tipo.
SELECT TIPO_CONTENIDO,
       ROUND(AVG(DURACION), 2) AS DURACION_PROMEDIO_MINUTOS
FROM (
    SELECT 'PELICULA' AS TIPO_CONTENIDO,
           M.duration_minute AS DURACION
    FROM MOVIES M

    UNION ALL

    SELECT 'DOCUMENTAL' AS TIPO_CONTENIDO,
           D.duration_minute AS DURACION
    FROM DOCUMENTARIES D

    UNION ALL

    SELECT 'EPISODIO' AS TIPO_CONTENIDO,
           E.duration_minute AS DURACION
    FROM EPISODES E
)
GROUP BY TIPO_CONTENIDO
ORDER BY DURACION_PROMEDIO_MINUTOS DESC;