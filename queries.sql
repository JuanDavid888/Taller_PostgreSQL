
-- 1. Obtén el “Top 10” de productos por unidades vendidas y su ingreso total

SELECT p.nombre,
    COUNT(cp.cantidad) AS cantidad,
    SUM(cp.total) AS total
FROM miscompras.productos p
JOIN miscompras.compras_productos cp USING(id_producto)
GROUP BY p.id_producto
ORDER BY cantidad DESC
LIMIT 10;

-- 2. Calcula el total pagado promedio por compra y la mediana aproximada

SELECT 
    ROUND(AVG(t.total), 2) AS promedio_compra,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY t.total) AS mediana
FROM (
    SELECT c.id_compra, SUM(cp.total) AS total
    FROM miscompras.compras c
    JOIN miscompras.compras_productos cp USING(id_compra)
    GROUP BY c.id_compra
) t;

-- 3. Lista compras por cliente con gasto total y un ranking global de gasto

SELECT cl.id, cl.nombre || ' ' || cl.apellidos AS cliente,
    COUNT(DISTINCT c.id_compra) AS compras,
    SUM(cp.total) AS gasto_total,
    RANK() OVER(ORDER BY SUM(cp.total) DESC) AS ranking_gasto
FROM miscompras.clientes cl
JOIN miscompras.compras c ON cl.id = c.id_cliente
JOIN miscompras.compras_productos cp USING(id_compra)
GROUP BY cl.id, cliente
ORDER BY ranking_gasto;

-- 4. Calcula por día el número de compras, ticket promedio y total

WITH t AS (
    SELECT
        c.fecha::date AS dia,
        c.id_compra,
        SUM(cp.total) AS total_compra
    FROM miscompras.compras c
    JOIN miscompras.compras_productos cp USING(id_compra)
    WHERE cp.estado = 1
    GROUP BY c.fecha::date, c.id_compra
)
SELECT dia,
    COUNT(id_compra) AS numero_compras,
    ROUND(AVG(total_compra), 2) AS ticket_promedio,
    SUM(total_compra) AS total_dia
FROM t
GROUP BY dia
ORDER BY dia;

-- 5. Realiza una búsqueda estilo e-commerce de productos activos y con stock cuyo nombre empiece por “caf”

SELECT nombre AS producto,
    cantidad_stock AS stock
FROM miscompras.productos
WHERE estado = 1
    AND cantidad_stock > 0
    AND nombre ILIKE 'caf%';

-- 6. Devuelve los productos con el precio formateado como texto monetario usando concatenación `('||')` y `TO_CHAR(numeric, 'FM999G999G999D00')`, ordenando de mayor a menor precio.

SELECT nombre,
    '$' || TO_CHAR(precio_venta, 'FM999G999G999D00') AS precio
FROM miscompras.productos
ORDER BY precio_venta DESC;

-- 7. Arma el “resumen de canasta” por compra: subtotal, `IVA al 19%` y total con IVA

SELECT 
    id_compra,
    SUM(total) AS subtotal,
    ROUND(SUM(total) * 0.19, 2) AS iva_19,
    ROUND(SUM(total) * 1.19, 2) AS total
FROM miscompras.compras_productos
WHERE estado = 1
GROUP BY id_compra
ORDER BY id_compra;

-- Calcula la participación (%) de cada categoría en las ventas

SELECT *
FROM miscompras.productos;

SELECT 
    ca.descripcion,
    ROUND(SUM(cp.total) * 100.0 / SUM(SUM(cp.total)) OVER(), 2)  AS porcentaje_participacion
FROM miscompras.categorias ca
JOIN miscompras.productos p USING(id_categoria)
JOIN miscompras.compras_productos cp USING(id_producto)
WHERE cp.estado = 1
GROUP BY ca.id_categoria, ca.descripcion
ORDER BY porcentaje_participacion DESC;

-- Clasifica el nivel de stock de productos activos (`CRÍTICO/BAJO/OK`)

SELECT nombre AS producto,
    CASE
        WHEN cantidad_stock <= 150 THEN 'CRÍTICO'
        WHEN cantidad_stock <= 350 THEN 'BAJO'
        ELSE 'OK'
    END AS nivel_stock
FROM miscompras.productos
WHERE estado = 1
ORDER BY cantidad_stock ASC

-- Obtén la última compra por cliente
SELECT DISTINCT ON (c.id_cliente)
    cl.nombre || ' ' || cl.apellidos AS nombre,
    c.fecha AS ultima_compra
FROM miscompras.clientes cl
JOIN compras c ON c.id_cliente = cl.id
JOIN compras_productos cp ON cp.id_compra = c.id_compra
WHERE cp.estado = 1;

SELECT * FROM compras

SELECT * FROM clientes