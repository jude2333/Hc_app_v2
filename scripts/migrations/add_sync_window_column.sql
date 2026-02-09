-- PowerSync Sync Window Migration
-- Adds sync_window column for dynamic date filtering

-- 1. Add sync_window column (default true so existing records sync initially)
ALTER TABLE data.hc_patient_visit_detail 
ADD COLUMN IF NOT EXISTS sync_window BOOLEAN DEFAULT true;

-- 2. Create partial index for efficient filtering (only indexes true values)
CREATE INDEX IF NOT EXISTS idx_hc_patient_visit_detail_sync_window 
ON data.hc_patient_visit_detail(sync_window) 
WHERE sync_window = true;

-- 3. Initial population: Set sync_window based on date window
-- 7 days back (for technicians to finish pending orders)
-- 10 days forward (for managers to see upcoming orders)
UPDATE data.hc_patient_visit_detail 
SET sync_window = (
  visit_date >= CURRENT_DATE - INTERVAL '7 days' 
  AND visit_date <= CURRENT_DATE + INTERVAL '10 days'
);

-- Verify the update
SELECT 
  'Total records' as category,
  COUNT(*) as count 
FROM data.hc_patient_visit_detail
UNION ALL
SELECT 
  'sync_window = true' as category,
  COUNT(*) as count 
FROM data.hc_patient_visit_detail 
WHERE sync_window = true;
