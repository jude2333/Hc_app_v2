import 'package:powersync/powersync.dart';

const schema = Schema([
  // workOrder table
  Table('hc_patient_visit_detail', [
    Column.integer('tenant_id'),
    Column.integer('hcpm_id'),
    Column.text('doc_id'),
    Column.text('patient_name'),
    Column.text('visit_date'),
    Column.text('visit_time'),
    Column.text('doctor_name'),
    Column.integer('pro_id'),
    Column.integer('manager_id'),
    Column.text('manager_name'),
    Column.integer('assigned_id'),
    Column.text('assigned_to'),
    Column.integer('b2b_client_id'),
    Column.text('b2b_client_name'),
    Column.text('status'),
    Column.text('server_status'),
    Column.real('bill_amount'),
    Column.real('received_amount'),
    Column.real('discount_amount'),
    Column.text('doc'),
    Column.text('bill_number'),
    Column.text('lab_number'),
    Column.integer('visible'),
    Column.text('created_by'),
    Column.text('created_at'),
    Column.text('last_updated_by'),
    Column.text('last_updated_at'),
  ], indexes: [
    // Performance indexes for common queries
    Index('idx_assigned_id', [IndexedColumn('assigned_id')]),
    Index('idx_manager_id', [IndexedColumn('manager_id')]),
    Index('idx_tenant_id', [IndexedColumn('tenant_id')]),
    Index('idx_status', [IndexedColumn('status')]),
    Index('idx_visit_date', [IndexedColumn('visit_date')]),
    Index('idx_visible', [IndexedColumn('visible')]),

    // Composite indexes for role-based queries
    Index('idx_tech_assigned', [
      IndexedColumn('assigned_id'),
      IndexedColumn('visible'),
      IndexedColumn('visit_date'),
    ]),
    Index('idx_manager_tenant', [
      IndexedColumn('manager_id'),
      IndexedColumn('tenant_id'),
      IndexedColumn('visible'),
    ]),
  ]),

  // priceList table
  Table('price_list', [
    Column.text('dept_id'),
    Column.text('dept_name'),
    Column.text('invest_id'),
    Column.text('invest_name'),
    Column.text('rate_card_name'),
    Column.real('base_cost'),
    Column.real('min_cost'),
    Column.real('cghs_price'),
    Column.text('history'),
    Column.text('created_at'),
    Column.text('updated_at'),
    Column.text('last_updated_by'),
    Column.integer('visible'),
  ], indexes: [
    Index('idx_pl_invest_name', [IndexedColumn('invest_name')]),
    Index('idx_pl_dept_name', [IndexedColumn('dept_name')]),
    Index('idx_pl_visible', [IndexedColumn('visible')]),
    Index('idx_pl_search', [
      IndexedColumn('visible'),
      IndexedColumn('invest_name'),
    ]),
  ]),

  Table('temp_uploads', [
    Column.text('work_order_id'),
    Column.text('file_name'),
    Column.text('file_location'),
    Column.text('file_data'), // base64 encoded
    Column.integer('file_size'),
    Column.text('status'), // pending, uploading, completed, failed
    Column.text('error_message'),
    Column.text('created_at'),
    Column.text('uploaded_at'),
    Column.integer('tenant_id'),
    Column.integer('created_by'),
  ], indexes: [
    Index('idx_tu_status', [IndexedColumn('status')]),
    Index('idx_tu_work_order', [IndexedColumn('work_order_id')]),
  ]),
]);
