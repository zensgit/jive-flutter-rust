# Database Schema Report
## Schema Information
- Date: Tue Sep 16 01:33:49 UTC 2025
- Database: PostgreSQL

## Migrations
```
total 140
drwxr-xr-x  2 runner runner  4096 Sep 16 01:27 .
drwxr-xr-x 10 runner runner  4096 Sep 16 01:27 ..
-rw-r--r--  1 runner runner  1650 Sep 16 01:27 001_create_templates_table.sql
-rw-r--r--  1 runner runner 10314 Sep 16 01:27 002_create_all_tables.sql
-rw-r--r--  1 runner runner  3233 Sep 16 01:27 003_insert_test_data.sql
-rw-r--r--  1 runner runner  2081 Sep 16 01:27 004_fix_missing_columns.sql
-rw-r--r--  1 runner runner  1843 Sep 16 01:27 005_create_superadmin.sql
-rw-r--r--  1 runner runner   231 Sep 16 01:27 006_update_superadmin_password.sql
-rw-r--r--  1 runner runner  6635 Sep 16 01:27 007_enhance_family_system.sql
-rw-r--r--  1 runner runner  8298 Sep 16 01:27 008_migrate_existing_data.sql
-rw-r--r--  1 runner runner  1132 Sep 16 01:27 009_create_superadmin_user.sql
-rw-r--r--  1 runner runner  5493 Sep 16 01:27 010_fix_schema_for_api.sql
-rw-r--r--  1 runner runner  6922 Sep 16 01:27 011_add_currency_exchange_tables.sql
-rw-r--r--  1 runner runner   154 Sep 16 01:27 011_fix_password_hash_column.sql
-rw-r--r--  1 runner runner  1789 Sep 16 01:27 012_fix_triggers_and_ledger_nullable.sql
-rw-r--r--  1 runner runner   499 Sep 16 01:27 013_add_payee_id_to_transactions.sql
-rw-r--r--  1 runner runner   444 Sep 16 01:27 014_add_recurring_and_denorm_names.sql
-rw-r--r--  1 runner runner   366 Sep 16 01:27 015_add_full_name_to_users.sql
-rw-r--r--  1 runner runner  2902 Sep 16 01:27 016_fix_families_member_count_and_superadmin.sql
-rw-r--r--  1 runner runner 14781 Sep 16 01:27 017_seed_full_currency_catalog.sql
-rw-r--r--  1 runner runner   762 Sep 16 01:27 018_add_username_to_users.sql
-rw-r--r--  1 runner runner  2357 Sep 16 01:27 019_tags_tables.sql
-rw-r--r--  1 runner runner  2556 Sep 16 01:27 020_adjust_templates_schema.sql
-rw-r--r--  1 runner runner  1327 Sep 16 01:27 021_extend_categories_for_user_features.sql
-rw-r--r--  1 runner runner  1289 Sep 16 01:27 022_backfill_categories.sql
```
## Tables
                    List of relations
 Schema |            Name             | Type  |  Owner   
--------+-----------------------------+-------+----------
 public | account_balances            | table | postgres
 public | accounts                    | table | postgres
 public | attachments                 | table | postgres
 public | audit_logs                  | table | postgres
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
 public | system_category_templates   | table | postgres
 public | tag_groups                  | table | postgres
 public | tags                        | table | postgres
 public | transactions                | table | postgres
 public | user_currency_preferences   | table | postgres
 public | user_currency_settings      | table | postgres
 public | users                       | table | postgres
(24 rows)

