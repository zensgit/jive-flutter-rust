-- Migration: Add more cryptocurrencies (76 new tokens)
-- Date: 2025-10-09
-- Description: Expand cryptocurrency list from 24 to 100 items

INSERT INTO currencies (code, name, name_zh, symbol, decimal_places, is_active, is_crypto, is_popular, display_order)
VALUES

-- === Layer 1 公链币 (Public Blockchains) ===
('SOL', 'Solana', 'Solana', 'SOL', 8, true, true, true, 2001),
('DOT', 'Polkadot', '波卡', 'DOT', 8, true, true, true, 2002),
('AVAX', 'Avalanche', '雪崩', 'AVAX', 8, true, true, false, 2003),
('ATOM', 'Cosmos', 'Cosmos', 'ATOM', 8, true, true, false, 2004),
('NEAR', 'NEAR Protocol', 'NEAR协议', 'NEAR', 8, true, true, false, 2005),
('FTM', 'Fantom', 'Fantom', 'FTM', 8, true, true, false, 2006),
('ALGO', 'Algorand', 'Algorand', 'ALGO', 8, true, true, false, 2007),
('XTZ', 'Tezos', 'Tezos', 'XTZ', 8, true, true, false, 2008),
('EOS', 'EOS', 'EOS', 'EOS', 8, true, true, false, 2009),
('TRX', 'TRON', '波场', 'TRX', 8, true, true, false, 2010),
('XLM', 'Stellar', '恒星币', 'XLM', 8, true, true, false, 2011),
('ADA', 'Cardano', '艾达币', 'ADA', 8, true, true, true, 2012),
('VET', 'VeChain', '唯链', 'VET', 8, true, true, false, 2013),
('ICP', 'Internet Computer', '互联网计算机', 'ICP', 8, true, true, false, 2014),
('FIL', 'Filecoin', 'Filecoin', 'FIL', 8, true, true, false, 2015),
('APT', 'Aptos', 'Aptos', 'APT', 8, true, true, false, 2016),
('SUI', 'Sui', 'Sui', 'SUI', 8, true, true, false, 2017),
('TON', 'Toncoin', 'Toncoin', 'TON', 8, true, true, false, 2018),

-- === Layer 2 & Scaling Solutions ===
('MATIC', 'Polygon', 'Polygon', 'MATIC', 8, true, true, true, 2019),
('OP', 'Optimism', 'Optimism', 'OP', 8, true, true, false, 2020),
('ARB', 'Arbitrum', 'Arbitrum', 'ARB', 8, true, true, false, 2021),
('IMX', 'Immutable X', 'Immutable X', 'IMX', 8, true, true, false, 2022),

-- === DeFi 代币 (DeFi Tokens) ===
('UNI', 'Uniswap', 'Uniswap', 'UNI', 8, true, true, true, 2023),
('SUSHI', 'SushiSwap', 'SushiSwap', 'SUSHI', 8, true, true, false, 2024),
('CAKE', 'PancakeSwap', 'PancakeSwap', 'CAKE', 8, true, true, false, 2025),
('CRV', 'Curve DAO Token', 'Curve', 'CRV', 8, true, true, false, 2026),
('1INCH', '1inch Network', '1inch', '1INCH', 8, true, true, false, 2027),
('SNX', 'Synthetix', 'Synthetix', 'SNX', 8, true, true, false, 2028),
('YFI', 'yearn.finance', 'yearn.finance', 'YFI', 8, true, true, false, 2029),
('BAL', 'Balancer', 'Balancer', 'BAL', 8, true, true, false, 2030),

-- === 稳定币 (Stablecoins) ===
('USDC', 'USD Coin', 'USDC', 'USDC', 8, true, true, true, 2031),
('BUSD', 'Binance USD', 'BUSD', 'BUSD', 8, true, true, false, 2032),
('DAI', 'Dai', 'Dai', 'DAI', 8, true, true, true, 2033),
('TUSD', 'TrueUSD', 'TrueUSD', 'TUSD', 8, true, true, false, 2034),
('FRAX', 'Frax', 'Frax', 'FRAX', 8, true, true, false, 2035),

-- === 交易所代币 (Exchange Tokens) ===
('BNB', 'BNB', '币安币', 'BNB', 8, true, true, true, 2036),
('CRO', 'Cronos', 'Cronos', 'CRO', 8, true, true, false, 2037),
('OKB', 'OKB', 'OKB', 'OKB', 8, true, true, false, 2038),
('HT', 'Huobi Token', '火币积分', 'HT', 8, true, true, false, 2039),
('LEO', 'UNUS SED LEO', 'LEO', 'LEO', 8, true, true, false, 2040),

-- === Meme 币 (Meme Coins) ===
('DOGE', 'Dogecoin', '狗狗币', 'DOGE', 8, true, true, true, 2041),
('SHIB', 'Shiba Inu', '柴犬币', 'SHIB', 8, true, true, true, 2042),
('PEPE', 'Pepe', 'Pepe', 'PEPE', 8, true, true, false, 2043),
('FLOKI', 'FLOKI', 'FLOKI', 'FLOKI', 8, true, true, false, 2044),
('BONK', 'Bonk', 'Bonk', 'BONK', 8, true, true, false, 2045),

-- === GameFi & Metaverse ===
('AXS', 'Axie Infinity', 'Axie Infinity', 'AXS', 8, true, true, false, 2046),
('SAND', 'The Sandbox', 'The Sandbox', 'SAND', 8, true, true, false, 2047),
('MANA', 'Decentraland', 'Decentraland', 'MANA', 8, true, true, false, 2048),
('ENJ', 'Enjin Coin', 'Enjin Coin', 'ENJ', 8, true, true, false, 2049),
('GALA', 'Gala', 'Gala', 'GALA', 8, true, true, false, 2050),
('APE', 'ApeCoin', 'ApeCoin', 'APE', 8, true, true, false, 2051),

-- === 预言机 & Infrastructure ===
('LINK', 'Chainlink', 'Chainlink', 'LINK', 8, true, true, true, 2052),
('BAND', 'Band Protocol', 'Band', 'BAND', 8, true, true, false, 2053),
('GRT', 'The Graph', 'The Graph', 'GRT', 8, true, true, false, 2054),

-- === 隐私币 (Privacy Coins) ===
('XMR', 'Monero', '门罗币', 'XMR', 8, true, true, false, 2055),
('ZEC', 'Zcash', 'Zcash', 'ZEC', 8, true, true, false, 2056),
('DASH', 'Dash', '达世币', 'DASH', 8, true, true, false, 2057),

-- === AI & Data ===
('FET', 'Fetch.ai', 'Fetch.ai', 'FET', 8, true, true, false, 2058),
('OCEAN', 'Ocean Protocol', 'Ocean', 'OCEAN', 8, true, true, false, 2059),
('AGIX', 'SingularityNET', 'SingularityNET', 'AGIX', 8, true, true, false, 2060),
('RNDR', 'Render Token', 'Render', 'RNDR', 8, true, true, false, 2061),

-- === Web3 & Storage ===
('AR', 'Arweave', 'Arweave', 'AR', 8, true, true, false, 2062),
('STORJ', 'Storj', 'Storj', 'STORJ', 8, true, true, false, 2063),

-- === NFT Platforms ===
('LOOKS', 'LooksRare', 'LooksRare', 'LOOKS', 8, true, true, false, 2064),
('BLUR', 'Blur', 'Blur', 'BLUR', 8, true, true, false, 2065),

-- === Staking & Liquid Staking ===
('LDO', 'Lido DAO', 'Lido', 'LDO', 8, true, true, false, 2066),
('RPL', 'Rocket Pool', 'Rocket Pool', 'RPL', 8, true, true, false, 2067),

-- === Cross-chain & Bridges ===
('RUNE', 'THORChain', 'THORChain', 'RUNE', 8, true, true, false, 2068),
('CELR', 'Celer Network', 'Celer', 'CELR', 8, true, true, false, 2069),

-- === Social & Creator Economy ===
('CHZ', 'Chiliz', 'Chiliz', 'CHZ', 8, true, true, false, 2070),
('FLOW', 'Flow', 'Flow', 'FLOW', 8, true, true, false, 2071),

-- === Governance & DAO ===
('ENS', 'Ethereum Name Service', 'ENS', 'ENS', 8, true, true, false, 2072),
('GMX', 'GMX', 'GMX', 'GMX', 8, true, true, false, 2073),

-- === Other Notable Projects ===
('INJ', 'Injective', 'Injective', 'INJ', 8, true, true, false, 2074),
('QNT', 'Quant', 'Quant', 'QNT', 8, true, true, false, 2075),
('HBAR', 'Hedera', 'Hedera', 'HBAR', 8, true, true, false, 2076),
('EGLD', 'MultiversX', 'MultiversX', 'EGLD', 8, true, true, false, 2077),
('THETA', 'Theta Network', 'Theta', 'THETA', 8, true, true, false, 2078),
('ZIL', 'Zilliqa', 'Zilliqa', 'ZIL', 8, true, true, false, 2079),
('KSM', 'Kusama', 'Kusama', 'KSM', 8, true, true, false, 2080),
('ONE', 'Harmony', 'Harmony', 'ONE', 8, true, true, false, 2081),
('CELO', 'Celo', 'Celo', 'CELO', 8, true, true, false, 2082),
('KAVA', 'Kava', 'Kava', 'KAVA', 8, true, true, false, 2083),
('ROSE', 'Oasis Network', 'Oasis', 'ROSE', 8, true, true, false, 2084),
('WAVES', 'Waves', 'Waves', 'WAVES', 8, true, true, false, 2085),
('QTUM', 'Qtum', 'Qtum', 'QTUM', 8, true, true, false, 2086),
('ZEN', 'Horizen', 'Horizen', 'ZEN', 8, true, true, false, 2087),
('ICX', 'ICON', 'ICON', 'ICX', 8, true, true, false, 2088),
('LSK', 'Lisk', 'Lisk', 'LSK', 8, true, true, false, 2089),
('MINA', 'Mina Protocol', 'Mina', 'MINA', 8, true, true, false, 2090),
('CFX', 'Conflux', 'Conflux', 'CFX', 8, true, true, false, 2091),
('IOTA', 'IOTA', 'IOTA', 'IOTA', 8, true, true, false, 2092),
('XDC', 'XDC Network', 'XDC', 'XDC', 8, true, true, false, 2093),
('STX', 'Stacks', 'Stacks', 'STX', 8, true, true, false, 2094),
('KLAY', 'Klaytn', 'Klaytn', 'KLAY', 8, true, true, false, 2095),
('TFUEL', 'Theta Fuel', 'Theta Fuel', 'TFUEL', 8, true, true, false, 2096),
('XEM', 'NEM', 'NEM', 'XEM', 8, true, true, false, 2097),
('BTT', 'BitTorrent', 'BitTorrent', 'BTT', 8, true, true, false, 2098),
('HOT', 'Holo', 'Holo', 'HOT', 8, true, true, false, 2099),
('SC', 'Siacoin', 'Siacoin', 'SC', 8, true, true, false, 2100)

ON CONFLICT (code) DO NOTHING;
