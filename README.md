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
  **PostgreSQL** como base de datos relacional analítica (Data Warehouse).
- **Apache Superset** para la visualización de datos y creación de dashboards.
- **Jupyter Notebook + DuckDB / Pandas** para el entorno analítico final.

---

### Arquitectura
La arquitectura implementada sigue el siguiente flujo:

```text
Fuentes de datos (APIs) → n8n (Productor) → RabbitMQ → n8n (Consumidor) → MinIO (Zonas) & PostgreSQL (Tablas Hechos/Dimensiones) → Apache Superset (BI)
```

Toda la infraestructura está desplegada en contenedores Docker aislados que se comunican a través de una red virtual.

---

### Componentes y rol
  Hemos divido la carga de trabajo en cuatro workflows distintos. Un par para cada API. Uno encargado de extraer los datos originales y enviarlos tanto a RabbitMQ como a la Zona Raw del Data Lake; el otro para leer a partir de la cola de RabbitMQ el mensaje que incluye los datos (content), procesar dichos datos y diferenciar sus procesos de transformación para enviar en un rama un fichero a la Zona Cleaned y, en otra rama, un fichero a la Zona Processed.

Para cumplir con los requisitos, hemos utilizado los siguientes componentes (en este caso, lo explicamos para la API de Open-Meteo, pero el proceso es el mismo para ambas fuentes de datos):

1. Workflow productor (n8n)
  - Se ejecuta de forma periódica.
  - Realiza peticiones HTTP a una API y extrae los datos del día anterior al momento de ejecución.
  - Envía los datos originales a MinIO (raw-data).
  - Publica cada paquete de datos como un mensaje en la cola de RabbitMQ.

<br>

2. RabbitMQ
  - Actúa como intermediario (broker), desacoplando la fase de ingesta (rápida) de la fase de procesamiento (más lenta y pesada).

<br>

3. Workflow consumidor (n8n):
  -  Escucha la cola de RabbitMQ.
  -  Parsea el contenido JSON.
  -  Aplica lógica de negocio (ej. limpieza de nulos, selección de variables).
  -  Envía los datos procesados a MinIO creando versiones transformadas.

<br>

4. PostgreSQL & Apache Superset (capa analítica)
  - PostgreSQL: actúa como un Data Warehouse en esquema de estrella. Almacena las tablas de hechos (mediciones)
    y dimensiones (tiempo, geografía) preparadas para joins analíticos.
  - Apache Superset: se conecta a PostgreSQL para generar paneles visuales en tiempo real,
    incluyendo mapas de calor con las coordenadas de las estaciones y series temporales de la evolución del aire cruzadas con el clima.

---

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

- Sobrecarga de memoria en n8n (OOM): inicialmente intentamos ingestar el dataset histórico de calidad del aire del Ayuntamiento de Madrid, el cual contenía más de 58.000 filas. Esto provocaba el colapso del contenedor de   n8n por falta de memoria RAM al intentar mapear los JSONs. Solución: cambiamos la fuente de datos al CSV de tiempo real (que contiene sólo la fotografía del momento). Utilizamos nodos Code de JavaScript para emular        mediante bucles el comportamiento Batch de 24 horas, rellenando huecos vacíos y procesando la información de forma ligera enviando 24 mensajes atómicos a RabbitMQ sin saturar la memoria.

- Desincronización temporal entre fuentes: nos dimos cuenta de que la API de Open-Meteo pedía parámetros históricos (ej: el día de ayer), pero el archivo del Ayuntamiento de Madrid es un CSV
  estático que se sobrescribe con el día actual. Esto generaba que al cruzar los datos en Superset, el clima y la contaminación no coincidieran en el mismo date_key. Solución: aplicamos un ajuste
  temporal dinámico mediante JavaScript en el workflow de ingesta de Madrid. Le restamos un día exacto (UTC) al timestamp original extraído del CSV antes de mandarlo a la cola, alineando ambos
  datasets de forma artificial pero analíticamente consistente para el ejercicio.
  
---

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
- Apache Superset: `http://localhost:8088`

Credenciales por defecto:
- RabbitMQ: user: `guest` | password: `guest`
- MinIO: user: `minio` | password: `minio123`
- Superset: user: admin | password: admin

---

### Configuración manual requerida

Antes de activar los flujos, realiza estos pasos:

1. Credenciales S3 en n8n:
  - Endpoint: `http://minio:9000`
  - Access/Secret Key: `minio` / `minio123`
  - Force Path Style: `Enabled`

2. Conexión de Apache Superset a PostgreSQL:
  - En el panel de Superset, añade una nueva base de datos.
  - Nombre de la conexión: `retail_dw`
  - User/Password: `dwuser` / `dwpassword`
  - Nombre base de datos: `retail_dw`

3. Colas en RabbitMQ:
  - Crear manualmente las colas especificadas en los nodos de RabbitMQ de n8n para evitar errores de conexión inicial.








