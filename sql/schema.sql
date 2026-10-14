-- ============================================================================
-- PROYECTO: Gastrobar - Sistema Híbrido Relacional-Vectorial para RAG
-- ARCHIVO: schema.sql
-- ENTORNO: PostgreSQL + pgvector
-- ============================================================================

-- Habilitar la extensión para soporte vectorial
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================================
-- 1. NÚCLEO Y RAG (TABLAS BASE)
-- ============================================================================

CREATE TABLE usuarios (
    id_usuario SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    rol VARCHAR(50) NOT NULL CHECK (rol IN ('administrador', 'cajero', 'mesero', 'barman', 'cliente_registrado', 'auditor'))
);

CREATE TABLE documentos (
    id_doc SERIAL PRIMARY KEY,
    titulo VARCHAR(200) NOT NULL,
    tipo_documento VARCHAR(50),
    fecha DATE DEFAULT CURRENT_DATE,
    fuente VARCHAR(255),
    contenido_texto TEXT NOT NULL
);

CREATE TABLE imagenes (
    id_img SERIAL PRIMARY KEY,
    id_doc INT REFERENCES documentos(id_doc) ON DELETE SET NULL,
    ruta_archivo VARCHAR(255) NOT NULL,
    descripcion TEXT
);

CREATE TABLE consultas (
    id_consulta SERIAL PRIMARY KEY,
    id_usuario INT NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    texto_pregunta TEXT NOT NULL,
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE resultados (
    id_resultado SERIAL PRIMARY KEY,
    id_consulta INT NOT NULL REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    id_doc INT REFERENCES documentos(id_doc) ON DELETE CASCADE,
    id_img INT REFERENCES imagenes(id_img) ON DELETE CASCADE,
    score_similitud NUMERIC(5,4) NOT NULL CHECK (score_similitud BETWEEN -1.0000 AND 1.0000),
    CONSTRAINT chk_resultado_fuente CHECK (
        (id_doc IS NOT NULL AND id_img IS NULL) OR 
        (id_doc IS NULL AND id_img IS NOT NULL)
    )
);

CREATE TABLE evaluaciones (
    id_eval SERIAL PRIMARY KEY,
    id_consulta INT UNIQUE NOT NULL REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    faithfulness NUMERIC(4,3) CHECK (faithfulness BETWEEN 0.000 AND 1.000),
    answer_relevancy NUMERIC(4,3) CHECK (answer_relevancy BETWEEN 0.000 AND 1.000),
    context_recall NUMERIC(4,3) CHECK (context_recall BETWEEN 0.000 AND 1.000),
    modelo_eval VARCHAR(100),
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- 2. DOMINIO GASTROBAR: PERSONAL Y CLIENTES
-- ============================================================================

CREATE TABLE empleado (
    id_empleado SERIAL PRIMARY KEY,
    tipo_documento VARCHAR(20) NOT NULL,
    numero_documento VARCHAR(50) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    telefono VARCHAR(30),
    cargo VARCHAR(50) NOT NULL,
    fecha_contratacion DATE NOT NULL DEFAULT CURRENT_DATE,
    salario_base NUMERIC(12,2) NOT NULL CHECK (salario_base >= 0),
    CONSTRAINT uq_empleado_doc UNIQUE (tipo_documento, numero_documento)
);

CREATE TABLE asistencia (
    id_asistencia SERIAL PRIMARY KEY,
    id_empleado INT NOT NULL REFERENCES empleado(id_empleado) ON DELETE CASCADE,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    hora_entrada TIME NOT NULL,
    hora_salida TIME
);

CREATE TABLE nomina (
    id_nomina SERIAL PRIMARY KEY,
    id_empleado INT NOT NULL REFERENCES empleado(id_empleado) ON DELETE CASCADE,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    salario_base NUMERIC(12,2) NOT NULL CHECK (salario_base >= 0),
    horas_trabajadas NUMERIC(6,2) NOT NULL DEFAULT 0 CHECK (horas_trabajadas >= 0),
    total_pagado NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total_pagado >= 0),
    CONSTRAINT uq_nomina_periodo UNIQUE (id_empleado, fecha_inicio, fecha_fin),
    CONSTRAINT chk_nomina_fechas CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE cliente (
    id_cliente SERIAL PRIMARY KEY,
    tipo_documento VARCHAR(20) NOT NULL,
    numero_documento VARCHAR(50) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    telefono VARCHAR(30),
    CONSTRAINT uq_cliente_doc UNIQUE (tipo_documento, numero_documento)
);

-- ============================================================================
-- 3. PRODUCTOS, INGREDIENTES Y PROVEEDORES
-- ============================================================================

CREATE TABLE producto (
    id_producto SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio_venta NUMERIC(12,2) NOT NULL CHECK (precio_venta >= 0),
    cantidad_disponible NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (cantidad_disponible >= 0),
    estado VARCHAR(20) DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo', 'agotado'))
);

CREATE TABLE ingrediente (
    id_ingrediente SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    unidad_medida VARCHAR(20) NOT NULL,
    cantidad_disponible NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (cantidad_disponible >= 0),
    stock_minimo NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0)
);

CREATE TABLE producto_ingrediente (
    id_producto INT REFERENCES producto(id_producto) ON DELETE CASCADE,
    id_ingrediente INT REFERENCES ingrediente(id_ingrediente) ON DELETE CASCADE,
    cantidad_requerida NUMERIC(10,2) NOT NULL CHECK (cantidad_requerida > 0),
    PRIMARY KEY (id_producto, id_ingrediente)
);

CREATE TABLE proveedor (
    id_proveedor SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    documento VARCHAR(50) UNIQUE,
    telefono VARCHAR(30),
    direccion TEXT
);

CREATE TABLE proveedor_producto (
    id_proveedor INT REFERENCES proveedor(id_proveedor) ON DELETE CASCADE,
    id_producto INT REFERENCES producto(id_producto) ON DELETE CASCADE,
    precio_compra NUMERIC(12,2) NOT NULL CHECK (precio_compra >= 0),
    codigo_producto_proveedor VARCHAR(50),
    PRIMARY KEY (id_proveedor, id_producto)
);

-- ============================================================================
-- 4. VENTAS, COMPRAS E INVENTARIO
-- ============================================================================

CREATE TABLE venta (
    id_venta SERIAL PRIMARY KEY,
    id_cliente INT REFERENCES cliente(id_cliente) ON DELETE SET NULL,
    id_empleado INT NOT NULL REFERENCES empleado(id_empleado),
    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metodo_pago VARCHAR(30) NOT NULL DEFAULT 'efectivo' CHECK (metodo_pago IN ('efectivo', 'tarjeta', 'nequi', 'daviplata', 'transferencia')),
    subtotal NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    descuento_total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (descuento_total >= 0),
    total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0)
);

CREATE TABLE detalle_venta (
    id_detalle_venta SERIAL PRIMARY KEY,
    id_venta INT NOT NULL REFERENCES venta(id_venta) ON DELETE CASCADE,
    id_producto INT NOT NULL REFERENCES producto(id_producto),
    cantidad NUMERIC(10,2) NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    observaciones_preparacion TEXT
);

CREATE TABLE compra (
    id_compra SERIAL PRIMARY KEY,
    id_proveedor INT REFERENCES proveedor(id_proveedor) ON DELETE SET NULL,
    id_empleado INT NOT NULL REFERENCES empleado(id_empleado),
    fecha TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('compra_inventario', 'gasto_general')),
    concepto TEXT,
    total NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0)
);

CREATE TABLE detalle_compra (
    id_detalle_compra SERIAL PRIMARY KEY,
    id_compra INT NOT NULL REFERENCES compra(id_compra) ON DELETE CASCADE,
    id_producto INT REFERENCES producto(id_producto),
    id_ingrediente INT REFERENCES ingrediente(id_ingrediente),
    cantidad NUMERIC(10,2) NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2) NOT NULL CHECK (precio_unitario >= 0),
    CONSTRAINT chk_detalle_compra_articulo CHECK (
        (id_producto IS NOT NULL AND id_ingrediente IS NULL) OR 
        (id_producto IS NULL AND id_ingrediente IS NOT NULL)
    )
);

CREATE TABLE movimiento_inventario (
    id_movimiento SERIAL PRIMARY KEY,
    id_empleado INT NOT NULL REFERENCES empleado(id_empleado),
    id_producto INT REFERENCES producto(id_producto),
    id_ingrediente INT REFERENCES ingrediente(id_ingrediente),
    fecha_hora TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_movimiento VARCHAR(30) NOT NULL CHECK (tipo_movimiento IN ('entrada', 'salida', 'ajuste', 'merma')),
    cantidad NUMERIC(10,2) NOT NULL CHECK (cantidad > 0),
    motivo TEXT,
    CONSTRAINT chk_movimiento_articulo CHECK (
        (id_producto IS NOT NULL AND id_ingrediente IS NULL) OR 
        (id_producto IS NULL AND id_ingrediente IS NOT NULL)
    )
);

-- ============================================================================
-- 5. EVENTOS, ARTISTAS Y PROMOCIONES
-- ============================================================================

CREATE TABLE evento (
    id_evento SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME,
    CONSTRAINT chk_evento_horario CHECK (hora_fin IS NULL OR hora_fin > hora_inicio)
);

CREATE TABLE artista (
    id_artista SERIAL PRIMARY KEY,
    nombre_artistico VARCHAR(100) NOT NULL,
    tipo_artista VARCHAR(50),
    contacto TEXT
);

CREATE TABLE evento_artista (
    id_evento INT REFERENCES evento(id_evento) ON DELETE CASCADE,
    id_artista INT REFERENCES artista(id_artista) ON DELETE CASCADE,
    tipo_presentacion VARCHAR(50),
    pago_acordado NUMERIC(12,2) CHECK (pago_acordado >= 0),
    PRIMARY KEY (id_evento, id_artista)
);

CREATE TABLE promocion (
    id_promocion SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    tipo_beneficio VARCHAR(50) NOT NULL,
    valor_beneficio NUMERIC(12,2) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    condiciones TEXT,
    CONSTRAINT chk_promocion_fechas CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE producto_promocion (
    id_producto INT REFERENCES producto(id_producto) ON DELETE CASCADE,
    id_promocion INT REFERENCES promocion(id_promocion) ON DELETE CASCADE,
    PRIMARY KEY (id_producto, id_promocion)
);

CREATE TABLE venta_promocion (
    id_venta INT REFERENCES venta(id_venta) ON DELETE CASCADE,
    id_promocion INT REFERENCES promocion(id_promocion) ON DELETE CASCADE,
    descuento_aportado NUMERIC(12,2) NOT NULL CHECK (descuento_aportado >= 0),
    PRIMARY KEY (id_venta, id_promocion)
);

CREATE TABLE evento_promocion (
    id_evento INT REFERENCES evento(id_evento) ON DELETE CASCADE,
    id_promocion INT REFERENCES promocion(id_promocion) ON DELETE CASCADE,
    hora_inicio TIME,
    hora_fin TIME,
    PRIMARY KEY (id_evento, id_promocion)
);

-- ============================================================================
-- 6. TABLAS VECTORIALES Y BÚSQUEDA SEMÁNTICA (pgvector)
-- ============================================================================

CREATE TABLE embeddings_texto (
    id_embedding SERIAL PRIMARY KEY,
    id_doc INT NOT NULL REFERENCES documentos(id_doc) ON DELETE CASCADE,
    chunk_id INT NOT NULL,
    estrategia_chunking VARCHAR(20) NOT NULL CHECK (estrategia_chunking IN ('fixed-size', 'sentence-aware', 'semantic')),
    chunk_texto TEXT NOT NULL,
    vector_embedding VECTOR(384) NOT NULL,
    modelo VARCHAR(100) NOT NULL,
    UNIQUE (id_doc, estrategia_chunking, chunk_id)
);

CREATE TABLE embeddings_imagen (
    id_embedding SERIAL PRIMARY KEY,
    id_img INT NOT NULL REFERENCES imagenes(id_img) ON DELETE CASCADE,
    vector_embedding VECTOR(512) NOT NULL,
    modelo VARCHAR(100) NOT NULL
);

CREATE TABLE query_embeddings (
    id_qemb SERIAL PRIMARY KEY,
    id_consulta INT NOT NULL REFERENCES consultas(id_consulta) ON DELETE CASCADE,
    vector_embedding VECTOR(384) NOT NULL,
    modelo VARCHAR(100) NOT NULL
);

-- ============================================================================
-- 7. ÍNDICES HNSW PARA BÚSQUEDA VECTORIAL RÁPIDA
-- ============================================================================

CREATE INDEX embeddings_texto_hnsw 
    ON embeddings_texto USING hnsw (vector_embedding vector_cosine_ops);

CREATE INDEX embeddings_imagen_hnsw 
    ON embeddings_imagen USING hnsw (vector_embedding vector_cosine_ops);
