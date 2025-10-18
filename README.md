# Parametrización EMK - JBE

Este repositorio contiene la configuración y personalización del sistema EMK para JBE.

## Estructura del Proyecto

```
parametrizacion_emaku_jbe/
├── transacciones/       # Definiciones de formularios (XML)
├── sentencias_sql/      # Consultas SQL
├── templates/           # Plantillas
├── database/            # Configuración de base de datos
│   ├── migrations/      # Migraciones de esquema
│   └── seeds/           # Datos iniciales
├── resources/           # Recursos
│   ├── jar_files/       # Bibliotecas Java
│   ├── server_side/     # Scripts del lado del servidor
│   └── icons/           # Íconos de la aplicación
├── docs/                # Documentación adicional
└── .github/workflows/   # Flujos de trabajo de GitHub Actions
```

## Requisitos

- PostgreSQL
- Java (versión compatible con EMK)
- Cliente Git

## Configuración Inicial

1. Clonar el repositorio
2. Configurar la base de datos
3. Importar las transacciones y sentencias SQL

## Guía de Contribución

1. Crear una rama para cada nueva característica
2. Usar mensajes de commit descriptivos
3. Hacer pull request a la rama principal
