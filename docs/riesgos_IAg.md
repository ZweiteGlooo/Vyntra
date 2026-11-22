# Vyntra - Plataforma de Streaming

**Integrantes:** Gloribeth Rentería, Valentina Tangarife, Isabella Vergara, Verónica Flor y Nicolás Mejía.

**Riesgos del uso de herramientas de IAg en el diseño y desarrollo de bases de datos**

## 1. Introducción

Las herramientas de inteligencia artificial generativa (IAg), como ChatGPT, Claude, Gemini o Copilot, pueden producir en segundos scripts DDL, inserts, consultas y bloques PL/SQL. Para un proyecto como Vyntra (25 tablas, 5.000 líneas de datos de prueba, reglas de negocio por plan, perfil y país) esto resulta tentador, pero un resultado que "se ve bien" no garantiza que sea correcto, seguro ni coherente con el caso de estudio.

Este documento recopila los riesgos que identificamos al usar IAg en actividades como las de esta entrega (DDL, DML, DQL y PL/SQL) dentro de un contexto profesional, usando como ejemplo el repositorio de Vyntra, y define las medidas que adoptamos para mitigarlos.

**Contexto técnico del proyecto:** el repositorio está construido sobre **Oracle Database 21c** (el DDL fue generado con Oracle SQL Developer Data Modeler y usa `VARCHAR2`, `NUMBER` y bloques `BEGIN ... END;`). Varios de los riesgos descritos a continuación nacen de la distancia entre lo que una IAg suele generar por defecto y lo que realmente acepta este motor.

## 2. Riesgos técnicos

**2.1 Alucinaciones sobre el esquema**

La IAg no conoce nuestro modelo a menos que se lo entreguemos completo, y aun así puede inventar elementos. Por ejemplo, puede escribir una consulta con `SUBSCRIPTIONS.cancel_date` cuando esa columna no existe, usar `USER_ID` en lugar de `USER_id`, o asumir una tabla `WATCH_HISTORY` cuando en Vyntra el historial vive en `REPRODUCTIONS` y `REPRODUCTION_PROGRESS`.

- *Consecuencia:* errores `ORA-00904` (identificador no válido) o `ORA-00942` (tabla inexistente), o peor, una consulta que corre pero apunta a la tabla equivocada.

**2.2 Mezcla de dialectos SQL**

El enunciado pide "al menos un TOP", palabra propia de SQL Server. En Oracle 21c `SELECT TOP 10 ...` **no funciona**; el equivalente es `FETCH FIRST 10 ROWS ONLY` (o `ROWNUM`). Una IAg puede entregar sintaxis de T-SQL, MySQL (`LIMIT`, `AUTO_INCREMENT`) o PostgreSQL mezclada con PL/SQL sin avisar.

- *Consecuencia:* scripts que fallan en la ejecución o que "se corrigen" de forma parcial, dejando lógica inconsistente.

**2.3 Consultas que funcionan pero entregan datos incorrectos**

Es el riesgo más difícil de detectar porque no genera error. Ejemplos relevantes para los reportes ejecutivos de Vyntra:

- *Usuarios activos:* contar `USERS` en lugar de usuarios con suscripción vigente o con reproducciones en el mes.
- *Contenido más visto:* usar `INNER JOIN` cuando se necesita `LEFT JOIN` para incluir títulos sin reproducciones, o contar reproducciones por episodio en lugar de por título.
- *Tasa de cancelación:* dividir entre el total histórico de suscripciones en vez de las activas al inicio del periodo, o dejar un `GROUP BY` incompleto que altere los totales.
- *Ranking:* ordenar sin criterio de desempate, de modo que el "Top N" cambie entre ejecuciones.

**2.4 Reglas de negocio olvidadas o mal interpretadas**

El caso de estudio contiene reglas que la IAg tiende a omitir si no se le indican de forma explícita:

- Un perfil infantil solo puede acceder a títulos aptos (`TP` o `7+`).
- La calidad de reproducción no puede superar la del plan vigente.
- Solo el plan Premium permite descargas offline.
- Un título solo se reproduce si está disponible en el país del usuario.
- Solo se admiten tarjetas de crédito o débito (`CREDITO` / `DEBITO`).
- No hay reproducciones simultáneas por encima de las pantallas del plan.

*Consecuencia:* un DDL, un trigger o un procedimiento "correctos" sintácticamente pero que permiten estados que el negocio prohíbe.

**2.5 Datos de prueba incoherentes**

Los inserts generados por IAg suelen respetar la sintaxis, pero no la lógica. Casos típicos: pagos con `billing_period_end` anterior a `billing_period_start`, cobros posteriores a una cancelación, reproducciones anteriores a la fecha de registro del usuario, descargas en suscripciones Básico o Estándar, o `uses_count` de un código promocional que no coincide con los pagos que lo usan. También puede no cumplir el mínimo de 10 registros por reporte o romper claves foráneas por insertar en un orden incorrecto.

**2.6 Código PL/SQL con errores de lógica y de concurrencia**

Procedimientos, funciones y triggers generados por IAg pueden presentar:

- Triggers que consultan la misma tabla que los dispara (error `ORA-04091`, tabla mutante).
- Manejo de excepciones genérico (`WHEN OTHERS THEN NULL`) que oculta fallos reales.
- `COMMIT` dentro de un procedimiento que debería dejar el control transaccional al llamador.
- Ausencia de validación de parámetros nulos o de casos límite (suscripción cancelada, plan inexistente).

**2.7 Rendimiento y diseño**

La IAg rara vez propone índices sobre las llaves foráneas más consultadas, puede usar subconsultas correlacionadas costosas donde bastaría un `JOIN`, o sugerir desnormalizaciones que rompen el modelo relacional ya validado (por ejemplo, duplicar el nombre del plan en `PAYMENTS` en lugar de usar `PLANS_id`).

**2.8 Documentación que no corresponde al código**

Los comentarios generados automáticamente pueden describir lo que el código *debería* hacer y no lo que realmente hace. Esto es especialmente grave en esta entrega, donde cada procedimiento, función y trigger debe estar documentado con su funcionalidad.

## 3. Riesgos de seguridad y privacidad

**3.1 Exposición de información al enviarla a un servicio externo**

Al pegar esquemas, scripts o datos en una herramienta de IAg, la información sale de nuestro entorno y puede ser almacenada o usada según los términos del proveedor. En un contexto profesional esto aplica a:

- Esquemas completos de bases de datos de clientes (propiedad intelectual).
- Datos reales de usuarios (nombre, correo, país, historial de consumo).
- Datos de pago: en Vyntra `PAYMENT_METHODS` guarda `card_number_masked` y `cardholder_name`; nunca deben compartirse datos reales de tarjetas.
- Credenciales, cadenas de conexión y contraseñas (la tabla `USERS` almacena `password_hash`; ni siquiera un hash real debe pegarse en un prompt).

**3.2 Código vulnerable generado sin revisión**

La IAg puede construir SQL dinámico concatenando parámetros con `EXECUTE IMMEDIATE`, lo que abre la puerta a **inyección SQL**; o proponer permisos excesivos (`GRANT ALL`, uso del usuario `SYSTEM`) por comodidad.

**3.3 Cumplimiento normativo**

Vyntra opera en Colombia, México, Ecuador y Perú, cada uno con su propia ley de protección de datos personales (por ejemplo, la Ley 1581 de 2012 en Colombia y la LFPDPPP en México). Trabajar con datos reales de usuarios en herramientas externas sin autorización o base legal puede constituir una infracción, aunque el código generado sea correcto.

## 4. Riesgos éticos y legales

- **Autoría y propiedad intelectual:** el código generado puede parecerse a fragmentos con licencias específicas, y no siempre es claro quién es el titular de lo producido.
- **Sesgos:** los datos de prueba sugeridos (nombres, nacionalidades, títulos) pueden reflejar estereotipos o sobrerrepresentar ciertos países y géneros, lo que afecta la calidad de los reportes de ejemplo.
- **Transparencia:** presentar como propio un trabajo generado total o parcialmente por IAg, sin declararlo, es una falta académica y, en el ámbito laboral, un problema de confianza con el cliente.
- **Responsabilidad:** la IAg no responde por errores en producción; la responsabilidad recae siempre en quien entrega el trabajo.

## 5. Riesgos profesionales y de equipo

- **Dependencia y pérdida de criterio:** aceptar el código sin entenderlo impide defenderlo, mantenerlo o corregirlo (por ejemplo, ante una pregunta sobre por qué un trigger usa cierto tipo de evento).
- **Inconsistencia entre integrantes:** si cada persona usa una herramienta o un prompt distinto, los scripts del repositorio terminan con convenciones de nombres, estilos y supuestos diferentes (idiomas, mayúsculas, formato de estados `'A'/'I'` vs. `'S'/'N'`).
- **Falta de trazabilidad:** sin registro de qué se generó con IAg y qué se revisó, es imposible auditar el origen de un error.
- **Falsa sensación de avance:** generar mucho código rápido no equivale a tener un entregable correcto; el costo se traslada a la depuración.

## 6. Medidas de mitigación

| Riesgo | Medida aplicada |
|---|---|
| Alucinaciones del esquema | Entregar siempre a la IAg el DDL real y contrastar cada tabla y columna usada con `script_DDL.sql`. |
| Mezcla de dialectos | Indicar en el prompt "Oracle Database 21c / PL/SQL" y validar con la documentación oficial de Oracle; usar `FETCH FIRST n ROWS ONLY` en lugar de `TOP`. |
| Resultados incorrectos | Ejecutar cada consulta en Oracle SQL Developer y verificar los totales con un conteo manual sobre una muestra pequeña. |
| Reglas de negocio | Enumerar las reglas del caso de estudio en el prompt y mantenerlas documentadas en el encabezado de los scripts (como ya se hace en `Vyntra_Datos_de_Prueba.sql`). |
| Datos incoherentes | Validar los inserts con consultas de verificación (fechas, claves foráneas, conteos por reporte) y recrear el esquema con el bloque de borrado del DDL para probar desde cero. |
| PL/SQL | Probar cada procedimiento, función y trigger con casos normales, nulos y de error; revisar manejo de excepciones y control de transacciones. |
| Privacidad | Usar únicamente datos ficticios; no pegar credenciales, datos de tarjetas ni información de personas reales. |
| Seguridad | Preferir variables de enlace (`:param`) frente a SQL dinámico concatenado y aplicar el principio de mínimo privilegio. |
| Trazabilidad | Versionar todo en Git con commits pequeños y descriptivos, y revisar los cambios entre pares (pull request) antes de integrarlos. |
| Transparencia | Declarar el uso de IAg (sección 7) y asegurar que cada integrante pueda explicar el código que entrega. |

## 7. Declaración de uso de IAg en este proyecto


| Actividad | Herramienta usada                                                                                        | Uso (ej. generación, revisión, explicación) | Verificación realizada                                                                                                                                                                                                                                                                                                       |
|---|----------------------------------------------------------------------------------------------------------|---|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| DDL | Oracle SQL Developer Data Modeler (generación a partir del modelo) y Claude (modificaciones posteriores) | El script base se generó desde el modelo; luego se ajustó con Claude (correcciones, restricciones, comentarios). | _[por completar]_                                                                                                                                                                                                                                                                                                            |
| DML (inserts) | Claude                                                                                                   | Generación de todas las tuplas de datos de prueba (`Vyntra_Datos_de_Prueba.sql`). | _[por completar]_                                                                                                                                                                                                                                                                                                            |
| DQL (consultas) | ChatGPT                                                                                                  | Generación de las consultas de los reportes ejecutivos. | La información generada se contrastó con el esquema y los datos existentes del proyecto. Se corrigieron consultas en las que la herramienta usaba elementos sin sentido para el caso (por ejemplo, referencias que no correspondían al modelo). Además, se revisó cada consulta frente a lo solicitado en el enunciado de la entrega.                                                                                                                                                                                                                                                                                                           |
| PL/SQL | Claude                                                                                                   | Generación del borrador de `script_PLSQL.sql` (función, procedimiento y trigger) a partir del DDL, los datos de prueba y las HU; las reglas del trigger se contrastaron contra las 876 reproducciones de los datos de prueba. | Se ejecutó en Oracle 21c después del DDL y los datos de prueba: los tres objetos compilaron sin errores y las pruebas del script (casos válidos y de error) dieron el resultado esperado. Se verificó que el `ROLLBACK` final deja los datos intactos y que los datos de prueba se cargan sin errores con el trigger activo. |
| Documentación | Claude                                                                                                   | Redacción del borrador a partir del caso de estudio y del repositorio. | Se contrastó el contenido con script_DDL.sql, el caso de estudio y las historias de usuario, y se ajustó la sección 7 con lo reportado por cada integrante.                                                                                                                                                                  |

## 8. Conclusión

La IAg es una herramienta de apoyo valiosa para acelerar tareas repetitivas, explorar alternativas y detectar errores, pero no reemplaza el conocimiento del modelo, de las reglas de negocio ni del motor de base de datos. En Vyntra, donde un error puede significar cobros incorrectos, contenido no apto visible en un perfil infantil o datos personales expuestos, el criterio humano es el control final. Por ello, nuestro equipo adopta el principio de **usar la IAg como asistente, nunca como autora**: todo lo generado se revisa, se prueba, se documenta y se declara.