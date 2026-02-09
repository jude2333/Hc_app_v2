-- PostgREST JWT Role Setup for Local Development
-- Run this in pgAdmin connected to live_db2

-- 1. Create anonymous role (for unauthenticated requests)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anonymous') THEN
    CREATE ROLE anonymous NOLOGIN;
    RAISE NOTICE 'Created role: anonymous';
  ELSE
    RAISE NOTICE 'Role anonymous already exists';
  END IF;
END
$$;

-- 2. Create webuser role (for authenticated requests)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'webuser') THEN
    CREATE ROLE webuser NOLOGIN;
    RAISE NOTICE 'Created role: webuser';
  ELSE
    RAISE NOTICE 'Role webuser already exists';
  END IF;
END
$$;

-- 3. Grant permissions to anonymous (minimal - just login function)
GRANT USAGE ON SCHEMA data TO anonymous;
GRANT USAGE ON SCHEMA public TO anonymous;
GRANT EXECUTE ON FUNCTION data.login_v4(text, text, integer) TO anonymous;

-- 4. Grant full CRUD to webuser (authenticated users)
GRANT USAGE ON SCHEMA data TO webuser;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA data TO webuser;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA data TO webuser;

-- 5. Allow postgres to switch to these roles
GRANT anonymous TO postgres;
GRANT webuser TO postgres;

-- Verify roles exist
SELECT rolname FROM pg_roles WHERE rolname IN ('anonymous', 'webuser');
