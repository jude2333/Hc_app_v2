-- -- Anderson CRM Database Initialization Script
-- -- Run this after Docker containers are up

-- -- Create the 'data' schema (used by PostgREST)
-- CREATE SCHEMA IF NOT EXISTS data;

-- -- Create tables in 'data' schema
-- -- CREATE TABLE IF NOT EXISTS data.hc_patient_visit_detail (
-- --     id TEXT PRIMARY KEY,
-- --     tenant_id INTEGER,
-- --     hcpm_id INTEGER,
-- --     doc_id TEXT,
-- --     patient_name TEXT,
-- --     visit_date TEXT,
-- --     visit_time TEXT,
-- --     doctor_name TEXT,
-- --     pro_id INTEGER,
-- --     manager_id TEXT,
-- --     manager_name TEXT,
-- --     assigned_id TEXT,
-- --     assigned_to TEXT,
-- --     b2b_client_id INTEGER,
-- --     b2b_client_name TEXT,
-- --     status TEXT DEFAULT 'Pending',
-- --     server_status TEXT DEFAULT 'Pending',
-- --     bill_amount REAL DEFAULT 0,
-- --     received_amount REAL DEFAULT 0,
-- --     discount_amount REAL DEFAULT 0,
-- --     doc TEXT DEFAULT '{}',
-- --     bill_number TEXT DEFAULT '',
-- --     lab_number TEXT DEFAULT '',
-- --     visible INTEGER DEFAULT 1,
-- --     created_by TEXT,
-- --     created_at TEXT,
-- --     last_updated_by TEXT,
-- --     last_updated_at TEXT
-- -- );

-- -- CREATE TABLE IF NOT EXISTS data.price_list (
-- --     id TEXT PRIMARY KEY,
-- --     dept_id INTEGER,
-- --     dept_name TEXT,
-- --     invest_id INTEGER,
-- --     invest_name TEXT,
-- --     base_cost REAL,
-- --     min_cost REAL,
-- --     visible INTEGER DEFAULT 1,
-- --     created_at TEXT,
-- --     updated_at TEXT
-- -- );

-- -- Create PowerSync publication
-- CREATE PUBLICATION powersync FOR ALL TABLES;

-- -- Grant permissions
-- GRANT USAGE ON SCHEMA data TO postgres;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA data TO postgres;

-- -- Sample data for testing
-- INSERT INTO data.price_list (id, dept_id, dept_name, invest_id, invest_name, base_cost, min_cost, visible)
-- VALUES 
--     ('pl-001', 1, 'Pathology', 101, 'Complete Blood Count', 350, 250, 1),
--     ('pl-002', 1, 'Pathology', 102, 'Lipid Profile', 600, 450, 1),
--     ('pl-003', 2, 'Radiology', 201, 'X-Ray Chest', 400, 300, 1)
-- ON CONFLICT (id) DO NOTHING;

-- -- Verify setup
-- SELECT 'Tables created successfully' as status;
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'data';
