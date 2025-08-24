-- Jive Money Database Schema
-- Converted from Maybe Rails schema.rb
-- Generated at: 2025-08-23 10:50:33 +0800

-- Enable PostgreSQL extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "plpgsql";

-- Create enum types
CREATE TYPE account_status AS ENUM ('ok', 'syncing', 'error');

-- Tables
CREATE TABLE account_group_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    account_group_id UUID NOT NULL,
    position INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for account_group_memberships
CREATE INDEX idx_on_account_group_id_position_788a538d22 ON account_group_memberships (account_group_id, position);
CREATE INDEX index_account_group_memberships_on_account_group_id ON account_group_memberships (account_group_id);
CREATE UNIQUE INDEX index_account_group_memberships_unique ON account_group_memberships (account_id, account_group_id);
CREATE INDEX index_account_group_memberships_on_account_id ON account_group_memberships (account_id);

CREATE TABLE account_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    position INTEGER NOT NULL DEFAULT 0,
    color VARCHAR(255) DEFAULT '#3B82F6',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for account_groups
CREATE UNIQUE INDEX index_account_groups_on_family_id_and_name ON account_groups (family_id, name);
CREATE INDEX index_account_groups_on_family_id_and_position ON account_groups (family_id, position);
CREATE INDEX index_account_groups_on_family_id ON account_groups (family_id);

CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subtype VARCHAR(255),
    family_id UUID NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    accountable_type VARCHAR(255),
    accountable_id UUID,
    balance DECIMAL(19, 4),
    currency VARCHAR(255),
    import_id UUID,
    plaid_account_id UUID,
    cash_balance DECIMAL(19, 4) DEFAULT '0.0',
    locked_attributes JSONB DEFAULT '{}',
    status VARCHAR(255) DEFAULT 'active',
    balance_currency VARCHAR(255),
    description TEXT,
    include_in_net_worth BOOLEAN NOT NULL DEFAULT TRUE
);

-- Indexes for accounts
CREATE INDEX index_accounts_on_accountable_id_and_accountable_type ON accounts (accountable_id, accountable_type);
CREATE INDEX index_accounts_on_accountable_type ON accounts (accountable_type);
CREATE INDEX index_accounts_on_balance_currency ON accounts (balance_currency);
CREATE INDEX index_accounts_on_family_id_and_accountable_type ON accounts (family_id, accountable_type);
CREATE INDEX index_accounts_on_family_id_and_id ON accounts (family_id, id);
CREATE INDEX index_accounts_on_family_id ON accounts (family_id);
CREATE INDEX index_accounts_on_import_id ON accounts (import_id);
CREATE INDEX index_accounts_on_include_in_net_worth ON accounts (include_in_net_worth);
CREATE INDEX index_accounts_on_plaid_account_id ON accounts (plaid_account_id);

CREATE TABLE active_storage_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    record_type VARCHAR(255) NOT NULL,
    record_id UUID NOT NULL,
    blob_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for active_storage_attachments
CREATE INDEX index_active_storage_attachments_on_blob_id ON active_storage_attachments (blob_id);
CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON active_storage_attachments (record_type, record_id, name, blob_id);

CREATE TABLE active_storage_blobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(255) NOT NULL,
    filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(255),
    metadata TEXT,
    service_name VARCHAR(255) NOT NULL,
    byte_size BIGINT NOT NULL,
    checksum VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for active_storage_blobs
CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON active_storage_blobs (key);

CREATE TABLE active_storage_variant_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blob_id UUID NOT NULL,
    variation_digest VARCHAR(255) NOT NULL
);

-- Indexes for active_storage_variant_records
CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON active_storage_variant_records (blob_id, variation_digest);

CREATE TABLE addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    addressable_type VARCHAR(255),
    addressable_id UUID,
    line1 VARCHAR(255),
    line2 VARCHAR(255),
    county VARCHAR(255),
    locality VARCHAR(255),
    region VARCHAR(255),
    country VARCHAR(255),
    postal_code INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for addresses
CREATE INDEX index_addresses_on_addressable ON addresses (addressable_type, addressable_id);

CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255),
    user_id UUID NOT NULL,
    scopes JSON,
    last_used_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    display_key VARCHAR(255) NOT NULL,
    source VARCHAR(255) DEFAULT 'web'
);

-- Indexes for api_keys
CREATE UNIQUE INDEX index_api_keys_on_display_key ON api_keys (display_key);
CREATE INDEX index_api_keys_on_revoked_at ON api_keys (revoked_at);
CREATE INDEX index_api_keys_on_user_id_and_source ON api_keys (user_id, source);
CREATE INDEX index_api_keys_on_user_id ON api_keys (user_id);

CREATE TABLE auto_skip_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scheduled_transaction_id UUID NOT NULL,
    target_date DATE,
    skipped BOOLEAN DEFAULT FALSE,
    reason TEXT,
    similar_transactions_count INTEGER DEFAULT 0,
    matching_transactions JSON,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for auto_skip_logs
CREATE INDEX idx_on_scheduled_transaction_id_target_date_aad8297302 ON auto_skip_logs (scheduled_transaction_id, target_date);
CREATE INDEX index_auto_skip_logs_on_scheduled_transaction_id ON auto_skip_logs (scheduled_transaction_id);
CREATE INDEX index_auto_skip_logs_on_skipped ON auto_skip_logs (skipped);
CREATE INDEX index_auto_skip_logs_on_target_date ON auto_skip_logs (target_date);

CREATE TABLE balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    date DATE NOT NULL,
    balance DECIMAL(19, 4) NOT NULL,
    currency VARCHAR(255) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    cash_balance DECIMAL(19, 4) DEFAULT '0.0'
);

-- Indexes for balances
CREATE UNIQUE INDEX index_account_balances_on_account_id_date_currency_unique ON balances (account_id, date, currency);
CREATE INDEX index_balances_on_account_id ON balances (account_id);

CREATE TABLE budget_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL,
    category_id UUID NOT NULL,
    budgeted_spending DECIMAL(19, 4) NOT NULL,
    currency VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for budget_categories
CREATE UNIQUE INDEX index_budget_categories_on_budget_id_and_category_id ON budget_categories (budget_id, category_id);
CREATE INDEX index_budget_categories_on_budget_id ON budget_categories (budget_id);
CREATE INDEX index_budget_categories_on_category_id ON budget_categories (category_id);

CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    budgeted_spending DECIMAL(19, 4),
    expected_income DECIMAL(19, 4),
    currency VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ledger_id UUID
);

-- Indexes for budgets
CREATE UNIQUE INDEX index_budgets_on_family_id_and_start_date_and_end_date ON budgets (family_id, start_date, end_date);
CREATE INDEX index_budgets_on_family_id ON budgets (family_id);
CREATE INDEX index_budgets_on_ledger_id ON budgets (ledger_id);

CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    color VARCHAR(255) NOT NULL DEFAULT '#6172F3',
    family_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    parent_id UUID,
    classification VARCHAR(255) NOT NULL DEFAULT 'expense',
    lucide_icon VARCHAR(255) NOT NULL DEFAULT 'shapes',
    position INTEGER,
    ledger_id UUID
);

-- Indexes for categories
CREATE INDEX index_categories_on_family_id ON categories (family_id);
CREATE INDEX index_categories_on_ledger_id ON categories (ledger_id);
CREATE INDEX index_categories_on_position ON categories (position);

CREATE TABLE category_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for category_groups
CREATE INDEX index_category_groups_on_display_order ON category_groups (display_order);
CREATE INDEX index_category_groups_on_is_active ON category_groups (is_active);
CREATE UNIQUE INDEX index_category_groups_on_key ON category_groups (key);

CREATE TABLE category_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    color VARCHAR(255) NOT NULL,
    lucide_icon VARCHAR(255) NOT NULL DEFAULT 'tag',
    classification VARCHAR(255) NOT NULL,
    group_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE,
    brand_logo_url VARCHAR(255),
    use_brand_logo BOOLEAN DEFAULT FALSE
);

-- Indexes for category_templates
CREATE INDEX index_category_templates_on_classification ON category_templates (classification);
CREATE INDEX index_category_templates_on_deleted_at ON category_templates (deleted_at);
CREATE INDEX index_category_templates_on_group_name ON category_templates (group_name);
CREATE INDEX index_category_templates_on_is_active ON category_templates (is_active);
CREATE INDEX index_category_templates_on_name ON category_templates (name);
CREATE INDEX index_category_templates_on_use_brand_logo ON category_templates (use_brand_logo);

CREATE TABLE chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title VARCHAR(255) NOT NULL,
    instructions VARCHAR(255),
    error JSONB,
    latest_assistant_response_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for chats
CREATE INDEX index_chats_on_user_id ON chats (user_id);

CREATE TABLE cloud_sync_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    provider VARCHAR(255) NOT NULL,
    access_token TEXT,
    refresh_token TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    enabled BOOLEAN DEFAULT FALSE,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    sync_settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for cloud_sync_configs
CREATE INDEX index_cloud_sync_configs_on_enabled ON cloud_sync_configs (enabled);
CREATE UNIQUE INDEX index_cloud_sync_configs_on_family_id_and_provider ON cloud_sync_configs (family_id, provider);
CREATE INDEX index_cloud_sync_configs_on_family_id ON cloud_sync_configs (family_id);

CREATE TABLE credit_card_foreign_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    credit_card_id UUID NOT NULL,
    currency VARCHAR(255) NOT NULL,
    balance DECIMAL(19, 4) DEFAULT '0.0',
    exchange_rate DECIMAL(19, 6),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for credit_card_foreign_balances
CREATE UNIQUE INDEX index_foreign_balances_on_card_and_currency ON credit_card_foreign_balances (credit_card_id, currency);
CREATE INDEX index_credit_card_foreign_balances_on_credit_card_id ON credit_card_foreign_balances (credit_card_id);

CREATE TABLE credit_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    available_credit DECIMAL(10, 2),
    minimum_payment DECIMAL(10, 2),
    apr DECIMAL(10, 2),
    expiration_date DATE,
    annual_fee DECIMAL(10, 2),
    locked_attributes JSONB DEFAULT '{}',
    bill_date INTEGER,
    payment_date INTEGER,
    credit_limit DECIMAL(19, 4),
    rewards_rate DECIMAL(5, 4),
    foreign_currency VARCHAR(255),
    foreign_balance DECIMAL(15, 2) DEFAULT '0.0',
    exchange_rate DECIMAL(10, 6) DEFAULT '1.0',
    currency_conversion_fee DECIMAL(5, 4) DEFAULT '0.0',
    auto_convert_currency BOOLEAN DEFAULT TRUE,
    last_exchange_rate_update TIMESTAMP WITH TIME ZONE,
    bank_name VARCHAR(255),
    bank_code VARCHAR(255),
    credit_limit_type VARCHAR(255) DEFAULT 'individual',
    shared_limit_group_id VARCHAR(255),
    shared_limit_total DECIMAL(19, 4),
    payment_date_type VARCHAR(255) DEFAULT 'fixed_date',
    payment_days_after_bill INTEGER,
    bill_calculation_in_previous_period BOOLEAN DEFAULT FALSE,
    is_multi_currency_card BOOLEAN DEFAULT FALSE
);

-- Indexes for credit_cards
CREATE INDEX index_credit_cards_on_bank_code ON credit_cards (bank_code);
CREATE INDEX index_credit_cards_on_shared_limit_group_id ON credit_cards (shared_limit_group_id);

CREATE TABLE cryptos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    locked_attributes JSONB DEFAULT '{}'
);

CREATE TABLE data_enrichments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    enrichable_type VARCHAR(255) NOT NULL,
    enrichable_id UUID NOT NULL,
    source VARCHAR(255),
    attribute_name VARCHAR(255),
    value JSONB,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for data_enrichments
CREATE UNIQUE INDEX idx_on_enrichable_id_enrichable_type_source_attribu_5be5f63e08 ON data_enrichments (enrichable_id, enrichable_type, source, attribute_name);
CREATE INDEX index_data_enrichments_on_enrichable ON data_enrichments (enrichable_type, enrichable_id);

CREATE TABLE depositories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    locked_attributes JSONB DEFAULT '{}',
    bank_code VARCHAR(255),
    bank_name VARCHAR(255),
    maturity_date DATE,
    maturity_amount DECIMAL(19, 4)
);

-- Indexes for depositories
CREATE INDEX index_depositories_on_bank_code ON depositories (bank_code);

CREATE TABLE entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    entryable_type VARCHAR(255),
    entryable_id UUID,
    amount DECIMAL(19, 4) NOT NULL,
    currency VARCHAR(255),
    date DATE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    import_id UUID,
    notes TEXT,
    excluded BOOLEAN DEFAULT FALSE,
    plaid_id VARCHAR(255),
    locked_attributes JSONB DEFAULT '{}',
    nature VARCHAR(255) DEFAULT 'outflow'
);

-- Indexes for entries
CREATE INDEX index_entries_on_account_id ON entries (account_id);
CREATE INDEX index_entries_on_import_id ON entries (import_id);
CREATE INDEX index_entries_on_nature ON entries (nature);

CREATE TABLE exchange_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_currency VARCHAR(255) NOT NULL,
    to_currency VARCHAR(255) NOT NULL,
    rate DECIMAL NOT NULL,
    date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for exchange_rates
CREATE UNIQUE INDEX index_exchange_rates_on_base_converted_date_unique ON exchange_rates (from_currency, to_currency, date);
CREATE INDEX index_exchange_rates_on_from_currency ON exchange_rates (from_currency);
CREATE INDEX index_exchange_rates_on_to_currency ON exchange_rates (to_currency);

CREATE TABLE export_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    user_id UUID NOT NULL,
    format VARCHAR(255) NOT NULL,
    date_range JSONB NOT NULL,
    filters JSONB DEFAULT '{}',
    file_name VARCHAR(255),
    file_size INTEGER,
    record_count INTEGER,
    download_url TEXT,
    download_count INTEGER DEFAULT 0,
    expires_at TIMESTAMP WITH TIME ZONE,
    last_downloaded_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for export_logs
CREATE INDEX index_export_logs_on_expires_at ON export_logs (expires_at);
CREATE INDEX index_export_logs_on_family_id_and_created_at ON export_logs (family_id, created_at);
CREATE INDEX index_export_logs_on_format ON export_logs (format);
CREATE INDEX index_export_logs_on_user_id_and_created_at ON export_logs (user_id, created_at);

CREATE TABLE families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    currency VARCHAR(255) DEFAULT 'USD',
    locale VARCHAR(255) DEFAULT 'en',
    stripe_customer_id VARCHAR(255),
    date_format VARCHAR(255) DEFAULT '%m-%d-%Y',
    country VARCHAR(255) DEFAULT 'US',
    timezone VARCHAR(255),
    data_enrichment_enabled BOOLEAN DEFAULT FALSE,
    early_access BOOLEAN DEFAULT FALSE,
    auto_sync_on_login BOOLEAN NOT NULL DEFAULT TRUE,
    latest_sync_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    latest_sync_completed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    currency_preferences JSONB NOT NULL DEFAULT '{}',
    enable_payees BOOLEAN DEFAULT FALSE,
    auto_associate_payee_category BOOLEAN DEFAULT FALSE,
    use_last_selected_category BOOLEAN DEFAULT FALSE,
    last_selected_category_id UUID,
    remember_last_account BOOLEAN DEFAULT FALSE,
    remember_most_used_account BOOLEAN DEFAULT FALSE,
    remember_last_category BOOLEAN DEFAULT FALSE,
    remember_most_used_category BOOLEAN DEFAULT FALSE,
    last_used_account_id UUID,
    last_used_category_id UUID
);

-- Indexes for families
CREATE INDEX index_families_on_currency_preferences ON families (currency_preferences);

CREATE TABLE holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    security_id UUID NOT NULL,
    date DATE NOT NULL,
    qty DECIMAL(19, 4) NOT NULL,
    price DECIMAL(19, 4) NOT NULL,
    amount DECIMAL(19, 4) NOT NULL,
    currency VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for holdings
CREATE UNIQUE INDEX idx_on_account_id_security_id_date_currency_5323e39f8b ON holdings (account_id, security_id, date, currency);
CREATE INDEX index_holdings_on_account_id ON holdings (account_id);
CREATE INDEX index_holdings_on_security_id ON holdings (security_id);

CREATE TABLE impersonation_session_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    impersonation_session_id UUID NOT NULL,
    controller VARCHAR(255),
    action VARCHAR(255),
    path TEXT,
    method VARCHAR(255),
    ip_address VARCHAR(255),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for impersonation_session_logs
CREATE INDEX index_impersonation_session_logs_on_impersonation_session_id ON impersonation_session_logs (impersonation_session_id);

CREATE TABLE impersonation_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    impersonator_id UUID NOT NULL,
    impersonated_id UUID NOT NULL,
    status VARCHAR(255) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for impersonation_sessions
CREATE INDEX index_impersonation_sessions_on_impersonated_id ON impersonation_sessions (impersonated_id);
CREATE INDEX index_impersonation_sessions_on_impersonator_id ON impersonation_sessions (impersonator_id);

CREATE TABLE import_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type VARCHAR(255) NOT NULL,
    key VARCHAR(255),
    value VARCHAR(255),
    create_when_empty BOOLEAN DEFAULT TRUE,
    import_id UUID NOT NULL,
    mappable_type VARCHAR(255),
    mappable_id UUID,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for import_mappings
CREATE INDEX index_import_mappings_on_import_id ON import_mappings (import_id);
CREATE INDEX index_import_mappings_on_mappable ON import_mappings (mappable_type, mappable_id);

CREATE TABLE import_rows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    import_id UUID NOT NULL,
    account VARCHAR(255),
    date VARCHAR(255),
    qty VARCHAR(255),
    ticker VARCHAR(255),
    price VARCHAR(255),
    amount VARCHAR(255),
    currency VARCHAR(255),
    name VARCHAR(255),
    category VARCHAR(255),
    tags VARCHAR(255),
    entity_type VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    exchange_operating_mic VARCHAR(255)
);

-- Indexes for import_rows
CREATE INDEX index_import_rows_on_import_id ON import_rows (import_id);

CREATE TABLE imports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    column_mappings JSONB,
    status VARCHAR(255),
    raw_file_str VARCHAR(255),
    normalized_csv_str VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    col_sep VARCHAR(255) DEFAULT ',',
    family_id UUID NOT NULL,
    account_id UUID,
    type VARCHAR(255) NOT NULL,
    date_col_label VARCHAR(255),
    amount_col_label VARCHAR(255),
    name_col_label VARCHAR(255),
    category_col_label VARCHAR(255),
    tags_col_label VARCHAR(255),
    account_col_label VARCHAR(255),
    qty_col_label VARCHAR(255),
    ticker_col_label VARCHAR(255),
    price_col_label VARCHAR(255),
    entity_type_col_label VARCHAR(255),
    notes_col_label VARCHAR(255),
    currency_col_label VARCHAR(255),
    date_format VARCHAR(255) DEFAULT '%m/%d/%Y',
    signage_convention VARCHAR(255) DEFAULT 'inflows_positive',
    error VARCHAR(255),
    number_format VARCHAR(255),
    exchange_operating_mic_col_label VARCHAR(255),
    amount_type_strategy VARCHAR(255) DEFAULT 'signed_amount',
    amount_type_inflow_value VARCHAR(255)
);

-- Indexes for imports
CREATE INDEX index_imports_on_family_id ON imports (family_id);

CREATE TABLE investments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    locked_attributes JSONB DEFAULT '{}'
);

CREATE TABLE invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255),
    role VARCHAR(255),
    token VARCHAR(255),
    family_id UUID NOT NULL,
    inviter_id UUID NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for invitations
CREATE UNIQUE INDEX index_invitations_on_email_and_family_id ON invitations (email, family_id);
CREATE INDEX index_invitations_on_email ON invitations (email);
CREATE INDEX index_invitations_on_family_id ON invitations (family_id);
CREATE INDEX index_invitations_on_inviter_id ON invitations (inviter_id);
CREATE UNIQUE INDEX index_invitations_on_token ON invitations (token);

CREATE TABLE invite_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for invite_codes
CREATE UNIQUE INDEX index_invite_codes_on_token ON invite_codes (token);

CREATE TABLE ledger_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL,
    physical_account_id UUID NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    notes TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for ledger_accounts
CREATE INDEX index_ledger_accounts_on_is_active ON ledger_accounts (is_active);
CREATE UNIQUE INDEX idx_ledger_accounts_unique ON ledger_accounts (ledger_id, physical_account_id);
CREATE INDEX index_ledger_accounts_on_ledger_id ON ledger_accounts (ledger_id);
CREATE INDEX index_ledger_accounts_on_physical_account_id ON ledger_accounts (physical_account_id);

CREATE TABLE ledger_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    ledger_type VARCHAR(255) NOT NULL,
    template_data JSON DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    is_system BOOLEAN DEFAULT FALSE,
    created_by_id UUID,
    color VARCHAR(255) DEFAULT '#6366f1',
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for ledger_templates
CREATE INDEX index_ledger_templates_on_created_by_id ON ledger_templates (created_by_id);
CREATE INDEX index_ledger_templates_on_is_system ON ledger_templates (is_system);
CREATE INDEX index_ledger_templates_on_ledger_type_and_is_active ON ledger_templates (ledger_type, is_active);

CREATE TABLE ledger_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    from_ledger_id UUID NOT NULL,
    to_ledger_id UUID NOT NULL,
    from_account_id UUID NOT NULL,
    to_account_id UUID NOT NULL,
    created_by_id UUID NOT NULL,
    amount_cents BIGINT NOT NULL,
    currency VARCHAR(255) NOT NULL DEFAULT 'USD',
    description TEXT NOT NULL,
    transfer_date DATE NOT NULL,
    reference_number VARCHAR(255) NOT NULL,
    status VARCHAR(255) NOT NULL DEFAULT 'pending',
    transfer_type VARCHAR(255) NOT NULL DEFAULT 'settlement',
    confirmed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for ledger_transfers
CREATE INDEX index_ledger_transfers_on_created_by_id ON ledger_transfers (created_by_id);
CREATE INDEX index_ledger_transfers_on_family_id_and_transfer_date ON ledger_transfers (family_id, transfer_date);
CREATE INDEX index_ledger_transfers_on_family_id ON ledger_transfers (family_id);
CREATE INDEX index_ledger_transfers_on_from_account_id ON ledger_transfers (from_account_id);
CREATE INDEX index_ledger_transfers_on_from_ledger_id_and_to_ledger_id ON ledger_transfers (from_ledger_id, to_ledger_id);
CREATE INDEX index_ledger_transfers_on_from_ledger_id ON ledger_transfers (from_ledger_id);
CREATE UNIQUE INDEX index_ledger_transfers_on_reference_number ON ledger_transfers (reference_number);
CREATE INDEX index_ledger_transfers_on_status_and_transfer_date ON ledger_transfers (status, transfer_date);
CREATE INDEX index_ledger_transfers_on_to_account_id ON ledger_transfers (to_account_id);
CREATE INDEX index_ledger_transfers_on_to_ledger_id ON ledger_transfers (to_ledger_id);
CREATE INDEX index_ledger_transfers_on_transfer_type ON ledger_transfers (transfer_type);

CREATE TABLE ledgers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color VARCHAR(255) DEFAULT '#3B82F6',
    is_default BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    ledger_type VARCHAR(255) DEFAULT 'personal',
    is_hidden BOOLEAN DEFAULT FALSE,
    cover_image_url VARCHAR(255),
    hide_all_categories BOOLEAN NOT NULL DEFAULT FALSE,
    show_transfer_flows BOOLEAN NOT NULL DEFAULT TRUE,
    show_investment_flows BOOLEAN NOT NULL DEFAULT TRUE
);

-- Indexes for ledgers
CREATE INDEX index_ledgers_on_family_id_and_is_default ON ledgers (family_id, is_default);
CREATE UNIQUE INDEX index_ledgers_on_family_id_and_name ON ledgers (family_id, name);
CREATE INDEX index_ledgers_on_family_id ON ledgers (family_id);
CREATE INDEX index_ledgers_on_is_hidden ON ledgers (is_hidden);
CREATE INDEX index_ledgers_on_ledger_type ON ledgers (ledger_type);

CREATE TABLE loans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    rate_type VARCHAR(255),
    interest_rate DECIMAL(10, 3),
    term_months INTEGER,
    initial_balance DECIMAL(19, 4),
    locked_attributes JSONB DEFAULT '{}'
);

CREATE TABLE merchant_category_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    category_id UUID,
    hits_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    payee_id BIGINT
);

-- Indexes for merchant_category_preferences
CREATE INDEX index_merchant_category_preferences_on_category_id ON merchant_category_preferences (category_id);
CREATE UNIQUE INDEX idx_on_family_id_payee_id ON merchant_category_preferences (family_id, payee_id);
CREATE INDEX index_merchant_category_preferences_on_family_id ON merchant_category_preferences (family_id);
CREATE INDEX index_merchant_category_preferences_on_payee_id ON merchant_category_preferences (payee_id);

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID NOT NULL,
    type VARCHAR(255) NOT NULL,
    status VARCHAR(255) NOT NULL DEFAULT 'complete',
    content TEXT,
    ai_model VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    debug BOOLEAN DEFAULT FALSE,
    provider_id VARCHAR(255),
    reasoning BOOLEAN DEFAULT FALSE
);

-- Indexes for messages
CREATE INDEX index_messages_on_chat_id ON messages (chat_id);

CREATE TABLE mobile_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    device_id VARCHAR(255),
    device_name VARCHAR(255),
    device_type VARCHAR(255),
    os_version VARCHAR(255),
    app_version VARCHAR(255),
    last_seen_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    oauth_application_id INTEGER
);

-- Indexes for mobile_devices
CREATE INDEX index_mobile_devices_on_oauth_application_id ON mobile_devices (oauth_application_id);
CREATE UNIQUE INDEX index_mobile_devices_on_user_id_and_device_id ON mobile_devices (user_id, device_id);
CREATE INDEX index_mobile_devices_on_user_id ON mobile_devices (user_id);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    notification_type VARCHAR(255) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB DEFAULT '{}',
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for notifications
CREATE INDEX index_notifications_on_family_id_and_notification_type ON notifications (family_id, notification_type);
CREATE INDEX index_notifications_on_family_id_and_read_at ON notifications (family_id, read_at);
CREATE INDEX index_notifications_on_family_id ON notifications (family_id);
CREATE INDEX index_notifications_on_notification_type ON notifications (notification_type);
CREATE INDEX index_notifications_on_read_at ON notifications (read_at);

CREATE TABLE oauth_access_grants (
    id BIGSERIAL PRIMARY KEY,
    resource_owner_id VARCHAR(255) NOT NULL,
    application_id BIGINT NOT NULL,
    token VARCHAR(255) NOT NULL,
    expires_in INTEGER NOT NULL,
    redirect_uri TEXT NOT NULL,
    scopes VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for oauth_access_grants
CREATE INDEX index_oauth_access_grants_on_application_id ON oauth_access_grants (application_id);
CREATE INDEX index_oauth_access_grants_on_resource_owner_id ON oauth_access_grants (resource_owner_id);
CREATE UNIQUE INDEX index_oauth_access_grants_on_token ON oauth_access_grants (token);

CREATE TABLE oauth_access_tokens (
    id BIGSERIAL PRIMARY KEY,
    resource_owner_id VARCHAR(255),
    application_id BIGINT NOT NULL,
    token VARCHAR(255) NOT NULL,
    refresh_token VARCHAR(255),
    expires_in INTEGER,
    scopes VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE,
    previous_refresh_token VARCHAR(255) NOT NULL
);

-- Indexes for oauth_access_tokens
CREATE INDEX index_oauth_access_tokens_on_application_id ON oauth_access_tokens (application_id);
CREATE UNIQUE INDEX index_oauth_access_tokens_on_refresh_token ON oauth_access_tokens (refresh_token);
CREATE INDEX index_oauth_access_tokens_on_resource_owner_id ON oauth_access_tokens (resource_owner_id);
CREATE UNIQUE INDEX index_oauth_access_tokens_on_token ON oauth_access_tokens (token);

CREATE TABLE oauth_applications (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    uid VARCHAR(255) NOT NULL,
    secret VARCHAR(255) NOT NULL,
    redirect_uri TEXT NOT NULL,
    scopes VARCHAR(255) NOT NULL,
    confidential BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    owner_id UUID,
    owner_type VARCHAR(255)
);

-- Indexes for oauth_applications
CREATE INDEX index_oauth_applications_on_owner_id_and_owner_type ON oauth_applications (owner_id, owner_type);
CREATE UNIQUE INDEX index_oauth_applications_on_uid ON oauth_applications (uid);

CREATE TABLE other_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    locked_attributes JSONB DEFAULT '{}'
);

CREATE TABLE other_liabilities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    locked_attributes JSONB DEFAULT '{}'
);

CREATE TABLE payee_categories (
    id BIGSERIAL PRIMARY KEY,
    payee_id BIGINT NOT NULL,
    category_id UUID NOT NULL,
    auto_assigned BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for payee_categories
CREATE INDEX index_payee_categories_on_category_id ON payee_categories (category_id);
CREATE UNIQUE INDEX index_payee_categories_on_payee_id_and_category_id ON payee_categories (payee_id, category_id);
CREATE INDEX index_payee_categories_on_payee_id ON payee_categories (payee_id);

CREATE TABLE payees (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    family_id UUID NOT NULL,
    transactions_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    color VARCHAR(255),
    logo_url VARCHAR(255),
    website_url VARCHAR(255),
    payee_type VARCHAR(255),
    source VARCHAR(255),
    provider_merchant_id UUID,
    position INTEGER DEFAULT 0
);

-- Indexes for payees
CREATE UNIQUE INDEX index_payees_on_family_id_and_name ON payees (family_id, name);
CREATE INDEX index_payees_on_family_id ON payees (family_id);
CREATE INDEX index_payees_on_payee_type ON payees (payee_type);
CREATE INDEX index_payees_on_position ON payees (position);
CREATE INDEX index_payees_on_provider_merchant_id ON payees (provider_merchant_id);
CREATE INDEX index_payees_on_source ON payees (source);

CREATE TABLE plaid_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plaid_item_id UUID NOT NULL,
    plaid_id VARCHAR(255) NOT NULL,
    plaid_type VARCHAR(255) NOT NULL,
    plaid_subtype VARCHAR(255),
    current_balance DECIMAL(19, 4),
    available_balance DECIMAL(19, 4),
    currency VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    mask VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    raw_payload JSONB DEFAULT '{}',
    raw_transactions_payload JSONB DEFAULT '{}',
    raw_investments_payload JSONB DEFAULT '{}',
    raw_liabilities_payload JSONB DEFAULT '{}'
);

-- Indexes for plaid_accounts
CREATE UNIQUE INDEX index_plaid_accounts_on_plaid_id ON plaid_accounts (plaid_id);
CREATE INDEX index_plaid_accounts_on_plaid_item_id ON plaid_accounts (plaid_item_id);

CREATE TABLE plaid_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    access_token VARCHAR(255),
    plaid_id VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    next_cursor VARCHAR(255),
    scheduled_for_deletion BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    available_products VARCHAR(255),
    billed_products VARCHAR(255),
    plaid_region VARCHAR(255) NOT NULL DEFAULT 'us',
    institution_url VARCHAR(255),
    institution_id VARCHAR(255),
    institution_color VARCHAR(255),
    status VARCHAR(255) NOT NULL DEFAULT 'good',
    raw_payload JSONB DEFAULT '{}',
    raw_institution_payload JSONB DEFAULT '{}'
);

-- Indexes for plaid_items
CREATE INDEX index_plaid_items_on_family_id ON plaid_items (family_id);
CREATE UNIQUE INDEX index_plaid_items_on_plaid_id ON plaid_items (plaid_id);

CREATE TABLE prepaid_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subtype VARCHAR(255),
    recharge_amount DECIMAL(19, 4),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for prepaid_cards
CREATE INDEX index_prepaid_cards_on_subtype ON prepaid_cards (subtype);

CREATE TABLE properties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    year_built INTEGER,
    area_value INTEGER,
    area_unit VARCHAR(255),
    locked_attributes JSONB DEFAULT '{}'
);

CREATE TABLE quick_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    account_id UUID NOT NULL,
    category_id UUID,
    amount DECIMAL(19, 4) NOT NULL,
    transaction_type VARCHAR(255) NOT NULL,
    description TEXT,
    notes TEXT,
    is_reimbursable BOOLEAN DEFAULT FALSE,
    tags TEXT,
    coupon_amount DECIMAL(19, 4) DEFAULT '0.0',
    fee_amount DECIMAL(19, 4) DEFAULT '0.0',
    attachments TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id UUID,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payee_id BIGINT
);

-- Indexes for quick_transactions
CREATE INDEX index_quick_transactions_on_family_id_and_created_at ON quick_transactions (family_id, created_at);
CREATE INDEX index_quick_transactions_on_payee_id ON quick_transactions (payee_id);
CREATE INDEX index_quick_transactions_on_tags ON quick_transactions (tags);
CREATE INDEX index_quick_transactions_on_transaction_type ON quick_transactions (transaction_type);

CREATE TABLE reimbursement_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    name VARCHAR(255),
    description TEXT,
    total_amount DECIMAL,
    status VARCHAR(255),
    submitted_at TIMESTAMP WITH TIME ZONE,
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for reimbursement_batches
CREATE INDEX index_reimbursement_batches_on_family_id ON reimbursement_batches (family_id);

CREATE TABLE rejected_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inflow_transaction_id UUID NOT NULL,
    outflow_transaction_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for rejected_transfers
CREATE UNIQUE INDEX idx_on_inflow_transaction_id_outflow_transaction_id_412f8e7e26 ON rejected_transfers (inflow_transaction_id, outflow_transaction_id);
CREATE INDEX index_rejected_transfers_on_inflow_transaction_id ON rejected_transfers (inflow_transaction_id);
CREATE INDEX index_rejected_transfers_on_outflow_transaction_id ON rejected_transfers (outflow_transaction_id);

CREATE TABLE rule_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL,
    action_type VARCHAR(255) NOT NULL,
    value VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for rule_actions
CREATE INDEX index_rule_actions_on_rule_id ON rule_actions (rule_id);

CREATE TABLE rule_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID,
    parent_id UUID,
    condition_type VARCHAR(255) NOT NULL,
    operator VARCHAR(255) NOT NULL,
    value VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for rule_conditions
CREATE INDEX index_rule_conditions_on_parent_id ON rule_conditions (parent_id);
CREATE INDEX index_rule_conditions_on_rule_id ON rule_conditions (rule_id);

CREATE TABLE rule_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL,
    transaction_id UUID NOT NULL,
    attribute_name VARCHAR(255) NOT NULL,
    old_value TEXT,
    new_value TEXT,
    modification_type VARCHAR(255) NOT NULL,
    batch_id UUID,
    executed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    rule_description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for rule_logs
CREATE INDEX index_rule_logs_on_batch_id ON rule_logs (batch_id);
CREATE INDEX index_rule_logs_on_executed_at ON rule_logs (executed_at);
CREATE INDEX index_rule_logs_on_rule_id ON rule_logs (rule_id);
CREATE INDEX index_rule_logs_on_transaction_id_and_attribute_name ON rule_logs (transaction_id, attribute_name);
CREATE INDEX index_rule_logs_on_transaction_id ON rule_logs (transaction_id);

CREATE TABLE rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    resource_type VARCHAR(255) NOT NULL,
    effective_date DATE,
    active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    name VARCHAR(255)
);

-- Indexes for rules
CREATE INDEX index_rules_on_family_id ON rules (family_id);

CREATE TABLE scheduled_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    account_id UUID NOT NULL,
    category_id UUID,
    payee_id BIGINT,
    name VARCHAR(255) NOT NULL,
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(255) NOT NULL DEFAULT 'USD',
    transaction_type VARCHAR(255) NOT NULL DEFAULT 'expense',
    notes TEXT,
    start_date DATE NOT NULL,
    frequency_type VARCHAR(255) NOT NULL DEFAULT 'monthly',
    frequency_value INTEGER DEFAULT 1,
    custom_frequency_unit VARCHAR(255),
    monthly_day_type VARCHAR(255),
    monthly_day INTEGER,
    monthly_week_number INTEGER,
    monthly_weekday INTEGER,
    end_condition VARCHAR(255) NOT NULL DEFAULT 'never',
    end_date DATE,
    end_count INTEGER,
    auto_pay BOOLEAN DEFAULT FALSE,
    auto_skip BOOLEAN DEFAULT FALSE,
    is_paused BOOLEAN DEFAULT FALSE,
    next_due_date DATE,
    last_executed_at TIMESTAMP WITH TIME ZONE,
    execution_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_error TEXT,
    last_error_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for scheduled_transactions
CREATE INDEX index_scheduled_transactions_on_account_id_and_frequency_type ON scheduled_transactions (account_id, frequency_type);
CREATE INDEX index_scheduled_transactions_on_account_id ON scheduled_transactions (account_id);
CREATE INDEX index_scheduled_transactions_on_auto_pay_and_next_due_date ON scheduled_transactions (auto_pay, next_due_date);
CREATE INDEX index_scheduled_transactions_on_auto_skip_and_next_due_date ON scheduled_transactions (auto_skip, next_due_date);
CREATE INDEX index_scheduled_transactions_on_category_id ON scheduled_transactions (category_id);
CREATE INDEX index_scheduled_transactions_on_family_id_and_next_due_date ON scheduled_transactions (family_id, next_due_date);
CREATE INDEX index_scheduled_transactions_on_family_id ON scheduled_transactions (family_id);
CREATE INDEX index_scheduled_transactions_on_next_due_date ON scheduled_transactions (next_due_date);
CREATE INDEX index_scheduled_transactions_on_payee_id ON scheduled_transactions (payee_id);

CREATE TABLE securities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticker VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    country_code VARCHAR(255),
    exchange_mic VARCHAR(255),
    exchange_acronym VARCHAR(255),
    logo_url VARCHAR(255),
    exchange_operating_mic VARCHAR(255),
    offline BOOLEAN NOT NULL DEFAULT FALSE,
    failed_fetch_at TIMESTAMP WITH TIME ZONE,
    failed_fetch_count INTEGER NOT NULL DEFAULT 0,
    last_health_check_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for securities
CREATE INDEX index_securities_on_country_code ON securities (country_code);
CREATE INDEX index_securities_on_exchange_operating_mic ON securities (exchange_operating_mic);

CREATE TABLE security_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL,
    price DECIMAL(19, 4) NOT NULL,
    currency VARCHAR(255) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    security_id UUID
);

-- Indexes for security_prices
CREATE UNIQUE INDEX index_security_prices_on_security_id_and_date_and_currency ON security_prices (security_id, date, currency);
CREATE INDEX index_security_prices_on_security_id ON security_prices (security_id);

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    user_agent VARCHAR(255),
    ip_address VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    active_impersonator_session_id UUID,
    subscribed_at TIMESTAMP WITH TIME ZONE,
    prev_transaction_page_params JSONB DEFAULT '{}',
    data JSONB DEFAULT '{}'
);

-- Indexes for sessions
CREATE INDEX index_sessions_on_active_impersonator_session_id ON sessions (active_impersonator_session_id);
CREATE INDEX index_sessions_on_user_id ON sessions (user_id);

CREATE TABLE settings (
    id BIGSERIAL PRIMARY KEY,
    var VARCHAR(255) NOT NULL,
    value TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for settings
CREATE UNIQUE INDEX index_settings_on_var ON settings (var);

CREATE TABLE subscription_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL,
    family_id UUID NOT NULL,
    event_type VARCHAR(255) NOT NULL,
    from_tier VARCHAR(255),
    to_tier VARCHAR(255),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for subscription_events
CREATE INDEX index_subscription_events_on_event_type ON subscription_events (event_type);
CREATE INDEX index_subscription_events_on_family_id_and_created_at ON subscription_events (family_id, created_at);
CREATE INDEX index_subscription_events_on_subscription_id_and_created_at ON subscription_events (subscription_id, created_at);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    status VARCHAR(255) NOT NULL,
    stripe_id VARCHAR(255),
    amount DECIMAL(19, 4),
    currency VARCHAR(255),
    interval VARCHAR(255),
    current_period_ends_at TIMESTAMP WITH TIME ZONE,
    trial_ends_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    tier VARCHAR(255) NOT NULL DEFAULT 'free',
    billing_period VARCHAR(255),
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    trial_end TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    payment_method JSONB DEFAULT '{}',
    payment_provider VARCHAR(255),
    provider_subscription_id VARCHAR(255),
    provider_customer_id VARCHAR(255),
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    cancel_reason TEXT,
    metadata JSONB DEFAULT '{}'
);

-- Indexes for subscriptions
CREATE INDEX index_subscriptions_on_current_period_end ON subscriptions (current_period_end);
CREATE INDEX index_subscriptions_on_family_id_and_status ON subscriptions (family_id, status);
CREATE UNIQUE INDEX index_subscriptions_on_family_id ON subscriptions (family_id);
CREATE INDEX index_subscriptions_on_provider_subscription_id ON subscriptions (provider_subscription_id);
CREATE INDEX index_subscriptions_on_tier ON subscriptions (tier);

CREATE TABLE syncs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    syncable_type VARCHAR(255) NOT NULL,
    syncable_id UUID NOT NULL,
    status VARCHAR(255) DEFAULT 'pending',
    error VARCHAR(255),
    data JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    parent_id UUID,
    pending_at TIMESTAMP WITH TIME ZONE,
    syncing_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,
    window_start_date DATE,
    window_end_date DATE
);

-- Indexes for syncs
CREATE INDEX index_syncs_on_parent_id ON syncs (parent_id);
CREATE INDEX index_syncs_on_status ON syncs (status);
CREATE INDEX index_syncs_on_syncable ON syncs (syncable_type, syncable_id);

CREATE TABLE tag_groups (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    family_id UUID NOT NULL,
    position INTEGER DEFAULT 0,
    color VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    icon VARCHAR(255)
);

-- Indexes for tag_groups
CREATE INDEX index_tag_groups_on_archived ON tag_groups (archived);
CREATE UNIQUE INDEX index_tag_groups_on_family_id_and_name ON tag_groups (family_id, name);
CREATE INDEX index_tag_groups_on_family_id ON tag_groups (family_id);

CREATE TABLE taggings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag_id UUID NOT NULL,
    taggable_type VARCHAR(255),
    taggable_id UUID,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for taggings
CREATE INDEX index_taggings_on_tag_id ON taggings (tag_id);
CREATE INDEX index_taggings_on_taggable ON taggings (taggable_type, taggable_id);

CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255),
    color VARCHAR(255) NOT NULL DEFAULT '#e99537',
    family_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    tag_group_id BIGINT,
    archived BOOLEAN DEFAULT FALSE,
    position INTEGER DEFAULT 0,
    usage_count INTEGER DEFAULT 0
);

-- Indexes for tags
CREATE INDEX index_tags_on_archived ON tags (archived);
CREATE INDEX index_tags_on_family_id_and_archived ON tags (family_id, archived);
CREATE INDEX index_tags_on_family_id ON tags (family_id);
CREATE INDEX index_tags_on_tag_group_id ON tags (tag_group_id);

CREATE TABLE tool_calls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    provider_id VARCHAR(255) NOT NULL,
    provider_call_id VARCHAR(255),
    type VARCHAR(255) NOT NULL,
    function_name VARCHAR(255),
    function_arguments JSONB,
    function_result JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for tool_calls
CREATE INDEX index_tool_calls_on_message_id ON tool_calls (message_id);

CREATE TABLE trades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    security_id UUID NOT NULL,
    qty DECIMAL(19, 4),
    price DECIMAL(19, 4),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    currency VARCHAR(255),
    locked_attributes JSONB DEFAULT '{}'
);

-- Indexes for trades
CREATE INDEX index_trades_on_security_id ON trades (security_id);

CREATE TABLE transaction_splits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_transaction_id UUID NOT NULL,
    split_transaction_id UUID NOT NULL,
    description VARCHAR(255),
    amount DECIMAL(19, 4),
    percentage DECIMAL(5, 2),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for transaction_splits
CREATE INDEX index_transaction_splits_on_original_transaction_id ON transaction_splits (original_transaction_id);
CREATE INDEX index_transaction_splits_on_split_transaction_id ON transaction_splits (split_transaction_id);

CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    category_id UUID,
    locked_attributes JSONB DEFAULT '{}',
    kind VARCHAR(255) NOT NULL DEFAULT 'standard',
    discount_amount DECIMAL(19, 4),
    discount_description VARCHAR(255),
    payee_id BIGINT,
    reimbursable BOOLEAN DEFAULT FALSE,
    reimbursed BOOLEAN DEFAULT FALSE,
    reimbursed_at TIMESTAMP WITH TIME ZONE,
    exclude_from_reports BOOLEAN DEFAULT FALSE,
    exclude_from_budget BOOLEAN DEFAULT FALSE,
    reimbursement_batch_id UUID,
    original_transaction_id UUID,
    refund_amount DECIMAL(19, 4) DEFAULT '0.0',
    is_refund BOOLEAN DEFAULT FALSE,
    ledger_id UUID,
    ledger_account_id UUID,
    scheduled_transaction_id UUID
);

-- Indexes for transactions
CREATE INDEX index_transactions_on_category_id ON transactions (category_id);
CREATE INDEX index_transactions_on_exclude_from_budget ON transactions (exclude_from_budget);
CREATE INDEX index_transactions_on_exclude_from_reports ON transactions (exclude_from_reports);
CREATE INDEX index_transactions_on_kind ON transactions (kind);
CREATE INDEX index_transactions_on_ledger_account_id ON transactions (ledger_account_id);
CREATE INDEX index_transactions_on_ledger_id ON transactions (ledger_id);
CREATE INDEX index_transactions_on_original_transaction_id ON transactions (original_transaction_id);
CREATE INDEX index_transactions_on_payee_id ON transactions (payee_id);
CREATE INDEX index_transactions_on_reimbursable ON transactions (reimbursable);
CREATE INDEX index_transactions_on_reimbursed ON transactions (reimbursed);
CREATE INDEX index_transactions_on_reimbursement_batch_id ON transactions (reimbursement_batch_id);
CREATE INDEX index_transactions_on_scheduled_transaction_id ON transactions (scheduled_transaction_id);

CREATE TABLE transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inflow_transaction_id UUID NOT NULL,
    outflow_transaction_id UUID NOT NULL,
    status VARCHAR(255) NOT NULL DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    fee_amount DECIMAL(19, 4),
    discount_amount DECIMAL(19, 4),
    fee_description VARCHAR(255),
    discount_description VARCHAR(255)
);

-- Indexes for transfers
CREATE UNIQUE INDEX idx_on_inflow_transaction_id_outflow_transaction_id_8cd07a28bd ON transfers (inflow_transaction_id, outflow_transaction_id);
CREATE INDEX index_transfers_on_inflow_transaction_id ON transfers (inflow_transaction_id);
CREATE INDEX index_transfers_on_outflow_transaction_id ON transfers (outflow_transaction_id);

CREATE TABLE travel_event_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    template_type VARCHAR(255) NOT NULL,
    category_ids JSONB NOT NULL DEFAULT '[]',
    is_system_template BOOLEAN DEFAULT FALSE,
    family_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for travel_event_templates
CREATE INDEX index_travel_event_templates_on_family_id ON travel_event_templates (family_id);
CREATE INDEX index_travel_event_templates_on_is_system_template ON travel_event_templates (is_system_template);
CREATE INDEX index_travel_event_templates_on_template_type ON travel_event_templates (template_type);

CREATE TABLE travel_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    name VARCHAR(255),
    description TEXT,
    start_date DATE,
    end_date DATE,
    location VARCHAR(255),
    is_active BOOLEAN,
    auto_tag BOOLEAN,
    travel_categories JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Indexes for travel_events
CREATE INDEX index_travel_events_on_family_id ON travel_events (family_id);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL,
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    email VARCHAR(255),
    password_digest VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    role VARCHAR(255) NOT NULL DEFAULT 'member',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    onboarded_at TIMESTAMP WITH TIME ZONE,
    unconfirmed_email VARCHAR(255),
    otp_secret VARCHAR(255),
    otp_required BOOLEAN NOT NULL DEFAULT FALSE,
    otp_backup_codes VARCHAR(255),
    show_sidebar BOOLEAN DEFAULT TRUE,
    default_period VARCHAR(255) NOT NULL DEFAULT 'last_30_days',
    last_viewed_chat_id UUID,
    show_ai_sidebar BOOLEAN DEFAULT TRUE,
    ai_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    theme VARCHAR(255) DEFAULT 'system',
    rule_prompts_disabled BOOLEAN DEFAULT FALSE,
    rule_prompt_dismissed_at TIMESTAMP WITH TIME ZONE,
    goals TEXT,
    set_onboarding_preferences_at TIMESTAMP WITH TIME ZONE,
    set_onboarding_goals_at TIMESTAMP WITH TIME ZONE,
    sidebar_view VARCHAR(255) DEFAULT 'type_groups',
    current_ledger_id UUID
);

-- Indexes for users
CREATE INDEX index_users_on_current_ledger_id ON users (current_ledger_id);
CREATE UNIQUE INDEX index_users_on_email ON users (email);
CREATE INDEX index_users_on_family_id ON users (family_id);
CREATE INDEX index_users_on_last_viewed_chat_id ON users (last_viewed_chat_id);
CREATE UNIQUE INDEX index_users_on_otp_secret ON users (otp_secret);

CREATE TABLE valuations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    locked_attributes JSONB DEFAULT '{}'
);

CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    year INTEGER,
    mileage_value INTEGER,
    mileage_unit VARCHAR(255),
    make VARCHAR(255),
    model VARCHAR(255),
    locked_attributes JSONB DEFAULT '{}'
);

-- Foreign Key Constraints
-- Note: These are inferred and may need manual adjustment

ALTER TABLE account_group_memberships ADD CONSTRAINT fk_account_group_memberships_account
    FOREIGN KEY (account_id) REFERENCES accounts(id);
ALTER TABLE account_group_memberships ADD CONSTRAINT fk_account_group_memberships_account_group
    FOREIGN KEY (account_group_id) REFERENCES account_groups(id);
ALTER TABLE accounts ADD CONSTRAINT fk_accounts_plaid_account
    FOREIGN KEY (plaid_account_id) REFERENCES plaid_accounts(id);
ALTER TABLE api_keys ADD CONSTRAINT fk_api_keys_user
    FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE auto_skip_logs ADD CONSTRAINT fk_auto_skip_logs_scheduled_transaction
    FOREIGN KEY (scheduled_transaction_id) REFERENCES scheduled_transactions(id);
ALTER TABLE balances ADD CONSTRAINT fk_balances_account
    FOREIGN KEY (account_id) REFERENCES accounts(id);
ALTER TABLE budget_categories ADD CONSTRAINT fk_budget_categories_budget
    FOREIGN KEY (budget_id) REFERENCES budgets(id);
ALTER TABLE budgets ADD CONSTRAINT fk_budgets_ledger
    FOREIGN KEY (ledger_id) REFERENCES ledgers(id);
ALTER TABLE categories ADD CONSTRAINT fk_categories_ledger
    FOREIGN KEY (ledger_id) REFERENCES ledgers(id);
ALTER TABLE chats ADD CONSTRAINT fk_chats_user
    FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE credit_card_foreign_balances ADD CONSTRAINT fk_credit_card_foreign_balances_credit_card
    FOREIGN KEY (credit_card_id) REFERENCES credit_cards(id);
ALTER TABLE entries ADD CONSTRAINT fk_entries_account
    FOREIGN KEY (account_id) REFERENCES accounts(id);
ALTER TABLE export_logs ADD CONSTRAINT fk_export_logs_user
    FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE holdings ADD CONSTRAINT fk_holdings_account
    FOREIGN KEY (account_id) REFERENCES accounts(id);
ALTER TABLE impersonation_session_logs ADD CONSTRAINT fk_impersonation_session_logs_impersonation_session
    FOREIGN KEY (impersonation_session_id) REFERENCES impersonation_sessions(id);
ALTER TABLE imports ADD CONSTRAINT fk_imports_account
    FOREIGN KEY (account_id) REFERENCES accounts(id);
ALTER TABLE ledger_accounts ADD CONSTRAINT fk_ledger_accounts_ledger
    FOREIGN KEY (ledger_id) REFERENCES ledgers(id);
ALTER TABLE messages ADD CONSTRAINT fk_messages_chat
    FOREIGN KEY (chat_id) REFERENCES chats(id);
ALTER TABLE mobile_devices ADD CONSTRAINT fk_mobile_devices_user
    FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE plaid_accounts ADD CONSTRAINT fk_plaid_accounts_plaid_item
    FOREIGN KEY (plaid_item_id) REFERENCES plaid_items(id);
ALTER TABLE quick_transactions ADD CONSTRAINT fk_quick_transactions_account
    FOREIGN KEY (account_id) REFERENCES accounts(id);
ALTER TABLE quick_transactions ADD CONSTRAINT fk_quick_transactions_user
    FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE rule_actions ADD CONSTRAINT fk_rule_actions_rule
    FOREIGN KEY (rule_id) REFERENCES rules(id);
ALTER TABLE rule_conditions ADD CONSTRAINT fk_rule_conditions_rule
    FOREIGN KEY (rule_id) REFERENCES rules(id);
ALTER TABLE rule_logs ADD CONSTRAINT fk_rule_logs_rule
    FOREIGN KEY (rule_id) REFERENCES rules(id);
ALTER TABLE rule_logs ADD CONSTRAINT fk_rule_logs_transaction
    FOREIGN KEY (transaction_id) REFERENCES transactions(id);
ALTER TABLE scheduled_transactions ADD CONSTRAINT fk_scheduled_transactions_account
    FOREIGN KEY (account_id) REFERENCES accounts(id);
ALTER TABLE sessions ADD CONSTRAINT fk_sessions_user
    FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE subscription_events ADD CONSTRAINT fk_subscription_events_subscription
    FOREIGN KEY (subscription_id) REFERENCES subscriptions(id);
ALTER TABLE taggings ADD CONSTRAINT fk_taggings_tag
    FOREIGN KEY (tag_id) REFERENCES tags(id);
ALTER TABLE tool_calls ADD CONSTRAINT fk_tool_calls_message
    FOREIGN KEY (message_id) REFERENCES messages(id);
ALTER TABLE transactions ADD CONSTRAINT fk_transactions_ledger
    FOREIGN KEY (ledger_id) REFERENCES ledgers(id);
ALTER TABLE transactions ADD CONSTRAINT fk_transactions_ledger_account
    FOREIGN KEY (ledger_account_id) REFERENCES ledger_accounts(id);
ALTER TABLE transactions ADD CONSTRAINT fk_transactions_scheduled_transaction
    FOREIGN KEY (scheduled_transaction_id) REFERENCES scheduled_transactions(id);