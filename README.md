# practica2-ibd

## Pipeline de Datos Ambientales - Ayuntamiento de Madrid

### Descripción general
  Esta implementación, gracias a la utilización de diferentes tecnologías englobadas en un paradigma de almacenamiento como es un Data Lake, nos permite adquirir información 
de diferentes fuentes de datos heterogéneas y aunarlas en un entorno capaz de dar soporte a consultas que facilita la toma de decisiones del Ayuntamiento de Madrid en cuanto
al análisis de datos ambientales.

El pipeline utiliza:

- **Open-Meteo API** y el **Portal de Datos Abiertos de Madrid** como fuentes de datos.
- **RabbitMQ** como gestor de colas de mensajes (*message broker*).
- **n8n** para la orquestación de flujos de trabajo.
- **MinIO** como capa de almacenamiento del Data Lake.
- **Jupyter Notebook + DuckDB / Pandas** para el entorno analítico final.

### Arquitectura
La arquitectura implementada sigue el siguiente flujo:

```text
Fuentes de datos (APIs) → n8n (Productor) → RabbitMQ → n8n (Consumidor) → MinIO (Zonas) → Jupyter (Análisis)
```

Toda la infraestructura está desplegada en contenedores Docker aislados que se comunican a través de una red virtual.

### Componentes y rol
  Hemos divido la carga de trabajo en cuatro workflows distintos. Un par para cada API. Uno encargado de extraer los datos originales y enviarlos tanto a RabbitMQ como a la Zona Raw del Data Lake; el otro para leer a partir de la cola de RabbitMQ el mensaje que incluye los datos (content), procesar dichos datos y diferenciar sus procesos de transformación para enviar en un rama un fichero a la Zona Processed y, en otra rama, un fichero a la Zona Access.

Para cumplir con los requisitos, hemos utilizado los siguientes componentes (en este caso, lo explicamos para la API de Open-Meteo, pero el proceso es el mismo para ambas fuentes de datos):

1. Workflow productor (n8n)
  - Se ejecuta de forma periódica.
  - Realiza peticiones HTTP a Open-Meteo y extrae los datos del día anterior al momento de ejecución.
  - Envía los datos originales a MinIO (raw-data).
  - Publica cada paquete de datos como un mensaje en la cola de RabbitMQ.

<br>

2. RabbitMQ
  - Actúa como intermediario (broker), desacoplando la fase de ingesta (rápida) de la fase de procesamiento (más lenta y pesada).

<br>

3. Workflow consumidor (n8n):
  -  Escucha la cola de RabbitMQ.
  -  Parsea el contenido JSON y lo transforma a formato tabular.
  -  Aplica lógica de negocio (ej. limpieza de nulos, detección de alertas de contaminación cruzando umbrales de NO2/PM10).
  -  Enriquece los datos geográficos transformando coordenadas en nombres de Distritos.
  -  Envía los datos procesados a MinIO creando versiones transformadas.

<br>

4. MinIO (Data Lake)
  - Organiza los datos en buckets lógicos:
      - raw-data: datos crudos.
      - processed-data: CSVs detallados con las variables de calidad del aire.
      - access-zone: archivos optimizados y particionados, listos para consumo analítico.

### Desafíos técnicos y soluciones
Durante el desarrollo de la práctica, nos enfrentamos a varios retos de infraestructura.

- Conversión a Parquet en n8n: inicialmente quisimos generar archivos Parquet directamente en n8n usando nodos de código (Python/Pandas).
  Sin embargo, nos topamos con que las imágenes base recientes de n8n limitaban el uso de gestores de paquetes (apk o apt-get),
  haciendo inestable la construcción del contenedor mediante un Dockerfile personalizado. Solución: decidimos asegurar el flujo manteniendo el formato nativo
  CSV particionado, dejando la optimización analítica al motor de DuckDB, el cual procesa múltiples CSVs distribuidos a gran velocidad.

- Bloqueo de red en la descarga de extensiones (DuckDB): al levantar el contenedor de Jupyter e intentar ejecutar INSTALL httpfs;
  para conectar DuckDB con MinIO vía S3, recibimos un error HTTP 451 (Unavailable For Legal Reasons). El firewall de la red bloqueaba
  la descarga de binarios .gz desde contenedores Linux. Solución: trabajamos con una extensión de Windows de DuckDB en local, creando un notebook y conectándonos
  a MinIO desde ahí, consiguiendo leer los ficheros correctamente.

### Despliegue con Docker
Todos los servicios se despliegan utilizando docker-compose.

Iniciar el sistema:

```bash
docker compose up -d
```

Puntos de Acceso:
- n8n: `http://localhost:5678`
- RabbitMQ (UI): `http://localhost:15672`
- MinIO (Console): `http://localhost:9001`
- Jupyter Lab: `http://localhost:8888`

Credenciales por defecto:
- RabbitMQ: user: `guest` | password: `guest`
- MinIO: user: `minio` | password: `minio123`

Pasos de configuración manual → antes de activar los flujos de trabajo en n8n, es necesario realizar estos pasos manuales:

Añadir una nueva credencial de tipo S3 (MinIO) en n8n con los siguientes parámetros:
  - Endpoint: http://minio:9000 (Nota: usar el nombre del contenedor, no localhost).
  - Access Key: minio
  - Secret Key: minio123
  - Region: us-east-1
  - Force Path Style: enabled

Configuración de RabbtiMQ:
  - Crear dos colas, una para cada API.








