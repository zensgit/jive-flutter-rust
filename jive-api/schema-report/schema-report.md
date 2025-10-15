# Database Schema Report
## Schema Information
- Date: Wed Oct  8 09:32:25 UTC 2025
- Database: PostgreSQL

## Migrations
```
total 208
drwxr-xr-x  2 runner runner  4096 Oct  8 09:31 .
drwxr-xr-x 11 runner runner  4096 Oct  8 09:31 ..
-rw-r--r--  1 runner runner  1650 Oct  8 09:31 001_create_templates_table.sql
-rw-r--r--  1 runner runner 10314 Oct  8 09:31 002_create_all_tables.sql
-rw-r--r--  1 runner runner  3233 Oct  8 09:31 003_insert_test_data.sql
-rw-r--r--  1 runner runner  2081 Oct  8 09:31 004_fix_missing_columns.sql
-rw-r--r--  1 runner runner  1843 Oct  8 09:31 005_create_superadmin.sql
-rw-r--r--  1 runner runner   231 Oct  8 09:31 006_update_superadmin_password.sql
-rw-r--r--  1 runner runner  6635 Oct  8 09:31 007_enhance_family_system.sql
-rw-r--r--  1 runner runner  8298 Oct  8 09:31 008_migrate_existing_data.sql
-rw-r--r--  1 runner runner  1132 Oct  8 09:31 009_create_superadmin_user.sql
-rw-r--r--  1 runner runner  6878 Oct  8 09:31 010_fix_schema_for_api.sql
-rw-r--r--  1 runner runner  6922 Oct  8 09:31 011_add_currency_exchange_tables.sql
-rw-r--r--  1 runner runner  1789 Oct  8 09:31 012_fix_triggers_and_ledger_nullable.sql
-rw-r--r--  1 runner runner   594 Oct  8 09:31 013_add_payee_id_to_transactions.sql
-rw-r--r--  1 runner runner   444 Oct  8 09:31 014_add_recurring_and_denorm_names.sql
-rw-r--r--  1 runner runner   366 Oct  8 09:31 015_add_full_name_to_users.sql
-rw-r--r--  1 runner runner  2902 Oct  8 09:31 016_fix_families_member_count_and_superadmin.sql
-rw-r--r--  1 runner runner 14781 Oct  8 09:31 017_seed_full_currency_catalog.sql
-rw-r--r--  1 runner runner   762 Oct  8 09:31 018_add_username_to_users.sql
-rw-r--r--  1 runner runner  1663 Oct  8 09:31 018_fix_exchange_rates_unique_date.sql
-rw-r--r--  1 runner runner  1085 Oct  8 09:31 019_add_manual_rate_columns.sql
-rw-r--r--  1 runner runner  2357 Oct  8 09:31 019_tags_tables.sql
-rw-r--r--  1 runner runner  2556 Oct  8 09:31 020_adjust_templates_schema.sql
-rw-r--r--  1 runner runner  1327 Oct  8 09:31 021_extend_categories_for_user_features.sql
-rw-r--r--  1 runner runner  1289 Oct  8 09:31 022_backfill_categories.sql
-rw-r--r--  1 runner runner   606 Oct  8 09:31 023_add_exchange_rates_today_lookup_index.sql
-rw-r--r--  1 runner runner  2050 Oct  8 09:31 024_add_export_indexes.sql
-rw-r--r--  1 runner runner   259 Oct  8 09:31 025_fix_password_hash_column.sql
-rw-r--r--  1 runner runner   295 Oct  8 09:31 026_add_audit_indexes.sql
-rw-r--r--  1 runner runner  2433 Oct  8 09:31 027_fix_superadmin_baseline.sql
-rw-r--r--  1 runner runner   582 Oct  8 09:31 028_add_unique_default_ledger_index.sql
-rw-r--r--  1 runner runner  1588 Oct  8 09:31 031_create_banks_table.sql
-rw-r--r--  1 runner runner   299 Oct  8 09:31 032_add_bank_id_to_accounts.sql
-rw-r--r--  1 runner runner  9201 Oct  8 09:31 036_add_budget_tables.sql
-rw-r--r--  1 runner runner  9763 Oct  8 09:31 037_add_net_worth_tracking.sql
-rw-r--r--  1 runner runner  7730 Oct  8 09:31 038_add_travel_mode_mvp.sql
```
## Tables
                    List of relations
 Schema |            Name             | Type  |  Owner   
--------+-----------------------------+-------+----------
 public | account_balances            | table | postgres
 public | accounts                    | table | postgres
 public | attachments                 | table | postgres
 public | audit_logs                  | table | postgres
 public | banks                       | table | postgres
 public | budget_alerts               | table | postgres
 public | budget_categories           | table | postgres
 public | budget_templates            | table | postgres
 public | budget_tracking             | table | postgres
 public | budgets                     | table | postgres
 public | categories                  | table | postgres
 public | crypto_prices               | table | postgres
 public | currencies                  | table | postgres
 public | exchange_conversion_history | table | postgres
 public | exchange_rate_cache         | table | postgres
 public | exchange_rates              | table | postgres
 public | families                    | table | postgres
 public | family_audit_logs           | table | postgres
 public | family_currency_settings    | table | postgres
 public | family_members              | table | postgres
 public | invitations                 | table | postgres
 public | ledgers                     | table | postgres
 public | net_worth_goals             | table | postgres
 public | system_category_templates   | table | postgres
 public | tag_groups                  | table | postgres
 public | tags                        | table | postgres
 public | transactions                | table | postgres
 public | user_currency_preferences   | table | postgres
 public | user_currency_settings      | table | postgres
 public | users                       | table | postgres
(30 rows)

