-- 1. Crear esquema para el modelo dimensional
CREATE SCHEMA dw;

-- 2. Tablas de dimensiones
CREATE TABLE dw.dim_date (
    date_key SERIAL PRIMARY KEY,
    year VARCHAR(4) NOT NULL,
    month VARCHAR(2) NOT NULL,
    day VARCHAR(2) NOT NULL,
    hour VARCHAR(2) NOT NULL,
    UNIQUE(year, month, day, hour)   -- Asegura que no haya periodos de tiempo duplicados durante las inserciones
);

-- 3. Tabla de hechos
CREATE TABLE dw.fact_mediciones (
    medicion_key SERIAL PRIMARY KEY,
    date_key INT NOT NULL REFERENCES dw.dim_date(date_key),
    latitud NUMERIC NOT NULL,
    longitud NUMERIC NOT NULL,
    pm10 NUMERIC,
    pm2_5 NUMERIC,
    no2 NUMERIC
);

-- 4. Crear índices para mejorar el rendimiento de las consultas
CREATE INDEX idx_fact_mediciones_date ON dw.fact_mediciones(date_key);
-- Opcional: índice espacial/de coordenadas para hacer mapas en Superset
CREATE INDEX idx_fact_mediciones_location ON dw.fact_mediciones(latitud, longitud);