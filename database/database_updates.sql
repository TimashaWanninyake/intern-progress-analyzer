-- ===========================================================
-- DATABASE UPDATES FOR AI REPORTING SYSTEM
-- ===========================================================
-- Date: October 21, 2025
-- Purpose: Add tables and enhancements for multi-AI provider reporting system
--          Supporting OLLAMA, GPT-4, and Claude integrations
-- ===========================================================

USE intern_analytics;

-- ===========================================================
-- AI PROVIDER SETTINGS TABLE
-- ===========================================================
-- Stores configuration for different AI providers
-- ===========================================================

CREATE TABLE IF NOT EXISTS ai_provider_settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    provider_name ENUM('ollama', 'gpt4', 'claude') NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,             -- User-friendly name
    api_endpoint VARCHAR(255),                       -- API endpoint URL
    model_name VARCHAR(100),                         -- Specific model (e.g., 'gpt-4', 'claude-3', 'llama3:8b')
    api_key_required BOOLEAN DEFAULT TRUE,           -- Whether API key is required
    is_active BOOLEAN DEFAULT TRUE,                  -- Whether provider is currently enabled
    max_tokens INT DEFAULT 4000,                     -- Maximum tokens per request
    temperature DECIMAL(3,2) DEFAULT 0.7,           -- AI temperature setting
    cost_per_1k_tokens DECIMAL(10,6) DEFAULT 0.0,   -- Cost tracking
    description TEXT,                                -- Provider description
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_provider_active (provider_name, is_active)
);

-- Insert default AI provider settings
INSERT INTO ai_provider_settings (provider_name, display_name, api_endpoint, model_name, api_key_required, description) VALUES
('ollama', 'OLLAMA (Local)', 'http://localhost:11434/api/generate', 'llama3:8b', FALSE, 'Local AI model - fast, private, no API costs'),
('gpt4', 'GPT-4 (OpenAI)', 'https://api.openai.com/v1/chat/completions', 'gpt-4', TRUE, 'Advanced AI from OpenAI - comprehensive analysis'),
('claude', 'Claude (Anthropic)', 'https://api.anthropic.com/v1/messages', 'claude-3-sonnet-20240229', TRUE, 'Claude AI - detailed insights and professional formatting')
ON DUPLICATE KEY UPDATE 
    display_name = VALUES(display_name),
    api_endpoint = VALUES(api_endpoint),
    model_name = VALUES(model_name),
    description = VALUES(description);

-- ===========================================================
-- AI REPORTS TABLE
-- ===========================================================
-- Stores generated AI reports with metadata
-- ===========================================================

CREATE TABLE IF NOT EXISTS ai_reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,                         -- FK to projects
    supervisor_id INT NOT NULL,                      -- FK to users (supervisor who generated)
    report_type ENUM('weekly', 'monthly', 'project_summary', 'intern_analysis') DEFAULT 'weekly',
    ai_provider ENUM('ollama', 'gpt4', 'claude') NOT NULL,
    model_used VARCHAR(100),                         -- Specific model version used
    report_title VARCHAR(255),                       -- Report title
    report_data JSON,                                -- Complete report data structure
    summary TEXT,                                    -- Quick summary
    warnings TEXT,                                   -- Identified issues/warnings
    suggestions TEXT,                                -- AI recommendations
    performance_metrics JSON,                        -- Structured performance data
    week_start_date DATE,                            -- For weekly reports
    week_end_date DATE,                              -- For weekly reports
    generation_time_ms INT,                          -- Time taken to generate (milliseconds)
    token_usage INT DEFAULT 0,                       -- Tokens used for cost tracking
    status ENUM('generating', 'completed', 'failed', 'archived') DEFAULT 'generating',
    error_message TEXT,                              -- Error details if generation failed
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (supervisor_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_project_date (project_id, week_start_date, week_end_date),
    INDEX idx_supervisor_date (supervisor_id, generated_at),
    INDEX idx_status_provider (status, ai_provider),
    INDEX idx_report_type (report_type)
);

-- ===========================================================
-- AI REPORT TEMPLATES TABLE
-- ===========================================================
-- Stores customizable report templates
-- ===========================================================

CREATE TABLE IF NOT EXISTS ai_report_templates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    template_name VARCHAR(100) NOT NULL UNIQUE,
    report_type ENUM('weekly', 'monthly', 'project_summary', 'intern_analysis') NOT NULL,
    template_prompt TEXT NOT NULL,                   -- AI prompt template
    output_format ENUM('structured', 'narrative', 'detailed') DEFAULT 'structured',
    sections JSON,                                   -- Report sections configuration
    is_default BOOLEAN DEFAULT FALSE,               -- Whether this is the default template
    created_by INT,                                  -- FK to users (admin/supervisor who created)
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_type_active (report_type, is_active)
);

-- Insert default report templates
INSERT INTO ai_report_templates (template_name, report_type, template_prompt, output_format, sections, is_default) VALUES
('Standard Weekly Report', 'weekly', 
'Analyze the following logbook entries from interns for this week. Provide a comprehensive weekly progress report including: 1) Overall Progress Summary, 2) Individual Intern Performance, 3) Challenges Identified, 4) Achievements Highlights, 5) Recommendations for Next Week. Format the response as structured JSON with clear sections.',
'structured', 
'{"sections": ["progress_summary", "individual_performance", "challenges", "achievements", "recommendations", "risk_assessment"]}',
TRUE),

('Detailed Intern Analysis', 'intern_analysis',
'Perform a detailed analysis of individual intern performance based on their logbook entries. Focus on: 1) Technical Skills Development, 2) Problem-Solving Abilities, 3) Communication & Collaboration, 4) Areas for Improvement, 5) Strengths to Leverage, 6) Personalized Development Plan.',
'detailed',
'{"sections": ["technical_skills", "problem_solving", "communication", "improvements", "strengths", "development_plan"]}',
TRUE),

('Project Summary Report', 'project_summary',
'Generate a comprehensive project summary based on all available data. Include: 1) Project Overview & Objectives, 2) Team Performance Analysis, 3) Milestone Progress, 4) Technical Challenges & Solutions, 5) Resource Utilization, 6) Risk Assessment, 7) Future Recommendations.',
'narrative',
'{"sections": ["overview", "team_performance", "milestones", "technical_analysis", "resources", "risks", "recommendations"]}',
TRUE)
ON DUPLICATE KEY UPDATE 
    template_prompt = VALUES(template_prompt),
    output_format = VALUES(output_format),
    sections = VALUES(sections);

-- ===========================================================
-- SYSTEM PREFERENCES TABLE
-- ===========================================================
-- Stores user/system preferences for AI reporting
-- ===========================================================

CREATE TABLE IF NOT EXISTS system_preferences (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,                                     -- FK to users (NULL for system-wide preferences)
    preference_key VARCHAR(100) NOT NULL,
    preference_value TEXT,
    preference_type ENUM('string', 'json', 'boolean', 'integer') DEFAULT 'string',
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_preference (user_id, preference_key),
    INDEX idx_user_key (user_id, preference_key)
);

-- Insert default system preferences
INSERT INTO system_preferences (user_id, preference_key, preference_value, preference_type, description) VALUES
(NULL, 'default_ai_provider', 'ollama', 'string', 'Default AI provider for new users'),
(NULL, 'max_report_history', '50', 'integer', 'Maximum number of reports to keep per project'),
(NULL, 'auto_generate_weekly', 'true', 'boolean', 'Automatically generate weekly reports'),
(NULL, 'report_retention_days', '365', 'integer', 'Number of days to retain archived reports'),
(NULL, 'ai_timeout_seconds', '300', 'integer', 'Timeout for AI API calls in seconds')
ON DUPLICATE KEY UPDATE 
    preference_value = VALUES(preference_value),
    description = VALUES(description);

-- ===========================================================
-- USAGE STATISTICS TABLE
-- ===========================================================
-- Track AI provider usage for analytics and cost management
-- ===========================================================

CREATE TABLE IF NOT EXISTS ai_usage_statistics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,                            -- FK to users
    ai_provider ENUM('ollama', 'gpt4', 'claude') NOT NULL,
    report_type ENUM('weekly', 'monthly', 'project_summary', 'intern_analysis'),
    tokens_used INT DEFAULT 0,
    generation_time_ms INT DEFAULT 0,
    cost_estimated DECIMAL(10,6) DEFAULT 0.00,       -- Estimated cost in USD
    success BOOLEAN DEFAULT TRUE,
    error_type VARCHAR(100),                         -- Error category if failed
    used_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user_provider_date (user_id, ai_provider, used_at),
    INDEX idx_provider_success (ai_provider, success),
    INDEX idx_usage_date (used_at)
);

-- ===========================================================
-- INTERN PERFORMANCE METRICS TABLE
-- ===========================================================
-- Stores calculated performance metrics for interns
-- ===========================================================

CREATE TABLE IF NOT EXISTS intern_performance_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,
    intern_id INT NOT NULL,                          -- FK to users
    project_id INT NOT NULL,                         -- FK to projects
    metric_period_start DATE NOT NULL,
    metric_period_end DATE NOT NULL,
    productivity_score DECIMAL(5,2),                 -- 0-100 productivity score
    consistency_score DECIMAL(5,2),                  -- 0-100 consistency score
    challenge_resolution_score DECIMAL(5,2),         -- 0-100 problem-solving score
    communication_score DECIMAL(5,2),                -- 0-100 communication score
    technical_growth_score DECIMAL(5,2),             -- 0-100 technical improvement score
    overall_performance_score DECIMAL(5,2),          -- 0-100 overall score
    metrics_data JSON,                               -- Detailed metrics breakdown
    calculated_by_ai ENUM('ollama', 'gpt4', 'claude'),
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (intern_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    INDEX idx_intern_period (intern_id, metric_period_start, metric_period_end),
    INDEX idx_project_period (project_id, metric_period_start, metric_period_end),
    INDEX idx_performance_score (overall_performance_score)
);

-- ===========================================================
-- REPORT FEEDBACK TABLE
-- ===========================================================
-- Store supervisor feedback on AI-generated reports
-- ===========================================================

CREATE TABLE IF NOT EXISTS report_feedback (
    id INT AUTO_INCREMENT PRIMARY KEY,
    report_id INT NOT NULL,                          -- FK to ai_reports
    supervisor_id INT NOT NULL,                      -- FK to users
    accuracy_rating INT CHECK (accuracy_rating BETWEEN 1 AND 5),
    usefulness_rating INT CHECK (usefulness_rating BETWEEN 1 AND 5),
    completeness_rating INT CHECK (completeness_rating BETWEEN 1 AND 5),
    feedback_text TEXT,
    suggestions_for_improvement TEXT,
    would_use_again BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (report_id) REFERENCES ai_reports(id) ON DELETE CASCADE,
    FOREIGN KEY (supervisor_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_report_feedback (report_id),
    INDEX idx_supervisor_feedback (supervisor_id, created_at)
);

-- ===========================================================
-- UPDATE EXISTING WEEKLY_REPORTS TABLE
-- ===========================================================
-- Enhance existing weekly_reports table for compatibility
-- ===========================================================

-- Add AI provider tracking to existing weekly_reports
ALTER TABLE weekly_reports 
ADD COLUMN IF NOT EXISTS ai_provider ENUM('ollama', 'gpt4', 'claude') DEFAULT 'ollama' 
AFTER generated_by_model;

ALTER TABLE weekly_reports 
ADD COLUMN IF NOT EXISTS report_status ENUM('active', 'archived', 'superseded') DEFAULT 'active' 
AFTER generated_on;

ALTER TABLE weekly_reports 
ADD COLUMN IF NOT EXISTS tokens_used INT DEFAULT 0 
AFTER report_status;

-- Add index for better performance
ALTER TABLE weekly_reports 
ADD INDEX IF NOT EXISTS idx_ai_provider_status (ai_provider, report_status);

-- ===========================================================
-- ENHANCE LOGBOOK_ENTRIES TABLE
-- ===========================================================
-- Add fields to support better AI analysis
-- ===========================================================

-- Add sentiment analysis fields
ALTER TABLE logbook_entries 
ADD COLUMN IF NOT EXISTS mood_rating INT CHECK (mood_rating BETWEEN 1 AND 5) 
AFTER tomorrow_plan;

ALTER TABLE logbook_entries 
ADD COLUMN IF NOT EXISTS productivity_self_rating INT CHECK (productivity_self_rating BETWEEN 1 AND 5) 
AFTER mood_rating;

ALTER TABLE logbook_entries 
ADD COLUMN IF NOT EXISTS hours_worked DECIMAL(4,2) DEFAULT 8.0 
AFTER productivity_self_rating;

ALTER TABLE logbook_entries 
ADD COLUMN IF NOT EXISTS tags JSON 
AFTER hours_worked;

-- Add index for AI analysis queries
ALTER TABLE logbook_entries 
ADD INDEX IF NOT EXISTS idx_mood_productivity (mood_rating, productivity_self_rating);

-- ===========================================================
-- CREATE VIEWS FOR COMMON AI QUERIES
-- ===========================================================

-- View for comprehensive intern performance data
CREATE OR REPLACE VIEW intern_performance_view AS
SELECT 
    u.id as intern_id,
    u.name as intern_name,
    u.slt_id,
    p.id as project_id,
    p.name as project_name,
    COUNT(le.id) as total_entries,
    AVG(le.mood_rating) as avg_mood,
    AVG(le.productivity_self_rating) as avg_self_productivity,
    AVG(le.hours_worked) as avg_hours_worked,
    MAX(le.date) as last_entry_date,
    DATEDIFF(CURDATE(), MAX(le.date)) as days_since_last_entry
FROM users u
LEFT JOIN project_assignments pa ON u.id = pa.intern_id AND pa.is_active = TRUE
LEFT JOIN projects p ON pa.project_id = p.id
LEFT JOIN logbook_entries le ON u.id = le.intern_id
WHERE u.role = 'intern'
GROUP BY u.id, p.id;

-- View for project progress analysis
CREATE OR REPLACE VIEW project_progress_view AS
SELECT 
    p.id as project_id,
    p.name as project_name,
    p.status,
    p.supervisor_id,
    us.name as supervisor_name,
    COUNT(DISTINCT pa.intern_id) as intern_count,
    COUNT(le.id) as total_logbook_entries,
    COUNT(DISTINCT le.date) as active_days,
    AVG(le.mood_rating) as avg_team_mood,
    AVG(le.productivity_self_rating) as avg_team_productivity,
    MAX(le.date) as last_activity_date,
    COUNT(DISTINCT ar.id) as ai_reports_generated
FROM projects p
LEFT JOIN users us ON p.supervisor_id = us.id
LEFT JOIN project_assignments pa ON p.id = pa.project_id AND pa.is_active = TRUE
LEFT JOIN logbook_entries le ON pa.intern_id = le.intern_id
LEFT JOIN ai_reports ar ON p.id = ar.project_id
GROUP BY p.id;

-- ===========================================================
-- CLEANUP AND OPTIMIZATION
-- ===========================================================

-- Remove any duplicate entries that might exist
-- (Safety measure for repeated script execution)

-- Optimize table storage engines
ALTER TABLE ai_provider_settings ENGINE=InnoDB;
ALTER TABLE ai_reports ENGINE=InnoDB;
ALTER TABLE ai_report_templates ENGINE=InnoDB;
ALTER TABLE system_preferences ENGINE=InnoDB;
ALTER TABLE ai_usage_statistics ENGINE=InnoDB;
ALTER TABLE intern_performance_metrics ENGINE=InnoDB;
ALTER TABLE report_feedback ENGINE=InnoDB;

-- ===========================================================
-- SUCCESS MESSAGE
-- ===========================================================

SELECT 'Database updates for AI Reporting System completed successfully!' as status,
       'Added 7 new tables and enhanced existing tables for multi-AI provider support' as details,
       NOW() as updated_at;
