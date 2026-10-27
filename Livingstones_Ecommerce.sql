/* =====================================================================
   Livingstones_Ecommerce - Modelo estrella (SQL Server)
   Origen : dbo.stg_orders  (todo texto, tal cual el CSV)
   Destino: dbo.dim_* y dbo.fact_orders (tipados, con PK, FK y CHECK)
   Orden  : 0 reinicio -> 1 dimensiones -> 2 fact -> 3 carga -> 4 validacion
   ===================================================================== */
USE Livingstones_Ecommerce;
GO

/* ---------------------------------------------------------------------
   0. REINICIO (solo para poder volver a correr el script)
   Se borra en orden INVERSO: primero la fact (depende de las dimensiones)
   y despues las dimensiones. stg.orders NO se toca.
   --------------------------------------------------------------------- */
DROP TABLE IF EXISTS dbo.fact_orders;
DROP TABLE IF EXISTS dbo.dim_date;
DROP TABLE IF EXISTS dbo.dim_customer;
DROP TABLE IF EXISTS dbo.dim_payment_method;
DROP TABLE IF EXISTS dbo.dim_region;
DROP TABLE IF EXISTS dbo.dim_category;
GO

/* ---------------------------------------------------------------------
   1. DIMENSIONES (no dependen de nadie, van primero)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.dim_category (
    category_id   INT          NOT NULL,
    category_name NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_dim_category      PRIMARY KEY (category_id),
    CONSTRAINT UQ_dim_category_name UNIQUE (category_name)
);

CREATE TABLE dbo.dim_region (
    region_id   INT          NOT NULL,
    region_name NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_dim_region      PRIMARY KEY (region_id),
    CONSTRAINT UQ_dim_region_name UNIQUE (region_name)
);

CREATE TABLE dbo.dim_payment_method (
    payment_method_id   INT          NOT NULL,
    payment_method_name NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_dim_payment_method      PRIMARY KEY (payment_method_id),
    CONSTRAINT UQ_dim_payment_method_name UNIQUE (payment_method_name)
);

CREATE TABLE dbo.dim_customer (
    customer_id INT NOT NULL,
    CONSTRAINT PK_dim_customer PRIMARY KEY (customer_id)
);

CREATE TABLE dbo.dim_date (
    order_date   DATE         NOT NULL,
    [year]       SMALLINT     NOT NULL,
    month_number TINYINT      NOT NULL,
    month_name   NVARCHAR(20) NOT NULL,
    [quarter]    TINYINT      NOT NULL,
    day_name     NVARCHAR(20) NOT NULL,
    CONSTRAINT PK_dim_date PRIMARY KEY (order_date)
);
GO

/* ---------------------------------------------------------------------
   2. TABLA DE HECHOS (va despues: sus FK apuntan a las dimensiones)
   --------------------------------------------------------------------- */
CREATE TABLE dbo.fact_orders (
    order_id          INT           NOT NULL,
    order_date        DATE          NOT NULL,
    customer_id       INT           NOT NULL,
    category_id       INT           NOT NULL,
    region_id         INT           NOT NULL,
    payment_method_id INT           NOT NULL,
    quantity          INT           NOT NULL,
    unit_price        DECIMAL(10,2) NOT NULL,
    discount          DECIMAL(4,2)  NOT NULL,
    delivery_days     INT           NOT NULL,
    customer_rating   DECIMAL(2,1)  NOT NULL,
    revenue           DECIMAL(10,2) NOT NULL,

    CONSTRAINT PK_fact_orders PRIMARY KEY (order_id),

    CONSTRAINT FK_fact_date     FOREIGN KEY (order_date)        REFERENCES dbo.dim_date (order_date),
    CONSTRAINT FK_fact_customer FOREIGN KEY (customer_id)       REFERENCES dbo.dim_customer (customer_id),
    CONSTRAINT FK_fact_category FOREIGN KEY (category_id)       REFERENCES dbo.dim_category (category_id),
    CONSTRAINT FK_fact_region   FOREIGN KEY (region_id)         REFERENCES dbo.dim_region (region_id),
    CONSTRAINT FK_fact_payment  FOREIGN KEY (payment_method_id) REFERENCES dbo.dim_payment_method (payment_method_id),

    CONSTRAINT CK_fact_quantity CHECK (quantity > 0),
    CONSTRAINT CK_fact_discount CHECK (discount BETWEEN 0 AND 1),
    CONSTRAINT CK_fact_delivery CHECK (delivery_days >= 0),
    CONSTRAINT CK_fact_rating   CHECK (customer_rating BETWEEN 1 AND 5),
    CONSTRAINT CK_fact_revenue  CHECK (revenue >= 0)
);
GO

/* ---------------------------------------------------------------------
   3. CARGA (mismo orden: dimensiones primero, fact al final)
   --------------------------------------------------------------------- */

-- 3.1 Dimensiones con clave sustituta: ROW_NUMBER numera los valores unicos
INSERT INTO dbo.dim_category (category_id, category_name)
SELECT ROW_NUMBER() OVER (ORDER BY product_category), product_category
FROM (SELECT DISTINCT product_category FROM dbo.stg_orders) AS x;

INSERT INTO dbo.dim_region (region_id, region_name)
SELECT ROW_NUMBER() OVER (ORDER BY region), region
FROM (SELECT DISTINCT region FROM dbo.stg_orders) AS x;

INSERT INTO dbo.dim_payment_method (payment_method_id, payment_method_name)
SELECT ROW_NUMBER() OVER (ORDER BY payment_method), payment_method
FROM (SELECT DISTINCT payment_method FROM dbo.stg_orders) AS x;

-- 3.2 Clientes: el customer_id original ya es el codigo
INSERT INTO dbo.dim_customer (customer_id)
SELECT DISTINCT CAST(customer_id AS INT)
FROM dbo.stg_orders;

-- 3.3 Calendario: fecha convertida de texto dia/mes/anio (estilo 103)
--     SET LANGUAGE hace que DATENAME devuelva nombres en espanol
SET LANGUAGE Spanish;

INSERT INTO dbo.dim_date (order_date, [year], month_number, month_name, [quarter], day_name)
SELECT d,
       YEAR(d),
       MONTH(d),
       DATENAME(MONTH, d),
       DATEPART(QUARTER, d),
       DATENAME(WEEKDAY, d)
FROM (SELECT DISTINCT TRY_CONVERT(date, order_date, 103) AS d
      FROM dbo.stg_orders) AS x;

-- 3.4 Fact: convierte tipos y cambia el texto por los codigos (LEFT JOIN:
--     si algun valor no matchea, el codigo queda NULL y NOT NULL frena todo)
INSERT INTO dbo.fact_orders
    (order_id, order_date, customer_id, category_id, region_id, payment_method_id,
     quantity, unit_price, discount, delivery_days, customer_rating, revenue)
SELECT CAST(o.order_id AS INT),
       TRY_CONVERT(date, o.order_date, 103),
       CAST(o.customer_id AS INT),
       c.category_id,
       r.region_id,
       p.payment_method_id,
       CAST(o.quantity AS INT),
       TRY_CONVERT(DECIMAL(10,2), o.unit_price),
       TRY_CONVERT(DECIMAL(4,2),  o.discount),
       CAST(o.delivery_days AS INT),
       TRY_CONVERT(DECIMAL(2,1),  o.customer_rating),
       TRY_CONVERT(DECIMAL(10,2), o.revenue)
FROM dbo.stg_orders AS o
LEFT JOIN dbo.dim_category        AS c ON c.category_name        = o.product_category
LEFT JOIN dbo.dim_region          AS r ON r.region_name          = o.region
LEFT JOIN dbo.dim_payment_method AS p ON p.payment_method_name = o.payment_method;
GO

/* ---------------------------------------------------------------------
   4. VALIDACION (comparar con los valores esperados)
   --------------------------------------------------------------------- */

-- 4.1 Filas por tabla. Esperado: fact 5000, customer 989, category 4,
--     region 4, payment 3, date 5000
SELECT 'fact_orders' AS tabla, COUNT(*) AS filas FROM dbo.fact_orders
UNION ALL SELECT 'dim_customer',       COUNT(*) FROM dbo.dim_customer
UNION ALL SELECT 'dim_category',       COUNT(*) FROM dbo.dim_category
UNION ALL SELECT 'dim_region',         COUNT(*) FROM dbo.dim_region
UNION ALL SELECT 'dim_payment_method', COUNT(*) FROM dbo.dim_payment_method
UNION ALL SELECT 'dim_date',           COUNT(*) FROM dbo.dim_date;

-- 4.2 Totales de control.
--     Esperado: revenue 5109775.74 | quantity 20224 | unit_price 1542093.87
--               fechas 2022-01-01 a 2035-09-09
SELECT SUM(revenue)    AS sum_revenue,
       SUM(quantity)   AS sum_quantity,
       SUM(unit_price) AS sum_unit_price,
       MIN(order_date) AS fecha_min,
       MAX(order_date) AS fecha_max
FROM dbo.fact_orders;

-- 4.3 Revenue por categoria.
--     Esperado: Beauty 765860.88 | Clothing 1531931.72
--               Electronics 1829899.22 | Home 982083.92
SELECT c.category_name, SUM(f.revenue) AS revenue
FROM dbo.fact_orders AS f
JOIN dbo.dim_category AS c ON c.category_id = f.category_id
GROUP BY c.category_name
ORDER BY c.category_name;

-- 4.4 Revenue recalculado. Esperado: 0 filas con diferencia
SELECT COUNT(*) AS filas_con_diferencia
FROM dbo.fact_orders
WHERE ABS(revenue - ROUND(quantity * unit_price * (1 - discount), 2)) > 0.01;

-- 4.5 Calendario sin huecos. Esperado: dias = dias_esperados (5000)
SELECT COUNT(*) AS dias,
       DATEDIFF(DAY, MIN(order_date), MAX(order_date)) + 1 AS dias_esperados
FROM dbo.dim_date;

-- 4.6 stg vs fact. Esperado: 5000 y 5000
SELECT (SELECT COUNT(*) FROM dbo.stg_orders)   AS filas_stg,
       (SELECT COUNT(*) FROM dbo.fact_orders)  AS filas_fact;

SELECT TABLE_SCHEMA, TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES;