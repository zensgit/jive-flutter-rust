-- 040_update_crypto_chinese_names.sql
-- 批量更新加密货币的中文名称
-- 覆盖率目标: 100% (108种加密货币)

-- ============================================================
-- 主流加密货币 (Market Cap Top 20)
-- ============================================================
UPDATE currencies SET name_zh = '比特币' WHERE code = 'BTC' AND is_crypto = true;
UPDATE currencies SET name_zh = '以太坊' WHERE code = 'ETH' AND is_crypto = true;
UPDATE currencies SET name_zh = '泰达币' WHERE code = 'USDT' AND is_crypto = true;
UPDATE currencies SET name_zh = 'USD币' WHERE code = 'USDC' AND is_crypto = true;
UPDATE currencies SET name_zh = '币安币' WHERE code = 'BNB' AND is_crypto = true;
UPDATE currencies SET name_zh = '瑞波币' WHERE code = 'XRP' AND is_crypto = true;
UPDATE currencies SET name_zh = '索拉纳' WHERE code = 'SOL' AND is_crypto = true;
UPDATE currencies SET name_zh = '卡尔达诺' WHERE code = 'ADA' AND is_crypto = true;
UPDATE currencies SET name_zh = '狗狗币' WHERE code = 'DOGE' AND is_crypto = true;
UPDATE currencies SET name_zh = '波卡' WHERE code = 'DOT' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Polygon马蹄' WHERE code = 'MATIC' AND is_crypto = true;
UPDATE currencies SET name_zh = '莱特币' WHERE code = 'LTC' AND is_crypto = true;
UPDATE currencies SET name_zh = '波场' WHERE code = 'TRX' AND is_crypto = true;
UPDATE currencies SET name_zh = '雪崩币' WHERE code = 'AVAX' AND is_crypto = true;
UPDATE currencies SET name_zh = '柴犬币' WHERE code = 'SHIB' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Dai稳定币' WHERE code = 'DAI' AND is_crypto = true;
UPDATE currencies SET name_zh = '链接币' WHERE code = 'LINK' AND is_crypto = true;
UPDATE currencies SET name_zh = '宇宙币' WHERE code = 'ATOM' AND is_crypto = true;
UPDATE currencies SET name_zh = '恒星币' WHERE code = 'XLM' AND is_crypto = true;
UPDATE currencies SET name_zh = '门罗币' WHERE code = 'XMR' AND is_crypto = true;

-- ============================================================
-- DeFi 协议代币
-- ============================================================
UPDATE currencies SET name_zh = 'Uniswap独角兽' WHERE code = 'UNI' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Aave借贷' WHERE code = 'AAVE' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Compound借贷' WHERE code = 'COMP' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Curve曲线' WHERE code = 'CRV' AND is_crypto = true;
UPDATE currencies SET name_zh = '煎饼交易所' WHERE code = 'CAKE' AND is_crypto = true;
UPDATE currencies SET name_zh = 'SushiSwap寿司' WHERE code = 'SUSHI' AND is_crypto = true;
UPDATE currencies SET name_zh = '1inch协议' WHERE code = '1INCH' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Balancer平衡器' WHERE code = 'BAL' AND is_crypto = true;
UPDATE currencies SET name_zh = '合成资产' WHERE code = 'SNX' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Maker治理' WHERE code = 'MKR' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Lido质押' WHERE code = 'LDO' AND is_crypto = true;
UPDATE currencies SET name_zh = 'yearn收益聚合' WHERE code = 'YFI' AND is_crypto = true;
UPDATE currencies SET name_zh = 'GMX交易' WHERE code = 'GMX' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Frax稳定币' WHERE code = 'FRAX' AND is_crypto = true;

-- ============================================================
-- Layer 2 和侧链
-- ============================================================
UPDATE currencies SET name_zh = 'Arbitrum二层' WHERE code = 'ARB' AND is_crypto = true;
UPDATE currencies SET name_zh = '乐观以太坊' WHERE code = 'OP' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Immutable不变' WHERE code = 'IMX' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Loopring路印' WHERE code = 'LRC' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Stacks堆栈' WHERE code = 'STX' AND is_crypto = true;

-- ============================================================
-- 新一代公链
-- ============================================================
UPDATE currencies SET name_zh = 'Aptos公链' WHERE code = 'APT' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Sui水链' WHERE code = 'SUI' AND is_crypto = true;
UPDATE currencies SET name_zh = '阿尔格兰德' WHERE code = 'ALGO' AND is_crypto = true;
UPDATE currencies SET name_zh = '近协议' WHERE code = 'NEAR' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Fantom公链' WHERE code = 'FTM' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Conflux树图' WHERE code = 'CFX' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Celo支付' WHERE code = 'CELO' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Flow公链' WHERE code = 'FLOW' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Hedera哈希图' WHERE code = 'HBAR' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Cronos链' WHERE code = 'CRO' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Harmony和谐链' WHERE code = 'ONE' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Mina协议' WHERE code = 'MINA' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Klaytn克雷顿' WHERE code = 'KLAY' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Kusama草间弥生' WHERE code = 'KSM' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Waves波浪' WHERE code = 'WAVES' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Zilliqa吉利卡' WHERE code = 'ZIL' AND is_crypto = true;
UPDATE currencies SET name_zh = 'ICON图标' WHERE code = 'ICX' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Lisk利斯克' WHERE code = 'LSK' AND is_crypto = true;

-- ============================================================
-- NFT 和元宇宙
-- ============================================================
UPDATE currencies SET name_zh = '无聊猿' WHERE code = 'APE' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Axie游戏' WHERE code = 'AXS' AND is_crypto = true;
UPDATE currencies SET name_zh = '沙盒' WHERE code = 'SAND' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Decentraland元宇宙' WHERE code = 'MANA' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Enjin币' WHERE code = 'ENJ' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Gala游戏' WHERE code = 'GALA' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Blur市场' WHERE code = 'BLUR' AND is_crypto = true;
UPDATE currencies SET name_zh = 'LooksRare市场' WHERE code = 'LOOKS' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Theta网络' WHERE code = 'THETA' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Theta燃料' WHERE code = 'TFUEL' AND is_crypto = true;

-- ============================================================
-- AI 和数据服务
-- ============================================================
UPDATE currencies SET name_zh = '奇点网络' WHERE code = 'AGIX' AND is_crypto = true;
UPDATE currencies SET name_zh = '图表' WHERE code = 'GRT' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Render渲染' WHERE code = 'RNDR' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Fetch智能' WHERE code = 'FET' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Ocean协议' WHERE code = 'OCEAN' AND is_crypto = true;

-- ============================================================
-- 存储和基础设施
-- ============================================================
UPDATE currencies SET name_zh = 'Filecoin存储' WHERE code = 'FIL' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Arweave存储' WHERE code = 'AR' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Storj存储' WHERE code = 'STORJ' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Siacoin云储' WHERE code = 'SC' AND is_crypto = true;

-- ============================================================
-- 预言机和跨链
-- ============================================================
UPDATE currencies SET name_zh = 'Band协议' WHERE code = 'BAND' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Celer网络' WHERE code = 'CELR' AND is_crypto = true;
UPDATE currencies SET name_zh = 'THORChain雷神链' WHERE code = 'RUNE' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Quant量化' WHERE code = 'QNT' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Injective注入' WHERE code = 'INJ' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Kava卡瓦' WHERE code = 'KAVA' AND is_crypto = true;

-- ============================================================
-- Meme 币
-- ============================================================
UPDATE currencies SET name_zh = 'Pepe蛙' WHERE code = 'PEPE' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Bonk狗币' WHERE code = 'BONK' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Floki狗币' WHERE code = 'FLOKI' AND is_crypto = true;

-- ============================================================
-- 老牌主流币
-- ============================================================
UPDATE currencies SET name_zh = '比特币现金' WHERE code = 'BCH' AND is_crypto = true;
UPDATE currencies SET name_zh = '以太经典' WHERE code = 'ETC' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Zcash零币' WHERE code = 'ZEC' AND is_crypto = true;
UPDATE currencies SET name_zh = '达世币' WHERE code = 'DASH' AND is_crypto = true;
UPDATE currencies SET name_zh = 'EOS柚子' WHERE code = 'EOS' AND is_crypto = true;
UPDATE currencies SET name_zh = 'NEO小蚁' WHERE code = 'NEO' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Qtum量子链' WHERE code = 'QTUM' AND is_crypto = true;
UPDATE currencies SET name_zh = 'VeChain唯链' WHERE code = 'VET' AND is_crypto = true;
UPDATE currencies SET name_zh = 'IOTA埃欧塔' WHERE code = 'IOTA' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Tezos特索斯' WHERE code = 'XTZ' AND is_crypto = true;
UPDATE currencies SET name_zh = 'NEM新经币' WHERE code = 'XEM' AND is_crypto = true;

-- ============================================================
-- 交易所平台币
-- ============================================================
UPDATE currencies SET name_zh = 'Toncoin吨币' WHERE code = 'TON' AND is_crypto = true;
UPDATE currencies SET name_zh = 'LEO代币' WHERE code = 'LEO' AND is_crypto = true;
UPDATE currencies SET name_zh = '币安美元' WHERE code = 'BUSD' AND is_crypto = true;
UPDATE currencies SET name_zh = 'TrueUSD真美元' WHERE code = 'TUSD' AND is_crypto = true;
UPDATE currencies SET name_zh = '火币币' WHERE code = 'HT' AND is_crypto = true;
UPDATE currencies SET name_zh = 'OKB平台币' WHERE code = 'OKB' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Kucoin币' WHERE code = 'KCS' AND is_crypto = true;

-- ============================================================
-- 其他生态代币
-- ============================================================
UPDATE currencies SET name_zh = '比特流' WHERE code = 'BTT' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Chiliz球迷币' WHERE code = 'CHZ' AND is_crypto = true;
UPDATE currencies SET name_zh = '以太坊域名' WHERE code = 'ENS' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Holo全息链' WHERE code = 'HOT' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Oasis绿洲' WHERE code = 'ROSE' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Rocket Pool火箭池' WHERE code = 'RPL' AND is_crypto = true;
UPDATE currencies SET name_zh = 'XDC网络' WHERE code = 'XDC' AND is_crypto = true;
UPDATE currencies SET name_zh = 'Horizen地平线' WHERE code = 'ZEN' AND is_crypto = true;
UPDATE currencies SET name_zh = '多元宇宙' WHERE code = 'EGLD' AND is_crypto = true;
