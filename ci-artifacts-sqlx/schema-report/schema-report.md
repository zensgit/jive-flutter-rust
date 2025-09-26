# Database Schema Report
## Schema Information
- Date: Tue Sep 23 09:26:04 UTC 2025
- Database: PostgreSQL

## Migrations
```
total 140
drwxr-xr-x  2 runner runner  4096 Sep 23 09:25 .
drwxr-xr-x 10 runner runner  4096 Sep 23 09:25 ..
-rw-r--r--  1 runner runner  1650 Sep 23 09:25 001_create_templates_table.sql
-rw-r--r--  1 runner runner 10314 Sep 23 09:25 002_create_all_tables.sql
-rw-r--r--  1 runner runner  3233 Sep 23 09:25 003_insert_test_data.sql
-rw-r--r--  1 runner runner  2081 Sep 23 09:25 004_fix_missing_columns.sql
-rw-r--r--  1 runner runner  1843 Sep 23 09:25 005_create_superadmin.sql
-rw-r--r--  1 runner runner   231 Sep 23 09:25 006_update_superadmin_password.sql
-rw-r--r--  1 runner runner  6635 Sep 23 09:25 007_enhance_family_system.sql
-rw-r--r--  1 runner runner  8298 Sep 23 09:25 008_migrate_existing_data.sql
-rw-r--r--  1 runner runner  1132 Sep 23 09:25 009_create_superadmin_user.sql
-rw-r--r--  1 runner runner  5493 Sep 23 09:25 010_fix_schema_for_api.sql
-rw-r--r--  1 runner runner  6922 Sep 23 09:25 011_add_currency_exchange_tables.sql
-rw-r--r--  1 runner runner   154 Sep 23 09:25 011_fix_password_hash_column.sql
-rw-r--r--  1 runner runner  1789 Sep 23 09:25 012_fix_triggers_and_ledger_nullable.sql
-rw-r--r--  1 runner runner   499 Sep 23 09:25 013_add_payee_id_to_transactions.sql
-rw-r--r--  1 runner runner   444 Sep 23 09:25 014_add_recurring_and_denorm_names.sql
-rw-r--r--  1 runner runner   366 Sep 23 09:25 015_add_full_name_to_users.sql
-rw-r--r--  1 runner runner  2902 Sep 23 09:25 016_fix_families_member_count_and_superadmin.sql
-rw-r--r--  1 runner runner 14781 Sep 23 09:25 017_seed_full_currency_catalog.sql
-rw-r--r--  1 runner runner   762 Sep 23 09:25 018_add_username_to_users.sql
-rw-r--r--  1 runner runner  2357 Sep 23 09:25 019_tags_tables.sql
-rw-r--r--  1 runner runner  2556 Sep 23 09:25 020_adjust_templates_schema.sql
-rw-r--r--  1 runner runner  1327 Sep 23 09:25 021_extend_categories_for_user_features.sql
-rw-r--r--  1 runner runner  1289 Sep 23 09:25 022_backfill_categories.sql
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

