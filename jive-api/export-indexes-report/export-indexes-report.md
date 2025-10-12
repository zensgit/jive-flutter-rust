# Export Indexes Report
Generated at: Wed Oct  8 09:32:08 UTC 2025

                                                                Table "public.transactions"
      Column      |           Type           | Collation | Nullable |            Default             | Storage  | Compression | Stats target | Description 
------------------+--------------------------+-----------+----------+--------------------------------+----------+-------------+--------------+-------------
 id               | uuid                     |           | not null | gen_random_uuid()              | plain    |             |              | 
 ledger_id        | uuid                     |           | not null |                                | plain    |             |              | 
 transaction_type | character varying(20)    |           | not null |                                | extended |             |              | 
 amount           | numeric(15,2)            |           | not null |                                | main     |             |              | 
 currency         | character varying(10)    |           |          | 'CNY'::character varying       | extended |             |              | 
 category_id      | uuid                     |           |          |                                | plain    |             |              | 
 account_id       | uuid                     |           | not null |                                | plain    |             |              | 
 to_account_id    | uuid                     |           |          |                                | plain    |             |              | 
 transaction_date | date                     |           | not null |                                | plain    |             |              | 
 transaction_time | time without time zone   |           |          |                                | plain    |             |              | 
 description      | text                     |           |          |                                | extended |             |              | 
 notes            | text                     |           |          |                                | extended |             |              | 
 tags             | text[]                   |           |          |                                | extended |             |              | 
 location         | text                     |           |          |                                | extended |             |              | 
 merchant         | character varying(200)   |           |          |                                | extended |             |              | 
 receipt_url      | text                     |           |          |                                | extended |             |              | 
 is_recurring     | boolean                  |           |          | false                          | plain    |             |              | 
 recurring_id     | uuid                     |           |          |                                | plain    |             |              | 
 status           | character varying(20)    |           |          | 'completed'::character varying | extended |             |              | 
 created_by       | uuid                     |           | not null |                                | plain    |             |              | 
 updated_by       | uuid                     |           |          |                                | plain    |             |              | 
 deleted_at       | timestamp with time zone |           |          |                                | plain    |             |              | 
 created_at       | timestamp with time zone |           |          | CURRENT_TIMESTAMP              | plain    |             |              | 
 updated_at       | timestamp with time zone |           |          | CURRENT_TIMESTAMP              | plain    |             |              | 
 reference_number | character varying(100)   |           |          |                                | extended |             |              | 
 is_manual        | boolean                  |           |          | true                           | plain    |             |              | 
 import_id        | character varying(100)   |           |          |                                | extended |             |              | 
 payee_id         | uuid                     |           |          |                                | plain    |             |              | 
 recurring_rule   | text                     |           |          |                                | extended |             |              | 
 category_name    | text                     |           |          |                                | extended |             |              | 
 payee            | text                     |           |          |                                | extended |             |              | 
Indexes:
    "transactions_pkey" PRIMARY KEY, btree (id)
    "idx_transactions_account" btree (account_id)
    "idx_transactions_category" btree (category_id)
    "idx_transactions_created_by" btree (created_by)
    "idx_transactions_date" btree (transaction_date)
    "idx_transactions_export" btree (transaction_date, ledger_id) WHERE deleted_at IS NULL
    "idx_transactions_export_covering" btree (ledger_id, transaction_date DESC) INCLUDE (amount, description, category_id, account_id, created_at) WHERE deleted_at IS NULL
    "idx_transactions_ledger" btree (ledger_id)
    "idx_transactions_payee_id" btree (payee_id)
    "idx_transactions_type" btree (transaction_type)
Check constraints:
    "transactions_status_check" CHECK (status::text = ANY (ARRAY['pending'::character varying, 'completed'::character varying, 'cancelled'::character varying]::text[]))
    "transactions_transaction_type_check" CHECK (transaction_type::text = ANY (ARRAY['expense'::character varying, 'income'::character varying, 'transfer'::character varying]::text[]))
Foreign-key constraints:
    "transactions_account_id_fkey" FOREIGN KEY (account_id) REFERENCES accounts(id)
    "transactions_category_id_fkey" FOREIGN KEY (category_id) REFERENCES categories(id)
    "transactions_created_by_fkey" FOREIGN KEY (created_by) REFERENCES users(id)
    "transactions_ledger_id_fkey" FOREIGN KEY (ledger_id) REFERENCES ledgers(id) ON DELETE CASCADE
    "transactions_to_account_id_fkey" FOREIGN KEY (to_account_id) REFERENCES accounts(id)
    "transactions_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES users(id)
Referenced by:
    TABLE "attachments" CONSTRAINT "attachments_transaction_id_fkey" FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE
    TABLE "budget_tracking" CONSTRAINT "budget_tracking_last_transaction_id_fkey" FOREIGN KEY (last_transaction_id) REFERENCES transactions(id)
Triggers:
    update_transactions_updated_at BEFORE UPDATE ON transactions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()
Access method: heap


            indexname             |                                                                                                     indexdef                                                                                                      
----------------------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 idx_transactions_account         | CREATE INDEX idx_transactions_account ON public.transactions USING btree (account_id)
 idx_transactions_category        | CREATE INDEX idx_transactions_category ON public.transactions USING btree (category_id)
 idx_transactions_created_by      | CREATE INDEX idx_transactions_created_by ON public.transactions USING btree (created_by)
 idx_transactions_date            | CREATE INDEX idx_transactions_date ON public.transactions USING btree (transaction_date)
 idx_transactions_export          | CREATE INDEX idx_transactions_export ON public.transactions USING btree (transaction_date, ledger_id) WHERE (deleted_at IS NULL)
 idx_transactions_export_covering | CREATE INDEX idx_transactions_export_covering ON public.transactions USING btree (ledger_id, transaction_date DESC) INCLUDE (amount, description, category_id, account_id, created_at) WHERE (deleted_at IS NULL)
 idx_transactions_ledger          | CREATE INDEX idx_transactions_ledger ON public.transactions USING btree (ledger_id)
 idx_transactions_payee_id        | CREATE INDEX idx_transactions_payee_id ON public.transactions USING btree (payee_id)
 idx_transactions_type            | CREATE INDEX idx_transactions_type ON public.transactions USING btree (transaction_type)
 transactions_pkey                | CREATE UNIQUE INDEX transactions_pkey ON public.transactions USING btree (id)
(10 rows)


## Audit Indexes
                indexname                |                                                         indexdef                                                          
-----------------------------------------+---------------------------------------------------------------------------------------------------------------------------
 family_audit_logs_pkey                  | CREATE UNIQUE INDEX family_audit_logs_pkey ON public.family_audit_logs USING btree (id)
 idx_family_audit_logs_action            | CREATE INDEX idx_family_audit_logs_action ON public.family_audit_logs USING btree (action)
 idx_family_audit_logs_created_at        | CREATE INDEX idx_family_audit_logs_created_at ON public.family_audit_logs USING btree (created_at DESC)
 idx_family_audit_logs_family_created_at | CREATE INDEX idx_family_audit_logs_family_created_at ON public.family_audit_logs USING btree (family_id, created_at DESC)
 idx_family_audit_logs_family_id         | CREATE INDEX idx_family_audit_logs_family_id ON public.family_audit_logs USING btree (family_id)
 idx_family_audit_logs_user_id           | CREATE INDEX idx_family_audit_logs_user_id ON public.family_audit_logs USING btree (user_id)
(6 rows)

