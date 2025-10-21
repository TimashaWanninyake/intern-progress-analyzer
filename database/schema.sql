CREATE DATABASE IF NOT EXISTS intern_analytics;
USE intern_analytics;

-- ===========================================================
-- USERS TABLE
-- ===========================================================
-- Stores all system users: interns, supervisors, and admins
-- 
-- Authentication Rules:
-- - INTERNS: Login with email only (no password required)
-- - SUPERVISORS: Login with email + password
-- - ADMINS: Login with email + password
-- 
-- Password Management:
-- - Supervisors/Admins: Can use "Forgot Password" with OTP
-- - Interns: password_hash is stored but not used for authentication
-- ===========================================================

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    slt_id VARCHAR(20) UNIQUE,                    -- Employee ID (e.g., T001000, S001000, A001000)
    name VARCHAR(100) NOT NULL,                    -- Full name of the user
    email VARCHAR(120) NOT NULL UNIQUE,            -- Email address (used for login)
    password_hash VARCHAR(255) NOT NULL,           -- Hashed password (only used for admin/supervisor)
    role ENUM('intern', 'supervisor', 'admin') DEFAULT 'intern',  -- User role
    project_id INT NULL,                           -- FK to projects (for interns only)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),                       -- Fast email lookup for login
    INDEX idx_role (role)                          -- Fast role-based queries
);

-- ===========================================================
-- PROJECTS TABLE
-- ===========================================================
-- Stores project information managed by supervisors
-- ===========================================================

CREATE TABLE projects (
    id INT AUTO_INCREMENT PRIMARY KEY,   
    name VARCHAR(150) NOT NULL,                    -- Project name
    description TEXT,                              -- Project description
    supervisor_id INT NOT NULL,                    -- FK to users (supervisor)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (supervisor_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_supervisor (supervisor_id)           -- Fast supervisor lookup
);

-- ===========================================================
-- LOGBOOK ENTRIES TABLE
-- ===========================================================
-- Stores daily logbook entries submitted by interns
-- ===========================================================

CREATE TABLE logbook_entries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    intern_id INT NOT NULL,                        -- FK to users (intern)
    date DATE NOT NULL,                            -- Entry date
    status ENUM('Working', 'WFH', 'Leave') DEFAULT 'Working',  -- Work status
    task_stack ENUM('Frontend', 'Backend', 'DataScience', 'UIUX', 'DevOps', 'Other') DEFAULT 'Other',
    todays_work TEXT NOT NULL,                     -- What was accomplished today
    challenges TEXT,                               -- Challenges faced
    tomorrow_plan TEXT,                            -- Plan for tomorrow
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (intern_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_intern_date (intern_id, date),       -- Fast lookup by intern and date
    INDEX idx_date (date)                          -- Fast date-based queries
);

-- ===========================================================
-- WEEKLY REPORTS TABLE
-- ===========================================================
-- Stores AI-generated weekly progress reports for projects
-- ===========================================================

CREATE TABLE weekly_reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,                       -- FK to projects
    week_start_date DATE NOT NULL,                 -- Start of the week
    week_end_date DATE NOT NULL,                   -- End of the week
    summary TEXT,                                  -- AI-generated summary
    warnings TEXT,                                 -- AI-generated warnings
    suggestions TEXT,                              -- AI-generated suggestions
    generated_by_model VARCHAR(50) DEFAULT 'gemma3:1b',  -- AI model used
    generated_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    INDEX idx_project_week (project_id, week_start_date, week_end_date)
);

-- ===========================================================
-- SYSTEM LOGS TABLE
-- ===========================================================
-- Stores system-wide activity logs for auditing
-- ===========================================================

CREATE TABLE system_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    action_type VARCHAR(100),                      -- Type of action (e.g., 'USER_CREATED', 'LOGIN')
    details TEXT,                                  -- Additional details about the action
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_action_type (action_type),           -- Fast action type queries
    INDEX idx_created_at (created_at)              -- Fast time-based queries
);

-- ===========================================================
-- PASSWORD RESET OTP TABLE (OPTIONAL - for production)
-- ===========================================================
-- Stores OTP codes for password reset
-- Note: Currently using in-memory storage. For production, use this table.
-- ===========================================================

CREATE TABLE password_reset_otps (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(120) NOT NULL,                   -- User email
    otp VARCHAR(6) NOT NULL,                       -- 6-digit OTP code
    expires_at TIMESTAMP NOT NULL,                 -- OTP expiration time (10 minutes)
    used BOOLEAN DEFAULT FALSE,                    -- Whether OTP has been used
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email_otp (email, otp),              -- Fast OTP verification
    INDEX idx_expires_at (expires_at)              -- Cleanup expired OTPs
);

-- ===========================================================
-- SAMPLE DATA FOR TESTING
-- ===========================================================

-- Admin User (Login: admin@company.com + password)
-- Note: Update password_hash with actual hashed password using werkzeug
INSERT INTO users (slt_id, name, email, password_hash, role)
VALUES 
('A001000', 'Admin User', 'admin@company.com', 
 'pbkdf2:sha256:600000$defaultsalt$1234567890abcdef', 'admin');

-- Supervisor (Login: kamal@company.com + password)
-- Note: Use "Forgot Password" feature to set initial password
INSERT INTO users (slt_id, name, email, password_hash, role)
VALUES
('S001000', 'Kamal Perera', 'kamal@company.com', 
 'pbkdf2:sha256:600000$defaultsalt$1234567890abcdef', 'supervisor');

-- Interns (Login: email only, NO password required)
-- password_hash is stored but not used for intern authentication
INSERT INTO users (slt_id, name, email, password_hash, role, project_id)
VALUES
('T001000', 'Ushani Silva', 'ushani@company.com', 'not_used_for_interns', 'intern', NULL),
('T001001', 'Lesanda Fernando', 'lesanda@company.com', 'not_used_for_interns', 'intern', NULL);

-- Sample Project
INSERT INTO projects (name, description, supervisor_id)
VALUES 
('AI-Powered HRMS', 'Develop an advanced HR Management System with AI-powered analytics and intern progress tracking', 1),
('Mobile App Development', 'Create a cross-platform mobile application using Flutter', 2);

-- Assign interns to project
UPDATE users SET project_id = 1 WHERE slt_id IN ('T001000', 'T001001');

-- Sample Logbook Entries
INSERT INTO logbook_entries (intern_id, date, status, task_stack, todays_work, challenges, tomorrow_plan)
VALUES
(3, '2025-10-15', 'Working', 'Frontend', 'Implemented login page UI with role selection buttons', 'Handling state management for role selection', 'Add email validation and API integration'),
(3, '2025-10-16', 'Working', 'Frontend', 'Integrated login API and implemented navigation to dashboards', 'CORS issues with API calls', 'Work on intern dashboard logbook feature'),
(3, '2025-10-17', 'WFH', 'Frontend', 'Created logbook entry form with dropdown and radio buttons', 'UI layout responsive issues on mobile', 'Test logbook submission and view past logs'),
(4, '2025-10-15', 'Working', 'Backend', 'Set up Flask application structure and database connection', 'MySQL connection pooling configuration', 'Implement authentication endpoints'),
(4, '2025-10-16', 'Working', 'Backend', 'Created user authentication routes with JWT token generation', 'Token expiry handling', 'Add admin routes for user management'),
(4, '2025-10-17', 'Working', 'Backend', 'Implemented forgot password with OTP functionality', 'Email service integration pending', 'Test OTP flow and add rate limiting');

-- Sample Weekly Report
INSERT INTO weekly_reports (project_id, week_start_date, week_end_date, summary, warnings, suggestions)
VALUES
(1, '2025-10-13', '2025-10-19', 
 'Good progress on frontend and backend development. Login system implemented successfully with role-based authentication.',
 'CORS issues delayed API integration. Email service for OTP not yet integrated.',
 'Consider adding unit tests for authentication flows. Implement email service for production deployment.');

-- Sample System Logs
INSERT INTO system_logs (action_type, details)
VALUES
('USER_CREATED', 'Admin user created: admin@company.com'),
('USER_CREATED', 'Supervisor created: kamal@company.com'),
('USER_CREATED', 'Intern created: ushani@company.com'),
('USER_CREATED', 'Intern created: lesanda@company.com'),
('PROJECT_CREATED', 'Project created: AI-Powered HRMS'),
('LOGIN_SUCCESS', 'User logged in: admin@company.com (admin)'),
('PASSWORD_RESET', 'Password reset requested: kamal@company.com');




-- Add status column to projects table
ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS status ENUM('Ongoing', 'Completed', 'Hold') DEFAULT 'Ongoing' 
AFTER description;

-- Update existing projects to have 'Ongoing' status
UPDATE projects SET status = 'Ongoing' WHERE status IS NULL;

-- Add index for status field for faster filtering
ALTER TABLE projects ADD INDEX idx_status (status);




-- Allows one intern to be assigned to multiple projects
CREATE TABLE IF NOT EXISTS project_assignments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    intern_id INT NOT NULL,
    project_id INT NOT NULL,
    assigned_date DATE DEFAULT (CURRENT_DATE),
    role_in_project VARCHAR(100) DEFAULT 'Developer',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (intern_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    UNIQUE KEY unique_assignment (intern_id, project_id),
    INDEX idx_intern (intern_id),
    INDEX idx_project (project_id),
    INDEX idx_active (is_active)
);

INSERT INTO project_assignments (intern_id, project_id, assigned_date, is_active)
SELECT id, project_id, CURDATE(), TRUE
FROM users
WHERE project_id IS NOT NULL AND role = 'intern'
ON DUPLICATE KEY UPDATE is_active = TRUE;

-- Add status column if not exists (from previous update)
ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS status ENUM('Ongoing', 'Completed', 'Hold') DEFAULT 'Ongoing' 
AFTER description;

-- Add more project details
ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS start_date DATE DEFAULT (CURRENT_DATE) AFTER status;

ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS end_date DATE NULL AFTER start_date;

ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS project_type VARCHAR(100) DEFAULT 'Development' AFTER end_date;

ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS technologies TEXT AFTER project_type;

ALTER TABLE projects 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at;

-- Add indexes
ALTER TABLE projects ADD INDEX IF NOT EXISTS idx_status (status);
ALTER TABLE projects ADD INDEX IF NOT EXISTS idx_start_date (start_date);

-- Set start_date for existing projects to their creation date
UPDATE projects SET start_date = DATE(created_at) WHERE start_date IS NULL;