-- 041_update_all_crypto_icons.sql
-- 为所有加密货币添加图标 emoji
-- 目标: 108种加密货币全部配置图标

-- ============================================================
-- 主流加密货币 (已有图标的保持不变，补充缺失的)
-- ============================================================
-- BTC ₿ (已有)
-- ETH Ξ (已有)
-- USDT ₮ (已有)
-- USDC Ⓢ (已有)
-- BNB Ƀ (已有)
UPDATE currencies SET icon = '✕' WHERE code = 'XRP' AND is_crypto = true; -- 瑞波币
UPDATE currencies SET icon = '◎' WHERE code = 'SOL' AND is_crypto = true; -- 索拉纳
-- ADA ₳ (已有)
UPDATE currencies SET icon = '🐕' WHERE code = 'DOGE' AND is_crypto = true; -- 狗狗币
-- DOT ● (已有)
UPDATE currencies SET icon = '⬡' WHERE code = 'MATIC' AND is_crypto = true; -- Polygon
-- LTC Ł (已有)
UPDATE currencies SET icon = '⟠' WHERE code = 'TRX' AND is_crypto = true; -- 波场
-- AVAX Ⱥ (已有)
UPDATE currencies SET icon = '🐕' WHERE code = 'SHIB' AND is_crypto = true; -- 柴犬币
-- DAI 💎 (已有)
-- LINK 🔗 (已有)
UPDATE currencies SET icon = '⚛️' WHERE code = 'ATOM' AND is_crypto = true; -- 宇宙币
UPDATE currencies SET icon = '⭐' WHERE code = 'XLM' AND is_crypto = true; -- 恒星币
UPDATE currencies SET icon = '🔒' WHERE code = 'XMR' AND is_crypto = true; -- 门罗币

-- ============================================================
-- DeFi 协议代币
-- ============================================================
-- UNI 🦄 (已有)
UPDATE currencies SET icon = '👻' WHERE code = 'AAVE' AND is_crypto = true; -- Aave借贷
UPDATE currencies SET icon = '🏦' WHERE code = 'COMP' AND is_crypto = true; -- Compound借贷
UPDATE currencies SET icon = '🌊' WHERE code = 'CRV' AND is_crypto = true; -- Curve曲线
UPDATE currencies SET icon = '🥞' WHERE code = 'CAKE' AND is_crypto = true; -- 煎饼交易所
UPDATE currencies SET icon = '🍣' WHERE code = 'SUSHI' AND is_crypto = true; -- SushiSwap寿司
UPDATE currencies SET icon = '1️⃣' WHERE code = '1INCH' AND is_crypto = true; -- 1inch协议
UPDATE currencies SET icon = '⚖️' WHERE code = 'BAL' AND is_crypto = true; -- Balancer平衡器
UPDATE currencies SET icon = '🔀' WHERE code = 'SNX' AND is_crypto = true; -- 合成资产
UPDATE currencies SET icon = '🏗️' WHERE code = 'MKR' AND is_crypto = true; -- Maker治理
UPDATE currencies SET icon = '🔱' WHERE code = 'LDO' AND is_crypto = true; -- Lido质押
UPDATE currencies SET icon = '💰' WHERE code = 'YFI' AND is_crypto = true; -- yearn收益聚合
UPDATE currencies SET icon = '📊' WHERE code = 'GMX' AND is_crypto = true; -- GMX交易
UPDATE currencies SET icon = '💵' WHERE code = 'FRAX' AND is_crypto = true; -- Frax稳定币

-- ============================================================
-- Layer 2 和侧链
-- ============================================================
UPDATE currencies SET icon = '🔷' WHERE code = 'ARB' AND is_crypto = true; -- Arbitrum二层
UPDATE currencies SET icon = '🔴' WHERE code = 'OP' AND is_crypto = true; -- 乐观以太坊
UPDATE currencies SET icon = '🎮' WHERE code = 'IMX' AND is_crypto = true; -- Immutable不变
UPDATE currencies SET icon = '🔁' WHERE code = 'LRC' AND is_crypto = true; -- Loopring路印
UPDATE currencies SET icon = '🏗️' WHERE code = 'STX' AND is_crypto = true; -- Stacks堆栈

-- ============================================================
-- 新一代公链
-- ============================================================
UPDATE currencies SET icon = '🌟' WHERE code = 'APT' AND is_crypto = true; -- Aptos公链
UPDATE currencies SET icon = '💧' WHERE code = 'SUI' AND is_crypto = true; -- Sui水链
UPDATE currencies SET icon = '🔺' WHERE code = 'ALGO' AND is_crypto = true; -- 阿尔格兰德
UPDATE currencies SET icon = '🌐' WHERE code = 'NEAR' AND is_crypto = true; -- 近协议
UPDATE currencies SET icon = '👻' WHERE code = 'FTM' AND is_crypto = true; -- Fantom公链
UPDATE currencies SET icon = '🌳' WHERE code = 'CFX' AND is_crypto = true; -- Conflux树图
UPDATE currencies SET icon = '💚' WHERE code = 'CELO' AND is_crypto = true; -- Celo支付
UPDATE currencies SET icon = '🌊' WHERE code = 'FLOW' AND is_crypto = true; -- Flow公链
UPDATE currencies SET icon = '⚡' WHERE code = 'HBAR' AND is_crypto = true; -- Hedera哈希图
UPDATE currencies SET icon = '👑' WHERE code = 'CRO' AND is_crypto = true; -- Cronos链
UPDATE currencies SET icon = '🎵' WHERE code = 'ONE' AND is_crypto = true; -- Harmony和谐链
UPDATE currencies SET icon = '🔶' WHERE code = 'MINA' AND is_crypto = true; -- Mina协议
UPDATE currencies SET icon = '🔥' WHERE code = 'KLAY' AND is_crypto = true; -- Klaytn克雷顿
UPDATE currencies SET icon = '🦜' WHERE code = 'KSM' AND is_crypto = true; -- Kusama草间弥生
UPDATE currencies SET icon = '🌊' WHERE code = 'WAVES' AND is_crypto = true; -- Waves波浪
UPDATE currencies SET icon = '⚡' WHERE code = 'ZIL' AND is_crypto = true; -- Zilliqa吉利卡
UPDATE currencies SET icon = '🔷' WHERE code = 'ICX' AND is_crypto = true; -- ICON图标
UPDATE currencies SET icon = '🔗' WHERE code = 'LSK' AND is_crypto = true; -- Lisk利斯克

-- ============================================================
-- NFT 和元宇宙
-- ============================================================
UPDATE currencies SET icon = '🦧' WHERE code = 'APE' AND is_crypto = true; -- 无聊猿
UPDATE currencies SET icon = '🎮' WHERE code = 'AXS' AND is_crypto = true; -- Axie游戏
UPDATE currencies SET icon = '🏖️' WHERE code = 'SAND' AND is_crypto = true; -- 沙盒
UPDATE currencies SET icon = '🌍' WHERE code = 'MANA' AND is_crypto = true; -- Decentraland元宇宙
UPDATE currencies SET icon = '⚔️' WHERE code = 'ENJ' AND is_crypto = true; -- Enjin币
UPDATE currencies SET icon = '🎰' WHERE code = 'GALA' AND is_crypto = true; -- Gala游戏
UPDATE currencies SET icon = '🖼️' WHERE code = 'BLUR' AND is_crypto = true; -- Blur市场
UPDATE currencies SET icon = '👀' WHERE code = 'LOOKS' AND is_crypto = true; -- LooksRare市场
UPDATE currencies SET icon = '📺' WHERE code = 'THETA' AND is_crypto = true; -- Theta网络
UPDATE currencies SET icon = '⛽' WHERE code = 'TFUEL' AND is_crypto = true; -- Theta燃料

-- ============================================================
-- AI 和数据服务
-- ============================================================
UPDATE currencies SET icon = '🤖' WHERE code = 'AGIX' AND is_crypto = true; -- 奇点网络
UPDATE currencies SET icon = '📈' WHERE code = 'GRT' AND is_crypto = true; -- 图表
UPDATE currencies SET icon = '🎨' WHERE code = 'RNDR' AND is_crypto = true; -- Render渲染
UPDATE currencies SET icon = '🤖' WHERE code = 'FET' AND is_crypto = true; -- Fetch智能
UPDATE currencies SET icon = '🌊' WHERE code = 'OCEAN' AND is_crypto = true; -- Ocean协议

-- ============================================================
-- 存储和基础设施
-- ============================================================
UPDATE currencies SET icon = '📁' WHERE code = 'FIL' AND is_crypto = true; -- Filecoin存储
UPDATE currencies SET icon = '💾' WHERE code = 'AR' AND is_crypto = true; -- Arweave存储
UPDATE currencies SET icon = '☁️' WHERE code = 'STORJ' AND is_crypto = true; -- Storj存储
UPDATE currencies SET icon = '💿' WHERE code = 'SC' AND is_crypto = true; -- Siacoin云储

-- ============================================================
-- 预言机和跨链
-- ============================================================
UPDATE currencies SET icon = '📡' WHERE code = 'BAND' AND is_crypto = true; -- Band协议
UPDATE currencies SET icon = '🌉' WHERE code = 'CELR' AND is_crypto = true; -- Celer网络
UPDATE currencies SET icon = '⚡' WHERE code = 'RUNE' AND is_crypto = true; -- THORChain雷神链
UPDATE currencies SET icon = '🔐' WHERE code = 'QNT' AND is_crypto = true; -- Quant量化
UPDATE currencies SET icon = '💉' WHERE code = 'INJ' AND is_crypto = true; -- Injective注入
UPDATE currencies SET icon = '🏔️' WHERE code = 'KAVA' AND is_crypto = true; -- Kava卡瓦

-- ============================================================
-- Meme 币
-- ============================================================
-- PEPE 🐸 (已有)
UPDATE currencies SET icon = '🐕' WHERE code = 'BONK' AND is_crypto = true; -- Bonk狗币
UPDATE currencies SET icon = '🐕' WHERE code = 'FLOKI' AND is_crypto = true; -- Floki狗币

-- ============================================================
-- 老牌主流币
-- ============================================================
UPDATE currencies SET icon = '💰' WHERE code = 'BCH' AND is_crypto = true; -- 比特币现金
UPDATE currencies SET icon = 'Ξ' WHERE code = 'ETC' AND is_crypto = true; -- 以太经典
UPDATE currencies SET icon = '🔒' WHERE code = 'ZEC' AND is_crypto = true; -- Zcash零币
UPDATE currencies SET icon = '💨' WHERE code = 'DASH' AND is_crypto = true; -- 达世币
UPDATE currencies SET icon = '🌅' WHERE code = 'EOS' AND is_crypto = true; -- EOS柚子
UPDATE currencies SET icon = '🟢' WHERE code = 'NEO' AND is_crypto = true; -- NEO小蚁
UPDATE currencies SET icon = '🔷' WHERE code = 'QTUM' AND is_crypto = true; -- Qtum量子链
UPDATE currencies SET icon = '♻️' WHERE code = 'VET' AND is_crypto = true; -- VeChain唯链
UPDATE currencies SET icon = '⚡' WHERE code = 'IOTA' AND is_crypto = true; -- IOTA埃欧塔
UPDATE currencies SET icon = '🔵' WHERE code = 'XTZ' AND is_crypto = true; -- Tezos特索斯
UPDATE currencies SET icon = '🔶' WHERE code = 'XEM' AND is_crypto = true; -- NEM新经币

-- ============================================================
-- 交易所平台币
-- ============================================================
UPDATE currencies SET icon = '💎' WHERE code = 'TON' AND is_crypto = true; -- Toncoin吨币
UPDATE currencies SET icon = '🦁' WHERE code = 'LEO' AND is_crypto = true; -- LEO代币
UPDATE currencies SET icon = '💵' WHERE code = 'BUSD' AND is_crypto = true; -- 币安美元
UPDATE currencies SET icon = '✅' WHERE code = 'TUSD' AND is_crypto = true; -- TrueUSD真美元
UPDATE currencies SET icon = '🔥' WHERE code = 'HT' AND is_crypto = true; -- 火币币
UPDATE currencies SET icon = '🅾️' WHERE code = 'OKB' AND is_crypto = true; -- OKB平台币
UPDATE currencies SET icon = '🅺' WHERE code = 'KCS' AND is_crypto = true; -- Kucoin币

-- ============================================================
-- 其他生态代币
-- ============================================================
UPDATE currencies SET icon = '⏩' WHERE code = 'BTT' AND is_crypto = true; -- 比特流
UPDATE currencies SET icon = '⚽' WHERE code = 'CHZ' AND is_crypto = true; -- Chiliz球迷币
UPDATE currencies SET icon = '📛' WHERE code = 'ENS' AND is_crypto = true; -- 以太坊域名
UPDATE currencies SET icon = '🔷' WHERE code = 'HOT' AND is_crypto = true; -- Holo全息链
UPDATE currencies SET icon = '🌹' WHERE code = 'ROSE' AND is_crypto = true; -- Oasis绿洲
UPDATE currencies SET icon = '🚀' WHERE code = 'RPL' AND is_crypto = true; -- Rocket Pool火箭池
UPDATE currencies SET icon = '❌' WHERE code = 'XDC' AND is_crypto = true; -- XDC网络
UPDATE currencies SET icon = '🔆' WHERE code = 'ZEN' AND is_crypto = true; -- Horizen地平线
UPDATE currencies SET icon = '⚡' WHERE code = 'EGLD' AND is_crypto = true; -- 多元宇宙

-- ============================================================
-- 验证：统计图标覆盖率
-- ============================================================
-- 此查询可手动执行验证
-- SELECT
--   COUNT(*) as total_crypto,
--   SUM(CASE WHEN icon IS NOT NULL THEN 1 ELSE 0 END) as has_icon,
--   ROUND(100.0 * SUM(CASE WHEN icon IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) as coverage_percent
-- FROM currencies
-- WHERE is_crypto = true;
