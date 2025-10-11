-- 039_add_currency_icon_field.sql
-- Add icon field to currencies table for cryptocurrency icons

-- Add icon column (nullable, will be populated for cryptocurrencies)
ALTER TABLE currencies
ADD COLUMN IF NOT EXISTS icon TEXT;

COMMENT ON COLUMN currencies.icon IS 'Icon identifier or emoji for the currency (especially for cryptocurrencies)';

-- Populate icon field for major cryptocurrencies
UPDATE currencies SET icon = '₿' WHERE code = 'BTC';
UPDATE currencies SET icon = 'Ξ' WHERE code = 'ETH';
UPDATE currencies SET icon = '₮' WHERE code = 'USDT';
UPDATE currencies SET icon = 'Ⓢ' WHERE code = 'USDC';
UPDATE currencies SET icon = 'Ƀ' WHERE code = 'BNB';
UPDATE currencies SET icon = '✕' WHERE code = 'XRP';
UPDATE currencies SET icon = '₳' WHERE code = 'ADA';
UPDATE currencies SET icon = '◎' WHERE code = 'SOL';
UPDATE currencies SET icon = '●' WHERE code = 'DOT';
UPDATE currencies SET icon = 'Ð' WHERE code = 'DOGE';
UPDATE currencies SET icon = 'Ł' WHERE code = 'LTC';
UPDATE currencies SET icon = 'Ⱥ' WHERE code = 'AVAX';
UPDATE currencies SET icon = '⟠' WHERE code = 'MATIC';
UPDATE currencies SET icon = '🦄' WHERE code = 'UNI';
UPDATE currencies SET icon = '🔗' WHERE code = 'LINK';
UPDATE currencies SET icon = '💎' WHERE code = 'DAI';
UPDATE currencies SET icon = '🌙' WHERE code = 'LUNA';
UPDATE currencies SET icon = '🐸' WHERE code = 'PEPE';
