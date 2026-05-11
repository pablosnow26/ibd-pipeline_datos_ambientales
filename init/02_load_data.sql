-- 1. Crear una tabla temporal idéntica a las columnas del CSV
CREATE TEMP TABLE staging_mediciones (
    pm10 NUMERIC,
    pm2_5 NUMERIC,
    no2 NUMERIC,
    latitud NUMERIC,
    longitud NUMERIC,
    year VARCHAR(4),
    month VARCHAR(2),
    day VARCHAR(2),
    hour VARCHAR(2)
);

-- 2. Cargar el archivo CSV en la tabla temporal
COPY staging_mediciones 
FROM "/datos_csv/2024_05_08.csv"
WITH (FORMAT csv, HEADER true, DELIMITER ",");

-- 3. Poblar la Dimensión de Fechas (dim_date)
-- Extraemos las combinaciones únicas de tiempo del CSV
INSERT INTO dw.dim_date (year, month, day, hour)
SELECT DISTINCT year, month, day, hour
FROM staging_mediciones
ON CONFLICT (year, month, day, hour) DO NOTHING;

-- 4. Poblar la Tabla de Hechos (fact_mediciones)
-- Cruzamos la tabla temporal con dim_date para obtener el date_key correspondiente
INSERT INTO dw.fact_mediciones (pm10, pm2_5, no2, latitud, longitud, date_key)
SELECT 
    s.pm10,
    s.pm2_5,
    s.no2,
    s.latitud,
    s.longitud,
    d.date_key
FROM staging_mediciones s
JOIN dw.dim_date d 
  ON s.year = d.year 
 AND s.month = d.month 
 AND s.day = d.day 
 AND s.hour = d.hour;

-- Al usar CREATE TEMP TABLE, PostgreSQL la eliminará automáticamente
-- en cuanto termine de ejecutar este script de inicialización.
