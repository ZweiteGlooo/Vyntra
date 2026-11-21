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