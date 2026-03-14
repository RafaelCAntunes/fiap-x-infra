--  Tabela de Usuários
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR(255) PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de Vídeos
CREATE TABLE IF NOT EXISTS videos (
    id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    s3_input_key VARCHAR(255),
    s3_output_key VARCHAR(255),
    status VARCHAR(50) DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user FOREIGN KEY(user_id) REFERENCES users(id)
);

INSERT INTO users (id, username, password, created_at)
VALUES (
    'a7b8c9d0-e1f2-4a5b-8c9d-0e1f2a3b4c5d', 
    'rafael_admin', 
    '$2a$10$7czAqCyFdWxjpJfMHid5AOVMSqOFm1ixtwKBTc6K8PspFbIkCVzIC', -- hash para a senha 'admin123'
    NOW()
) ON CONFLICT (username) DO NOTHING;