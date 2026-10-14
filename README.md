```markdown
# Gastrobar - Sistema Hibrido Relacional-Vectorial para RAG

Instrucciones para la configuracion y ejecucion del entorno de base de datos relacional y vectorial utilizando Docker.

## Requisitos previos

* Git
* Docker Desktop (con Docker Compose)

## Estructura del repositorio

```text
.
├── docker-compose.yml
├── README.md
└── sql/
    └── schema.sql

```

## Instrucciones de ejecucion

1. Clonar el repositorio:
    bash
git clone <URL_DEL_REPOSITORIO>
cd <NOMBRE_DEL_REPOSITORIO>



2. Iniciar el servicio con Docker Compose:
bash
docker compose up -d



3. Verificar que el contenedor esté en ejecucion:
bash
docker ps




## Datos de conexion a PostgreSQL

* Host: localhost
* Puerto: 5432
* Base de datos: gastrobar_db
* Usuario: gastrobar_user
* Contrasena: gastrobar_password

## Comandos utiles

* Detener el servicio:
bash
docker compose stop



* Reiniciar y reconstruir la base de datos desde cero:
bash
docker compose down -v
docker compose up -d



* Ver registros del contenedor:
    bash
docker compose logs -f
