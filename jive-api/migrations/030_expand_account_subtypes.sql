-- Migration: Expand account sub types to support more Chinese account types
-- Date: 2025-09-28
-- Description: Add support for WeChat, Alipay, Huabei, JD, investment types, and prepaid accounts

-- Drop the old constraint
ALTER TABLE accounts
DROP CONSTRAINT IF EXISTS check_account_sub_type;

-- Add new constraint with expanded types
ALTER TABLE accounts
ADD CONSTRAINT check_account_sub_type
  CHECK (account_sub_type IN (
    -- Original types
    'cash',
    'debit_card',
    'savings_account',
    'checking',
    'investment',
    'prepaid_card',
    'digital_wallet',
    'credit_card',
    'loan',
    'mortgage',
    -- Payment platforms
    'wechat',
    'wechat_change',
    'alipay',
    'yuebao',
    'union_pay',
    'bank_card',
    'provident_fund',
    'qq_wallet',
    'jd_wallet',
    'medical_insurance',
    'digital_rmb',
    'huawei_wallet',
    'pinduoduo_wallet',
    'paypal',
    -- Credit and installment
    'huabei',
    'jiebei',
    'jd_white_bar',
    'meituan_monthly',
    'douyin_monthly',
    'wechat_installment',
    -- Prepaid accounts
    'phone_credit',
    'utilities',
    'meal_card',
    'deposit',
    'transit_card',
    'membership_card',
    'gas_card',
    'sinopec_wallet',
    'apple_account',
    -- Investment types
    'stock',
    'fund',
    'gold',
    'forex',
    'futures',
    'bond',
    'fixed_income',
    'crypto',
    -- Other
    'other'
  ));

-- Add comment
COMMENT ON CONSTRAINT check_account_sub_type ON accounts IS
  'Validates account sub type: supports 52 different account types including Chinese payment platforms, credit services, prepaid accounts, and investment types';