-- =====================================================================
-- PROYECTO VYNTRA - SCRIPT PL/SQL
-- Motor: Oracle Database 21c
--
-- Orden de ejecucion:
--   1. script_DDL.sql
--   2. Vyntra_Datos_de_Prueba.sql
--   3. script_PLSQL.sql   (este archivo)
--
-- Objetos creados:
--   1. FN_CALCULAR_MONTO          (funcion)
--   2. SP_REGISTRAR_PAGO          (procedimiento almacenado)
--   3. TRG_VALIDAR_REPRODUCCION   (trigger)
--
-- Codigos de error propios (RAISE_APPLICATION_ERROR):
--   -20001 .. -20009  FN_CALCULAR_MONTO
--   -20010 .. -20019  SP_REGISTRAR_PAGO
--   -20020 .. -20029  TRG_VALIDAR_REPRODUCCION
-- =====================================================================

SET SERVEROUTPUT ON;


-- =====================================================================
-- 1. FUNCION: FN_CALCULAR_MONTO
-- ---------------------------------------------------------------------
-- Funcionalidad:
--   Calcula el valor a cobrar por un periodo de suscripcion a partir
--   del precio del plan y, opcionalmente, de un codigo promocional.
--   Apoya la HU-4.4 (cobro automatico de cada periodo).
--
-- Parametros:
--   p_plan_id    (IN) id del plan en PLANS.
--   p_promo_code (IN) codigo promocional (PROMO_CODES.code), p. ej.
--                     'BIENV10'. NULL = sin descuento.
--   p_fecha      (IN) fecha con la que se valida la vigencia del
--                     codigo. Por defecto, la fecha actual.
--
-- Retorna:
--   NUMBER(12,2) con el monto final, redondeado a 2 decimales.
--
-- Reglas:
--   - PORCENTAJE: precio * (1 - descuento / 100).
--   - VALOR_FIJO: precio - descuento.
--   - El codigo solo aplica si esta activo (state = 'A'), si p_fecha
--     esta entre valid_from y valid_to y si uses_count < max_uses.
--   - El monto nunca baja de 1, porque PAYMENTS tiene CHECK (amount >= 1).
--   - No modifica datos: se puede usar dentro de un SELECT.
--
-- Errores:
--   -20001 El plan no existe.
--   -20002 El codigo promocional no existe.
--   -20003 El codigo promocional no es aplicable (inactivo, fuera de
--          vigencia o sin usos disponibles).
--
-- Ejemplo:
--   SELECT FN_CALCULAR_MONTO(3, 'BIENV10', DATE '2026-11-22') FROM dual;  -- 13.49
-- =====================================================================
CREATE OR REPLACE FUNCTION FN_CALCULAR_MONTO (
    p_plan_id    IN PLANS.id%TYPE,
    p_promo_code IN PROMO_CODES.code%TYPE DEFAULT NULL,
    p_fecha      IN DATE                  DEFAULT SYSDATE
) RETURN NUMBER
IS
    v_precio PLANS.price%TYPE;
    v_promo  PROMO_CODES%ROWTYPE;
    v_monto  NUMBER(12,2);
BEGIN
    -- Precio base del plan
    BEGIN
        SELECT price INTO v_precio
        FROM PLANS
        WHERE id = p_plan_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'El plan ' || p_plan_id || ' no existe.');
    END;

    -- Sin codigo promocional: se cobra el precio completo
    IF p_promo_code IS NULL THEN
        RETURN v_precio;
    END IF;

    BEGIN
        SELECT * INTO v_promo
        FROM PROMO_CODES
        WHERE code = p_promo_code;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'El codigo promocional ' || p_promo_code || ' no existe.');
    END;

    IF v_promo.state <> 'A'
       OR TRUNC(p_fecha) NOT BETWEEN v_promo.valid_from AND v_promo.valid_to
       OR v_promo.uses_count >= v_promo.max_uses THEN
        RAISE_APPLICATION_ERROR(-20003, 'El codigo promocional ' || p_promo_code
            || ' no es aplicable (inactivo, fuera de vigencia o sin usos disponibles).');
    END IF;

    IF v_promo.discount_type = 'PORCENTAJE' THEN
        v_monto := v_precio * (1 - v_promo.discount_value / 100);
    ELSE -- VALOR_FIJO
        v_monto := v_precio - v_promo.discount_value;
    END IF;

    RETURN GREATEST(ROUND(v_monto, 2), 1);
END FN_CALCULAR_MONTO;
/


-- =====================================================================
-- 2. PROCEDIMIENTO: SP_REGISTRAR_PAGO
-- ---------------------------------------------------------------------
-- Funcionalidad:
--   Registra en PAYMENTS el cobro del siguiente periodo mensual de una
--   suscripcion activa. Apoya las HU-4.4 (cobro automatico) y
--   HU-4.6 (renovacion automatica).
--
-- Parametros:
--   p_subscription_id   (IN)  suscripcion a cobrar.
--   p_payment_method_id (IN)  tarjeta con la que se cobra.
--   p_promo_code        (IN)  codigo promocional opcional (NULL = ninguno).
--   p_payment_id        (OUT) id del pago creado (p. ej. 'PAY00290').
--
-- Pasos:
--   1. Bloquea la suscripcion (FOR UPDATE) y verifica que este activa
--      (state = 'A'). Una suscripcion cancelada o suspendida no se cobra.
--   2. Verifica que la tarjeta pertenezca al titular de la suscripcion,
--      este activa (state = 'A') y no este vencida en la fecha del cobro.
--   3. Calcula el periodo: empieza el dia siguiente al fin del ultimo
--      pago APROBADO (si el ultimo fue rechazado, se vuelve a intentar
--      el mismo periodo). Si no hay pagos, empieza en start_date de la
--      suscripcion. El fin es un mes despues menos un dia, igual que en
--      los datos de prueba.
--   4. Calcula el monto con FN_CALCULAR_MONTO usando el plan actual de
--      la suscripcion.
--   5. Genera el siguiente id ('PAY' + 5 digitos) y el siguiente
--      invoice_number e inserta el pago como aprobado (state = 'A').
--      payment_date = inicio del periodo, como en los datos de prueba.
--   6. Si se uso un codigo promocional, suma 1 a su uses_count.
--
-- Control transaccional:
--   NO hace COMMIT. Quien lo llama decide si confirma (COMMIT) o
--   deshace (ROLLBACK). Si algo falla, Oracle deshace solo lo que
--   hizo esta llamada.
--
-- Concurrencia:
--   Como el esquema no tiene secuencias, el id y el invoice_number se
--   calculan con MAX + 1. Para que dos cobros simultaneos no generen
--   el mismo numero se bloquea PAYMENTS en modo EXCLUSIVE hasta el
--   COMMIT/ROLLBACK del llamador.
--
-- Errores:
--   -20010 La suscripcion no existe.
--   -20011 La suscripcion no esta activa.
--   -20012 El metodo de pago no existe o no pertenece al titular.
--   -20013 El metodo de pago esta inactivo o vencido.
--   -20014 El codigo promocional se quedo sin usos al momento de aplicarlo.
--   (Tambien puede propagar -20001 a -20003 desde FN_CALCULAR_MONTO.)
--
-- Ejemplo:
--   DECLARE v_id PAYMENTS.id%TYPE;
--   BEGIN
--       SP_REGISTRAR_PAGO(1, 'PM0001', 'BIENV10', v_id);
--       DBMS_OUTPUT.PUT_LINE(v_id);
--   END;
-- =====================================================================
CREATE OR REPLACE PROCEDURE SP_REGISTRAR_PAGO (
    p_subscription_id   IN  SUBSCRIPTIONS.id%TYPE,
    p_payment_method_id IN  PAYMENT_METHODS.id%TYPE,
    p_promo_code        IN  PROMO_CODES.code%TYPE DEFAULT NULL,
    p_payment_id        OUT PAYMENTS.id%TYPE
)
IS
    v_sub        SUBSCRIPTIONS%ROWTYPE;
    v_pm         PAYMENT_METHODS%ROWTYPE;
    v_promo_id   PROMO_CODES.id%TYPE;
    v_inicio     DATE;
    v_fin        DATE;
    v_monto      PAYMENTS.amount%TYPE;
    v_num_pago   NUMBER;
    v_factura    PAYMENTS.invoice_number%TYPE;
BEGIN
    -- 1. Suscripcion activa (se bloquea para evitar cobros duplicados)
    BEGIN
        SELECT * INTO v_sub
        FROM SUBSCRIPTIONS
        WHERE id = p_subscription_id
        FOR UPDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'La suscripcion ' || p_subscription_id || ' no existe.');
    END;

    IF v_sub.state <> 'A' THEN
        RAISE_APPLICATION_ERROR(-20011, 'La suscripcion ' || p_subscription_id
            || ' no esta activa (estado ' || v_sub.state || ').');
    END IF;

    -- 3. Periodo a cobrar (se calcula antes para validar la tarjeta en esa fecha)
    SELECT MAX(billing_period_end) + 1 INTO v_inicio
    FROM PAYMENTS
    WHERE SUBSCRIPTION_id = p_subscription_id
      AND state = 'A';

    v_inicio := NVL(v_inicio, v_sub.start_date);
    v_fin    := ADD_MONTHS(v_inicio, 1) - 1;

    -- 2. Metodo de pago del titular, activo y vigente
    BEGIN
        SELECT * INTO v_pm
        FROM PAYMENT_METHODS
        WHERE id = p_payment_method_id
          AND USER_id = v_sub.USER_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20012, 'El metodo de pago ' || p_payment_method_id
                || ' no existe o no pertenece al titular de la suscripcion.');
    END;

    IF v_pm.state <> 'A' OR v_pm.expiration_date < v_inicio THEN
        RAISE_APPLICATION_ERROR(-20013, 'El metodo de pago ' || p_payment_method_id
            || ' esta inactivo o vencido.');
    END IF;

    -- 4. Monto (valida plan y codigo promocional)
    v_monto := FN_CALCULAR_MONTO(v_sub.PLAN_id, p_promo_code, v_inicio);

    IF p_promo_code IS NOT NULL THEN
        SELECT id INTO v_promo_id FROM PROMO_CODES WHERE code = p_promo_code;
    END IF;

    -- 5. Siguiente id y numero de factura
    LOCK TABLE PAYMENTS IN EXCLUSIVE MODE;

    SELECT NVL(MAX(TO_NUMBER(SUBSTR(id, 4))), 0) + 1,
           NVL(MAX(invoice_number), 100000) + 1
    INTO v_num_pago, v_factura
    FROM PAYMENTS
    WHERE id LIKE 'PAY%';

    p_payment_id := 'PAY' || LPAD(v_num_pago, 5, '0');

    INSERT INTO PAYMENTS (id, amount, billing_period_start, billing_period_end,
                          payment_date, invoice_number, state, SUBSCRIPTION_id,
                          PAYMENT_METHODS_id, PROMO_CODE_id, PLANS_id)
    VALUES (p_payment_id, v_monto, v_inicio, v_fin,
            v_inicio, v_factura, 'A', p_subscription_id,
            p_payment_method_id, v_promo_id, v_sub.PLAN_id);

    -- 6. Consumir un uso del codigo promocional
    IF v_promo_id IS NOT NULL THEN
        UPDATE PROMO_CODES
        SET uses_count = uses_count + 1
        WHERE id = v_promo_id
          AND uses_count < max_uses;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20014, 'El codigo promocional ' || p_promo_code
                || ' se quedo sin usos disponibles.');
        END IF;
    END IF;
END SP_REGISTRAR_PAGO;
/


-- =====================================================================
-- 3. TRIGGER: TRG_VALIDAR_REPRODUCCION
-- ---------------------------------------------------------------------
-- Funcionalidad:
--   Antes de insertar (o de cambiar perfil, titulo, calidad o fecha
--   de) una fila en REPRODUCTIONS, verifica las reglas de negocio del
--   caso de estudio que el DDL no puede expresar con un CHECK, porque
--   dependen de otras tablas. Si alguna no se cumple, la operacion se
--   rechaza con RAISE_APPLICATION_ERROR.
--   Apoya las HU-1.3, HU-2.5, HU-3.1 y HU-3.2.
--
-- Reglas que valida:
--   1. Periodo pagado: la suscripcion del perfil debe tener un pago
--      APROBADO cuyo periodo cubra la fecha de la reproduccion. Asi
--      una suscripcion cancelada conserva acceso hasta el final del
--      periodo que ya pago, pero no despues.
--   2. Calidad: quality_reproduction no puede superar max_quality del
--      plan de ESE periodo pagado (PAYMENTS.PLANS_id). Se usa el plan
--      del pago y no el actual porque un usuario pudo cambiar de plan:
--      sus reproducciones viejas se juzgan con el plan que tenia.
--   3. Perfil infantil: un perfil de tipo 'I' solo puede reproducir
--      titulos con age_rating 'TP' o '7+'.
--   4. Disponibilidad: el titulo debe estar disponible (AVAILABILITY)
--      en el pais del titular desde una fecha anterior o igual a la
--      de la reproduccion.
--
-- Notas de diseno:
--   - Es BEFORE ... FOR EACH ROW: valida cada fila antes de escribirla.
--   - Si el perfil o el titulo no existen, el trigger no hace nada y
--     deja que la llave foranea correspondiente rechace la fila.
--   - Solo consulta PROFILES, SUBSCRIPTIONS, USERS, PAYMENTS, PLANS,
--     TITLES y AVAILABILITY; nunca REPRODUCTIONS, asi que no produce
--     el error de tabla mutante (ORA-04091).
--   - Las 876 reproducciones de Vyntra_Datos_de_Prueba.sql cumplen
--     estas 4 reglas, por lo que el script de datos se puede volver a
--     cargar con el trigger ya creado.
--
-- Errores:
--   -20020 La suscripcion no tiene un periodo pagado en esa fecha.
--   -20021 La calidad supera la permitida por el plan.
--   -20022 Perfil infantil intentando reproducir contenido no apto.
--   -20023 El titulo no esta disponible en el pais del usuario.
-- =====================================================================
CREATE OR REPLACE TRIGGER TRG_VALIDAR_REPRODUCCION
BEFORE INSERT OR UPDATE OF PROFILE_id, TITLE_id, quality_reproduction, start_date
ON REPRODUCTIONS
FOR EACH ROW
DECLARE
    v_tipo_perfil  PROFILES.profile_type%TYPE;
    v_sub_id       SUBSCRIPTIONS.id%TYPE;
    v_pais         USERS.COUNTRY_id%TYPE;
    v_plan_id      PLANS.id%TYPE;
    v_max_calidad  PLANS.max_quality%TYPE;
    v_clasif       TITLES.age_rating%TYPE;
    v_disponible   NUMBER;
BEGIN
    -- Datos del perfil: tipo, suscripcion y pais del titular.
    -- Si el perfil no existe no se valida nada aqui: la FK
    -- REPRODUCTION_PROFILE_FK rechaza la fila con ORA-02291.
    BEGIN
        SELECT P.profile_type, S.id, U.COUNTRY_id
        INTO v_tipo_perfil, v_sub_id, v_pais
        FROM PROFILES P
        INNER JOIN SUBSCRIPTIONS S ON P.SUBSCRIPTION_id = S.id
        INNER JOIN USERS U ON S.USER_id = U.id
        WHERE P.id = :NEW.PROFILE_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN;
    END;

    -- Regla 1: periodo pagado que cubra la fecha (el mas reciente si hay varios)
    BEGIN
        SELECT PA.PLANS_id
        INTO v_plan_id
        FROM PAYMENTS PA
        WHERE PA.SUBSCRIPTION_id = v_sub_id
          AND PA.state = 'A'
          AND TRUNC(:NEW.start_date) BETWEEN PA.billing_period_start AND PA.billing_period_end
        ORDER BY PA.billing_period_start DESC
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20020, 'La suscripcion ' || v_sub_id
                || ' no tiene un periodo pagado que cubra la fecha '
                || TO_CHAR(:NEW.start_date, 'YYYY-MM-DD') || '.');
    END;

    -- Regla 2: calidad maxima del plan de ese periodo
    SELECT max_quality INTO v_max_calidad
    FROM PLANS
    WHERE id = v_plan_id;

    IF :NEW.quality_reproduction > v_max_calidad THEN
        RAISE_APPLICATION_ERROR(-20021, 'Calidad ' || :NEW.quality_reproduction
            || ' no permitida: el plan del periodo permite maximo ' || v_max_calidad || '.');
    END IF;

    -- Regla 3: perfil infantil solo ve contenido TP o 7+
    -- (si el titulo no existe, la FK REPRODUCTION_TITLE_FK lo rechaza)
    BEGIN
        SELECT age_rating INTO v_clasif
        FROM TITLES
        WHERE id = :NEW.TITLE_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN;
    END;

    IF v_tipo_perfil = 'I' AND v_clasif NOT IN ('TP', '7+') THEN
        RAISE_APPLICATION_ERROR(-20022, 'El perfil ' || :NEW.PROFILE_id
            || ' es infantil y el titulo ' || :NEW.TITLE_id
            || ' tiene clasificacion ' || v_clasif || '.');
    END IF;

    -- Regla 4: disponibilidad del titulo en el pais del titular
    SELECT COUNT(*) INTO v_disponible
    FROM AVAILABILITY
    WHERE TITLE_id = :NEW.TITLE_id
      AND COUNTRY_id = v_pais
      AND available_date <= :NEW.start_date;

    IF v_disponible = 0 THEN
        RAISE_APPLICATION_ERROR(-20023, 'El titulo ' || :NEW.TITLE_id
            || ' no esta disponible en ' || v_pais || ' para la fecha '
            || TO_CHAR(:NEW.start_date, 'YYYY-MM-DD') || '.');
    END IF;
END TRG_VALIDAR_REPRODUCCION;
/


-- =====================================================================
-- 4. PRUEBAS
-- ---------------------------------------------------------------------
-- Cada prueba imprime OK / ERROR esperado con DBMS_OUTPUT. Todas las
-- modificaciones se deshacen con el ROLLBACK del final, asi que los
-- datos de prueba quedan intactos.
--
-- Datos usados (de Vyntra_Datos_de_Prueba.sql):
--   - Suscripcion 1: usuario 1 (MEX), plan 2 Estandar (max 1080),
--     activa, ultimo pago aprobado cubre 2026-10-28 a 2026-11-27.
--   - Perfil 1 = estandar, perfil 2 = infantil (ambos de la suscripcion 1).
--   - PM0001 = tarjeta activa del usuario 1; PM0002 = inactiva del
--     usuario 1; PM0003 = tarjeta de otro usuario.
--   - Suscripcion 4: cancelada.
--   - T002 = 'TP' disponible en MEX; T026 = '18+' disponible en MEX;
--     T001 = no disponible en MEX.
-- =====================================================================

-- 4.1 Funcion
SELECT FN_CALCULAR_MONTO(2, NULL)                          AS ESTANDAR_SIN_PROMO,  -- 9.99
       FN_CALCULAR_MONTO(3, 'BIENV10', DATE '2026-11-22')  AS PREMIUM_10_PORC,     -- 13.49
       FN_CALCULAR_MONTO(2, 'COL2026', DATE '2026-11-22')  AS ESTANDAR_MENOS_2     -- 7.99
FROM dual;

DECLARE
    PROCEDURE probar(p_desc VARCHAR2, p_plan NUMBER, p_code VARCHAR2) IS
        v NUMBER;
    BEGIN
        v := FN_CALCULAR_MONTO(p_plan, p_code, DATE '2026-11-22');
        DBMS_OUTPUT.PUT_LINE('[FALLO] ' || p_desc || ' devolvio ' || v);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[OK] ' || p_desc || ' -> ' || SQLERRM);
    END;
BEGIN
    probar('Plan inexistente',        99, NULL);        -- -20001
    probar('Codigo inexistente',       2, 'NOEXISTE');  -- -20002
    probar('Codigo vencido/inactivo',  2, 'LANZA50');   -- -20003
END;
/

-- 4.2 Procedimiento
DECLARE
    v_id    PAYMENTS.id%TYPE;
    v_pago  PAYMENTS%ROWTYPE;
    v_usos  PROMO_CODES.uses_count%TYPE;

    PROCEDURE probar_error(p_desc VARCHAR2, p_sub NUMBER, p_pm VARCHAR2, p_code VARCHAR2) IS
        v_x PAYMENTS.id%TYPE;
    BEGIN
        SP_REGISTRAR_PAGO(p_sub, p_pm, p_code, v_x);
        DBMS_OUTPUT.PUT_LINE('[FALLO] ' || p_desc || ' creo el pago ' || v_x);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[OK] ' || p_desc || ' -> ' || SQLERRM);
    END;
BEGIN
    -- Caso valido: suscripcion 1, tarjeta PM0001, codigo BIENV10 (10%)
    SELECT uses_count INTO v_usos FROM PROMO_CODES WHERE code = 'BIENV10';
    SP_REGISTRAR_PAGO(1, 'PM0001', 'BIENV10', v_id);
    SELECT * INTO v_pago FROM PAYMENTS WHERE id = v_id;
    DBMS_OUTPUT.PUT_LINE('[OK] Pago creado ' || v_id
        || ' | periodo ' || TO_CHAR(v_pago.billing_period_start, 'YYYY-MM-DD')
        || ' a ' || TO_CHAR(v_pago.billing_period_end, 'YYYY-MM-DD')
        || ' | monto ' || v_pago.amount
        || ' | factura ' || v_pago.invoice_number);     -- 2026-11-28 a 2026-12-27, 8.99
    SELECT uses_count - v_usos INTO v_usos FROM PROMO_CODES WHERE code = 'BIENV10';
    DBMS_OUTPUT.PUT_LINE('[OK] uses_count de BIENV10 aumento en ' || v_usos);  -- 1

    -- Casos de error
    probar_error('Suscripcion inexistente',   9999, 'PM0001', NULL);  -- -20010
    probar_error('Suscripcion cancelada',        4, 'PM0005', NULL);  -- -20011
    probar_error('Tarjeta de otro usuario',      1, 'PM0003', NULL);  -- -20012
    probar_error('Tarjeta inactiva',             1, 'PM0002', NULL);  -- -20013
    probar_error('Codigo no aplicable',          1, 'PM0001', 'LANZA50');  -- -20003
END;
/

-- 4.3 Trigger
DECLARE
    PROCEDURE probar(p_desc VARCHAR2, p_id VARCHAR2, p_perfil NUMBER,
                     p_titulo VARCHAR2, p_calidad NUMBER, p_fecha DATE) IS
    BEGIN
        INSERT INTO REPRODUCTIONS (id, start_date, end_date, quality_reproduction,
                                   PROFILE_id, TITLE_id)
        VALUES (p_id, p_fecha, p_fecha + 1/24, p_calidad, p_perfil, p_titulo);
        DBMS_OUTPUT.PUT_LINE('[INSERTADA] ' || p_desc);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[RECHAZADA] ' || p_desc || ' -> ' || SQLERRM);
    END;
BEGIN
    probar('Valida: perfil estandar, TP, 1080',  'RTEST01', 1, 'T002', 1080, TO_DATE('2026-11-22 20:00', 'YYYY-MM-DD HH24:MI'));  -- se inserta
    probar('Valida: perfil infantil, TP, 720',   'RTEST02', 2, 'T002',  720, TO_DATE('2026-11-22 18:00', 'YYYY-MM-DD HH24:MI'));  -- se inserta
    probar('Sin periodo pagado',                 'RTEST03', 1, 'T002', 1080, TO_DATE('2027-03-01 20:00', 'YYYY-MM-DD HH24:MI'));  -- -20020
    probar('Calidad 4K en plan Estandar',        'RTEST04', 1, 'T002', 2160, TO_DATE('2026-11-22 20:00', 'YYYY-MM-DD HH24:MI'));  -- -20021
    probar('Perfil infantil con titulo 18+',     'RTEST05', 2, 'T026',  720, TO_DATE('2026-11-22 20:00', 'YYYY-MM-DD HH24:MI'));  -- -20022
    probar('Titulo no disponible en MEX',        'RTEST06', 1, 'T001', 1080, TO_DATE('2026-11-22 20:00', 'YYYY-MM-DD HH24:MI'));  -- -20023
END;
/

-- Deshace todo lo que hicieron las pruebas
ROLLBACK;
