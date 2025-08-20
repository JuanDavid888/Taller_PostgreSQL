# Taller Diseño de base de datos - Postgres

<img src="https://i.ibb.co/c0rfcc8/image.png" alt="image" border="0">

Teniendo en cuenta el diagrama entidad relación resuelva los siguientes requerimientos:

1. Genere los comandos DDL que permitan la creación de la base de datos del DER suministrado.
2. Genere los comandos DML que permitan insertar datos en la base de datos creada en el paso 1.

## Consultas

1. Obtén el “Top 10” de productos por unidades vendidas y su ingreso total, usando `JOIN ... USING`, agregación con `SUM()`, agrupación con `GROUP BY`, ordenamiento descendente con `ORDER BY` y paginado con `LIMIT`.

2. Calcula el total pagado promedio por compra y la mediana aproximada usando una subconsulta agregada y la función de ventana ordenada `PERCENTILE_CONT(...) WITHIN GROUP`, además de `AVG()` y `ROUND()` para formateo.

3. Lista compras por cliente con gasto total y un ranking global de gasto empleando funciones de ventana (`RANK() OVER (ORDER BY SUM(...) DESC)`), concatenación de texto y `COUNT(DISTINCT ...)`.

4. Calcula por día el número de compras, ticket promedio y total, usando un `CTE (WITH) o (Common Table Expression)“subconsulta con nombre”`, conversión de `fecha ::date`, y agregaciones (`COUNT, AVG, SUM`) con `ORDER BY`.

5. Realiza una búsqueda estilo e-commerce de productos activos y con stock cuyo nombre empiece por “caf”, usando filtros en `WHERE`, comparación numérica y búsqueda case-insensitive con `ILIKE 'caf%'`.

6. Devuelve los productos con el precio formateado como texto monetario usando concatenación `('||')` y `TO_CHAR(numeric, 'FM999G999G999D00')`, ordenando de mayor a menor precio.

   El modelo `'FM999G999G999D00'` se descompone así:

   - `FM`: “Fill Mode”. Quita espacios de relleno a la izquierda/derecha.
   - `9`: dígito opcional. Se muestran tantos como existan; si faltan, no se rellenan con ceros.
   - `0`: dígito obligatorio. Aquí `00` fuerza siempre dos decimales.
   - `G`: separador de miles según la configuración regional (p. ej., `,` en `en_US`, `.` en `es_CO`).
   - `D`: separador decimal según la configuración regional (p. ej., `.` en `en_US`, `,` en `es_CO`).

   Ejemplos

   - Con `lc_numeric = 'en_US'`: `to_char(1234567.5, 'FM999G999G999D00')` → `1,234,567.50`
   - Con `lc_numeric = 'es_CO'`: `to_char(1234567.5, 'FM999G999G999D00')` → `1.234.567,50`

7. Arma el “resumen de canasta” por compra: subtotal, `IVA al 19%` y total con IVA, mediante `SUM()` y `ROUND()` sobre el total por ítem, agrupado por compra.

8. Calcula la participación (%) de cada categoría en las ventas usando agregaciones por categoría y una ventana sobre el total (`SUM(SUM(total)) OVER ()`), más `ROUND()` para el porcentaje.

9. Clasifica el nivel de stock de productos activos (`CRÍTICO/BAJO/OK`) usando `CASE` sobre el campo `cantidad_stock` y ordena por el stock ascendente.

10. Obtén la última compra por cliente utilizando`DISTINCT ON (id_cliente)` combinado con `ORDER BY ... fecha DESC` y una agregación del total de la compra.

11. Devuelve los 2 productos más vendidos por categoría usando una subconsulta con `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY SUM(...) DESC)` y luego filtrando `ROW_NUMBER` <= 2.

12. Calcula ventas mensuales: agrupa por mes truncando la fecha con `DATE_TRUNC('month', fecha)`, cuenta compras distintas (`COUNT(DISTINCT ...)`) y suma ventas, ordenando cronológicamente.

13. Lista productos que nunca se han vendido mediante un anti-join con `NOT EXISTS`, comparando por id_producto.

    `WHERE  NOT EXISTS (
      SELECT *
      FROM   ..
      WHERE  ..
    );`

14. Identifica clientes que, al comprar “café”, también compran “pan” en la misma compra, usando un filtro con `ILIKE` y una subconsulta correlacionada con `EXISTS`.

    `WHERE ...  EXISTS (
      SELECT *
      FROM   ..
      WHERE  ..
    );`

15. Estima el margen porcentual “simulado” de un producto aplicando operadores aritméticos sobre precio_venta y formateo con `ROUND()` a un decimal.

16. Filtra clientes de un dominio dado usando expresiones regulares con el operador `~*` (case-insensitive) y limpieza con `TRIM()` sobre el correo electrónico.

17. Normaliza nombres y apellidos de clientes con `TRIM()` e `INITCAP()` para capitalizar, retornando columnas formateadas.

18. Selecciona los productos cuyo `id_producto` es par usando el operador módulo `%` en la cláusula `WHERE`.

19. Crea una vista ventas_por_compra que consolide `id_compra`,` id_cliente`, `fecha` y el `SUM(total)` por compra, usando `CREATE OR REPLACE VIEW` y `JOIN ... USING`.

20. Crea una vista materializada mensual mv_ventas_mensuales que agregue ventas por `DATE_TRUNC('month', fecha);` recuerda refrescarla con `REFRESH MATERIALIZED VIEW` cuando corresponda.

21. Realiza un “UPSERT” de un producto referenciado por codigo_barras usando `INSERT ... ON CONFLICT (...) DO UPDATE`, actualizando nombre y precio_venta cuando exista conflicto.

22. Recalcula el stock descontando lo vendido a partir de un `UPDATE ... FROM (SELECT ... GROUP BY ...)`, empleando `COALESCE()` y `GREATEST()` para evitar negativos.

23. Implementa una función PL/pgSQL (`miscompras.fn_total_compra`) que reciba `p_id_compra` y retorne el `total` con `COALESCE(SUM(...), 0);` define el tipo de retorno `NUMERIC(16,2)`.

24. Define un trigger `AFTER INSERT` sobre `compras_productos` que descuente stock mediante una función `RETURNS TRIGGER` y el uso del registro `NEW`, protegiendo con `GREATEST()` para no quedar bajo cero.

25. Asigna la “posición por precio” de cada producto dentro de su categoría con `DENSE_RANK() OVER (PARTITION BY ... ORDER BY precio_venta DESC)` y presenta el ranking.

26. Para cada cliente, muestra su gasto por compra, el gasto anterior y el delta entre compras usando `LAG(...) OVER (PARTITION BY id_cliente ORDER BY dia)` dentro de un `CTE` que agrega por día.

## Solución Diseño

```sql
-- Opcional: crea y usa el esquema
DROP SCHEMA IF EXISTS miscompras CASCADE;
CREATE SCHEMA IF NOT EXISTS miscompras;
SET search_path TO miscompras;

CREATE TABLE miscompras.clientes (
    id                 VARCHAR(20)  PRIMARY KEY,
    nombre             VARCHAR(40)  NOT NULL,
    apellidos          VARCHAR(100) NOT NULL,
    celular            NUMERIC(10,0),
    direccion          VARCHAR(80),
    correo_electronico VARCHAR(70)
);

CREATE TABLE miscompras.categorias (
    id_categoria  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descripcion   VARCHAR(45) NOT NULL,
    estado        SMALLINT     NOT NULL DEFAULT 1,
    CONSTRAINT categorias_estado_chk CHECK (estado IN (0,1))
);

CREATE TABLE miscompras.productos (
    id_producto    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         VARCHAR(45)   NOT NULL,
    id_categoria   INT           NOT NULL,
    codigo_barras  VARCHAR(150),
    precio_venta   NUMERIC(16,2) NOT NULL,
    cantidad_stock INT           NOT NULL DEFAULT 0,
    estado         SMALLINT      NOT NULL DEFAULT 1,
    CONSTRAINT productos_precio_chk   CHECK (precio_venta >= 0),
    CONSTRAINT productos_stock_chk    CHECK (cantidad_stock >= 0),
    CONSTRAINT productos_estado_chk   CHECK (estado IN (0,1)),
    CONSTRAINT productos_fk_categoria FOREIGN KEY (id_categoria)
        REFERENCES miscompras.categorias(id_categoria)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Unico por código de barras si se usa, permite varios NULL
CREATE UNIQUE INDEX IF NOT EXISTS ux_productos_codigo_barras
    ON miscompras.productos (codigo_barras)
    WHERE codigo_barras IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_productos_id_categoria
    ON miscompras.productos (id_categoria);


CREATE TABLE miscompras.compras (
    id_compra    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente   VARCHAR(20)  NOT NULL,
    fecha        TIMESTAMP    NOT NULL DEFAULT NOW(),
    medio_pago   CHAR(1)      NOT NULL,
    comentario   VARCHAR(300),
    estado       CHAR(1)      NOT NULL,
    CONSTRAINT compras_fk_cliente FOREIGN KEY (id_cliente)
        REFERENCES miscompras.clientes(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Indice para busquedas por cliente
CREATE INDEX IF NOT EXISTS idx_compras_id_cliente
    ON miscompras.compras (id_cliente);

CREATE TABLE miscompras.compras_productos (
    id_compra    INT           NOT NULL,
    id_producto  INT           NOT NULL,
    cantidad     INT           NOT NULL,
    total        NUMERIC(16,2) NOT NULL,
    estado       SMALLINT      NOT NULL DEFAULT 1,
    CONSTRAINT compras_productos_pk PRIMARY KEY (id_compra, id_producto),
    CONSTRAINT compras_productos_cantidad_chk CHECK (cantidad > 0),
    CONSTRAINT compras_productos_total_chk    CHECK (total >= 0),
    CONSTRAINT compras_productos_estado_chk   CHECK (estado IN (0,1)),
    CONSTRAINT compras_productos_fk_compra FOREIGN KEY (id_compra)
        REFERENCES miscompras.compras(id_compra)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT compras_productos_fk_producto FOREIGN KEY (id_producto)
        REFERENCES miscompras.productos(id_producto)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

-- Indice adicional para acelerar consultas por producto
CREATE INDEX IF NOT EXISTS idx_cp_id_producto
    ON miscompras.compras_productos (id_producto);

```