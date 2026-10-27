# 📊 Livingstones Global — E-Commerce Analytics & BI

Solución integral de Inteligencia de Negocios desarrollada para **Livingstones Global (ONG)**, abarcando la auditoría en Excel, modelado relacional en SQL Server y visualización ejecutiva en Power BI.

---

## 📂 Archivos del Proyecto
* **`Livingstones_Ecommerce.sql`**: Script completo en SQL Server para la creación del Modelo en Estrella (`fact_orders` y dimensiones `dim_*`), ingesta de datos y validaciones de integridad (`CHECK`).
* **`Livingstones_Ecommerce.xlsx`**: Archivo de origen con auditoría de datos, validación de la fórmula de facturación y consultas de Power Query.
* **`Livingstones_Ecommerce.pbix`**: Dashboard interactivo estructurado en 4 páginas funcionales (*Portada*, *Comercial*, *Logística* y *Clientes*).

---

## 💡 Hallazgos Clave y Gobierno de Datos
* **Media vs. Mediana:** Se detectó que el *Ticket Promedio* ($1.021,96) estaba sesgado por compras grandes[cite: 10, 12]. Se estableció el *Ticket Mediano* ($796,65) como métrica central robusta para el segmento B2C masivo[cite: 10, 12].
* **Caza de Outliers:** Mediante un gráfico de caja (*Box Plot* con umbral `= 1.5 IQR`), se aislaron **73 pedidos atípicos** (compras corporativas/mayoristas de alto volumen) para ser gestionados de forma diferenciada[cite: 10, 12].

---

## 🚀 Cómo Visualizar el Proyecto
1. **SQL Server:** Ejecutá el script `Livingstones_Ecommerce.sql` en SQL Server Management Studio para recrear el modelo de datos local[cite: 9].
2. **Power BI:** Abrí el archivo `Livingstones_Ecommerce.pbix` en Power BI Desktop para interactuar libremente con los datos, filtros y páginas del tablero[cite: 11].
