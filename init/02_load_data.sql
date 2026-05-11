-- 1. Creamos una tabla temporal que aguante las 56 columnas del CSV de Madrid
CREATE TEMP TABLE staging_madrid (
    provincia TEXT, municipio TEXT, estacion TEXT, magnitud TEXT, punto_muestreo TEXT, 
    ano TEXT, mes TEXT, dia TEXT,
    h01 TEXT, v01 TEXT, h02 TEXT, v02 TEXT, h03 TEXT, v03 TEXT, h04 TEXT, v04 TEXT, h05 TEXT, v05 TEXT,
    h06 TEXT, v06 TEXT, h07 TEXT, v07 TEXT, h08 TEXT, v08 TEXT, h09 TEXT, v09 TEXT, h10 TEXT, v10 TEXT,
    h11 TEXT, v11 TEXT, h12 TEXT, v12 TEXT, h13 TEXT, v13 TEXT, h14 TEXT, v14 TEXT, h15 TEXT, v15 TEXT,
    h16 TEXT, v16 TEXT, h17 TEXT, v17 TEXT, h18 TEXT, v18 TEXT, h19 TEXT, v19 TEXT, h20 TEXT, v20 TEXT,
    h21 TEXT, v21 TEXT, h22 TEXT, v22 TEXT, h23 TEXT, v23 TEXT, h24 TEXT, v24 TEXT
);

-- 2. Cargamos el CSV (Usando el delimitador ";" que es el que usa Madrid)
COPY staging_madrid 
FROM '/datos_csv/2026_05_08.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ';');

-- 3. Poblamos la dimensión de tiempo (un registro por cada día/hora del archivo)
INSERT INTO dw.dim_date (year, month, day, hour)
SELECT DISTINCT ano, mes, dia, '01' FROM staging_madrid
ON CONFLICT DO NOTHING;

-- 4. Poblamos la tabla de hechos (Ejemplo simplificado para NO2 - Magnitud 8)
INSERT INTO dw.fact_mediciones (no2, latitud, longitud, date_key)
SELECT 
    CAST(NULLIF(s.h01, '') AS NUMERIC), 
    40.4168, -3.7038, -- Coordenadas genéricas de Madrid (puedes ajustarlas)
    d.date_key
FROM staging_madrid s
JOIN dw.dim_date d ON s.ano = d.year AND s.mes = d.month AND s.dia = d.day
WHERE s.magnitud = '8'; -- Filtramos solo NO2 para este ejemplo
