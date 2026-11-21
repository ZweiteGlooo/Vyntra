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