-- Create schema for dimensional model
CREATE SCHEMA dw;

-- Dimension tables
CREATE TABLE dw.dim_date (
    date_key SERIAL PRIMARY KEY,
    year VARCHAR(4) NOT NULL,
    month VARCHAR(2) NOT NULL,
    day VARCHAR(2) NOT NULL,
    hour VARCHAR(2) NOT NULL,
    UNIQUE(year, month, day, hour)   -- Ensures no duplicate time periods during inserts
);

-- Fact table
CREATE TABLE dw.fact_mediciones (
    medicion_key SERIAL PRIMARY KEY,
    date_key INT NOT NULL REFERENCES dw.dim_date(date_key),
    latitud NUMERIC NOT NULL,
    longitud NUMERIC NOT NULL,
    pm10 NUMERIC,
    pm2_5 NUMERIC,
    no2 NUMERIC
);

-- Create indexes for better query performance
CREATE INDEX idx_fact_mediciones_date ON dw.fact_mediciones(date_key);
-- Opcional: Índice espacial/coordenadas por si haces mapas en Superset
CREATE INDEX idx_fact_mediciones_location ON dw.fact_mediciones(latitud, longitud);