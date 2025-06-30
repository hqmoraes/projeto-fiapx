-- =====================================================
-- SCRIPT DE CRIAÇÃO DO BANCO DE DADOS - PROJETO FIAP-X
-- Sistema de Processamento de Vídeos
-- =====================================================

-- Criar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- TABELA DE USUÁRIOS
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE
);

-- Índices para otimização
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- =====================================================
-- TABELA DE JOBS DE PROCESSAMENTO
-- =====================================================
CREATE TABLE IF NOT EXISTS processing_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    original_filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    -- Status: PENDING, PROCESSING, COMPLETED, ERROR, CANCELLED
    progress INTEGER DEFAULT 0, -- 0-100
    frames_extracted INTEGER DEFAULT 0,
    total_frames INTEGER,
    error_message TEXT,
    result_zip_path VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_jobs_user_id ON processing_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON processing_jobs(status);
CREATE INDEX IF NOT EXISTS idx_jobs_created_at ON processing_jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_jobs_user_status ON processing_jobs(user_id, status);

-- =====================================================
-- TABELA DE SESSÕES (JWT/Redis backup)
-- =====================================================
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- Índices para sessões
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON user_sessions(expires_at);

-- =====================================================
-- TABELA DE LOGS DE AUDITORIA
-- =====================================================
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50),
    resource_id UUID,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Índice para logs
CREATE INDEX IF NOT EXISTS idx_audit_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs(created_at);

-- =====================================================
-- TRIGGERS PARA UPDATED_AT
-- =====================================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jobs_updated_at 
    BEFORE UPDATE ON processing_jobs 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- VIEWS ÚTEIS
-- =====================================================

-- View para estatísticas por usuário
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    u.id,
    u.username,
    u.email,
    COUNT(pj.id) as total_jobs,
    COUNT(CASE WHEN pj.status = 'COMPLETED' THEN 1 END) as completed_jobs,
    COUNT(CASE WHEN pj.status = 'ERROR' THEN 1 END) as error_jobs,
    COUNT(CASE WHEN pj.status = 'PROCESSING' THEN 1 END) as processing_jobs,
    COUNT(CASE WHEN pj.status = 'PENDING' THEN 1 END) as pending_jobs,
    MAX(pj.created_at) as last_job_date,
    u.created_at as user_since
FROM users u
LEFT JOIN processing_jobs pj ON u.id = pj.user_id
GROUP BY u.id, u.username, u.email, u.created_at;

-- View para jobs recentes
CREATE OR REPLACE VIEW recent_jobs AS
SELECT 
    pj.id,
    pj.user_id,
    u.username,
    pj.original_filename,
    pj.status,
    pj.progress,
    pj.created_at,
    pj.completed_at,
    CASE 
        WHEN pj.completed_at IS NOT NULL AND pj.started_at IS NOT NULL 
        THEN EXTRACT(EPOCH FROM (pj.completed_at - pj.started_at))
        ELSE NULL 
    END as processing_time_seconds
FROM processing_jobs pj
JOIN users u ON pj.user_id = u.id
ORDER BY pj.created_at DESC;

-- =====================================================
-- FUNÇÃO PARA CLEANUP DE DADOS ANTIGOS
-- =====================================================
CREATE OR REPLACE FUNCTION cleanup_old_data(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
BEGIN
    -- Limpar sessões expiradas
    DELETE FROM user_sessions WHERE expires_at < CURRENT_TIMESTAMP;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    
    -- Limpar logs antigos
    DELETE FROM audit_logs WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '1 day' * days_to_keep;
    GET DIAGNOSTICS deleted_count = deleted_count + ROW_COUNT;
    
    -- Limpar jobs completados antigos (opcional - comentado por segurança)
    -- DELETE FROM processing_jobs 
    -- WHERE status = 'COMPLETED' 
    --   AND completed_at < CURRENT_TIMESTAMP - INTERVAL '1 day' * days_to_keep;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- DADOS INICIAIS (SEEDS)
-- =====================================================

-- Usuário padrão para testes (senha: admin123)
INSERT INTO users (username, email, password_hash) 
VALUES (
    'admin',
    'admin@fiapx.com',
    '$2a$10$8K1p/3qGEQgF2BaGKCOqMe7OWkK.2l3N5Wb3yf6x7tJKH4v6RqJhS'
) ON CONFLICT (username) DO NOTHING;

-- Usuário de teste (senha: test123)
INSERT INTO users (username, email, password_hash)
VALUES (
    'testuser',
    'test@fiapx.com',
    '$2a$10$DUmlkF4HU1sL9fCb7EUbP.CrHH2u.u6YGRHsAaEoGw8TgNBEDxxxy'
) ON CONFLICT (username) DO NOTHING;

-- =====================================================
-- PERMISSÕES E SEGURANÇA
-- =====================================================

-- Usuário específico da aplicação (opcional)
-- CREATE USER fiapx_app WITH ENCRYPTED PASSWORD 'your_secure_password_here';
-- GRANT CONNECT ON DATABASE fiapx TO fiapx_app;
-- GRANT USAGE ON SCHEMA public TO fiapx_app;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO fiapx_app;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO fiapx_app;

-- =====================================================
-- MONITORING QUERIES (para métricas)
-- =====================================================

-- Query para monitorar performance
CREATE OR REPLACE VIEW performance_metrics AS
SELECT 
    'total_users' as metric,
    COUNT(*)::text as value
FROM users
UNION ALL
SELECT 
    'active_jobs' as metric,
    COUNT(*)::text as value
FROM processing_jobs WHERE status IN ('PENDING', 'PROCESSING')
UNION ALL
SELECT 
    'completed_today' as metric,
    COUNT(*)::text as value
FROM processing_jobs 
WHERE status = 'COMPLETED' 
  AND completed_at > CURRENT_DATE
UNION ALL
SELECT 
    'error_rate_today' as metric,
    ROUND(
        (COUNT(CASE WHEN status = 'ERROR' THEN 1 END) * 100.0 / 
         NULLIF(COUNT(*), 0)), 2
    )::text || '%' as value
FROM processing_jobs 
WHERE created_at > CURRENT_DATE;

-- =====================================================
-- COMENTÁRIOS E DOCUMENTAÇÃO
-- =====================================================

COMMENT ON TABLE users IS 'Tabela de usuários do sistema';
COMMENT ON TABLE processing_jobs IS 'Jobs de processamento de vídeo';
COMMENT ON TABLE user_sessions IS 'Sessões ativas de usuários';
COMMENT ON TABLE audit_logs IS 'Logs de auditoria do sistema';

COMMENT ON COLUMN users.password_hash IS 'Hash bcrypt da senha do usuário';
COMMENT ON COLUMN processing_jobs.status IS 'Status: PENDING, PROCESSING, COMPLETED, ERROR, CANCELLED';
COMMENT ON COLUMN processing_jobs.progress IS 'Progresso de 0 a 100%';

-- =====================================================
-- VALIDAÇÃO FINAL
-- =====================================================

-- Verificar se todas as tabelas foram criadas
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
      AND table_name IN ('users', 'processing_jobs', 'user_sessions', 'audit_logs');
    
    IF table_count = 4 THEN
        RAISE NOTICE 'SUCCESS: Todas as 4 tabelas foram criadas com sucesso!';
    ELSE
        RAISE EXCEPTION 'ERRO: Nem todas as tabelas foram criadas. Encontradas: %', table_count;
    END IF;
END $$;

-- =====================================================
-- SCRIPT FINALIZADO
-- =====================================================
-- Para executar este script:
-- psql -U postgres -d fiapx -f create_database.sql
-- 
-- Ou via Docker:
-- docker exec -i postgres-container psql -U postgres -d fiapx < create_database.sql
-- =====================================================
