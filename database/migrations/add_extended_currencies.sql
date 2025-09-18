-- add_extended_currencies.sql
-- 添加用户提供的扩展货币列表到现有系统
-- 这些货币将添加到已有的货币表中

-- 确保currencies表具有所需的列结构
DO $$
BEGIN
    -- 检查并添加可选列
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='currencies' AND column_name='country_code'
    ) THEN
        ALTER TABLE currencies ADD COLUMN country_code VARCHAR(4);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='currencies' AND column_name='is_popular'
    ) THEN
        ALTER TABLE currencies ADD COLUMN is_popular BOOLEAN DEFAULT false;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='currencies' AND column_name='display_order'
    ) THEN
        ALTER TABLE currencies ADD COLUMN display_order INTEGER DEFAULT 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='currencies' AND column_name='is_crypto'
    ) THEN
        ALTER TABLE currencies ADD COLUMN is_crypto BOOLEAN DEFAULT false;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='currencies' AND column_name='flag'
    ) THEN
        ALTER TABLE currencies ADD COLUMN flag VARCHAR(10);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name='currencies' AND column_name='name_zh'
    ) THEN
        ALTER TABLE currencies ADD COLUMN name_zh VARCHAR(100);
    END IF;
END $$;

-- 插入扩展的法定货币列表（基于用户提供的表格）
INSERT INTO currencies (code, name, name_zh, symbol, decimal_places, is_active, is_crypto, country_code, is_popular, display_order)
VALUES
    -- 基础货币更新（确保符号正确）
    ('AED', 'UAE Dirham', '阿联酋迪拉姆', 'د.إ', 2, true, false, 'AE', false, 200),
    ('AFN', 'Afghan Afghani', '阿富汗尼', '؋', 2, true, false, 'AF', false, 201),
    ('ALL', 'Albanian Lek', '阿尔巴尼亚列克', 'L', 2, true, false, 'AL', false, 202),
    ('AMD', 'Armenian Dram', '亚美尼亚德拉姆', '֏', 2, true, false, 'AM', false, 203),
    ('AOA', 'Angolan Kwanza', '安哥拉宽扎', 'Kz', 2, true, false, 'AO', false, 204),
    ('ARS', 'Argentine Peso', '阿根廷比索', 'ARS$', 2, true, false, 'AR', false, 205),
    ('AZN', 'Azerbaijani Manat', '阿塞拜疆马纳特', '₼', 2, true, false, 'AZ', false, 206),
    ('BAM', 'Bosnia-Herzegovina Convertible Mark', '波黑可兑换马克', 'KM', 2, true, false, 'BA', false, 207),
    ('BBD', 'Barbadian Dollar', '巴巴多斯元', 'Bds$', 2, true, false, 'BB', false, 208),
    ('BDT', 'Bangladeshi Taka', '孟加拉塔卡', '৳', 2, true, false, 'BD', false, 209),
    ('BGN', 'Bulgarian Lev', '保加利亚列弗', 'лв', 2, true, false, 'BG', false, 210),
    ('BHD', 'Bahraini Dinar', '巴林第纳尔', '.د.ب', 3, true, false, 'BH', false, 211),
    ('BIF', 'Burundian Franc', '布隆迪法郎', 'FBu', 0, true, false, 'BI', false, 212),
    ('BMD', 'Bermudian Dollar', '百慕大元', 'BD$', 2, true, false, 'BM', false, 213),
    ('BND', 'Brunei Dollar', '文莱元', 'B$', 2, true, false, 'BN', false, 214),
    ('BOB', 'Bolivian Boliviano', '玻利维亚诺', 'Bs.', 2, true, false, 'BO', false, 215),
    ('BRL', 'Brazilian Real', '巴西雷亚尔', 'R$', 2, true, false, 'BR', false, 216),
    ('BSD', 'Bahamian Dollar', '巴哈马元', 'B$', 2, true, false, 'BS', false, 217),
    ('BTN', 'Bhutanese Ngultrum', '不丹努尔特鲁姆', 'Nu.', 2, true, false, 'BT', false, 218),
    ('BWP', 'Botswanan Pula', '博茨瓦纳普拉', 'P', 2, true, false, 'BW', false, 219),
    ('BYN', 'Belarusian Ruble', '白俄罗斯卢布', 'Br', 2, true, false, 'BY', false, 220),
    ('BZD', 'Belize Dollar', '伯利兹元', 'BZ$', 2, true, false, 'BZ', false, 221),
    ('CDF', 'Congolese Franc', '刚果法郎', 'FC', 2, true, false, 'CD', false, 222),
    ('CLP', 'Chilean Peso', '智利比索', 'CLP$', 0, true, false, 'CL', false, 223),
    ('COP', 'Colombian Peso', '哥伦比亚比索', 'COP$', 2, true, false, 'CO', false, 224),
    ('CRC', 'Costa Rican Colón', '哥斯达黎加科朗', '₡', 2, true, false, 'CR', false, 225),
    ('CUP', 'Cuban Peso', '古巴比索', '$MN', 2, true, false, 'CU', false, 226),
    ('CVE', 'Cape Verdean Escudo', '佛得角埃斯库多', 'Esc', 2, true, false, 'CV', false, 227),
    ('CZK', 'Czech Koruna', '捷克克朗', 'Kč', 2, true, false, 'CZ', false, 228),
    ('DJF', 'Djiboutian Franc', '吉布提法郎', 'Fdj', 0, true, false, 'DJ', false, 229),
    ('DKK', 'Danish Krone', '丹麦克朗', 'kr', 2, true, false, 'DK', false, 230),
    ('DOP', 'Dominican Peso', '多米尼加比索', 'RD$', 2, true, false, 'DO', false, 231),
    ('DZD', 'Algerian Dinar', '阿尔及利亚第纳尔', 'د.ج', 2, true, false, 'DZ', false, 232),
    ('EGP', 'Egyptian Pound', '埃及镑', 'E£', 2, true, false, 'EG', false, 233),
    ('ERN', 'Eritrean Nakfa', '厄立特里亚纳克法', 'Nfk', 2, true, false, 'ER', false, 234),
    ('ETB', 'Ethiopian Birr', '埃塞俄比亚比尔', 'Br', 2, true, false, 'ET', false, 235),
    ('FJD', 'Fijian Dollar', '斐济元', 'FJ$', 2, true, false, 'FJ', false, 236),
    ('GEL', 'Georgian Lari', '格鲁吉亚拉里', '₾', 2, true, false, 'GE', false, 237),
    ('GHS', 'Ghanaian Cedi', '加纳塞地', '₵', 2, true, false, 'GH', false, 238),
    ('GMD', 'Gambian Dalasi', '冈比亚达拉西', 'D', 2, true, false, 'GM', false, 239),
    ('GNF', 'Guinean Franc', '几内亚法郎', 'GFr', 0, true, false, 'GN', false, 240),
    ('GTQ', 'Guatemalan Quetzal', '危地马拉格查尔', 'Q', 2, true, false, 'GT', false, 241),
    ('GYD', 'Guyanese Dollar', '圭亚那元', 'G$', 2, true, false, 'GY', false, 242),
    ('HNL', 'Honduran Lempira', '洪都拉斯伦皮拉', 'L', 2, true, false, 'HN', false, 243),
    ('HRK', 'Croatian Kuna', '克罗地亚库纳', 'kn', 2, true, false, 'HR', false, 244),
    ('HTG', 'Haitian Gourde', '海地古德', 'G', 2, true, false, 'HT', false, 245),
    ('HUF', 'Hungarian Forint', '匈牙利福林', 'Ft', 2, true, false, 'HU', false, 246),
    ('IDR', 'Indonesian Rupiah', '印尼卢比', 'Rp', 2, true, false, 'ID', false, 247),
    ('ILS', 'Israeli New Shekel', '以色列新谢克尔', '₪', 2, true, false, 'IL', false, 248),
    ('IQD', 'Iraqi Dinar', '伊拉克第纳尔', 'ع.د', 3, true, false, 'IQ', false, 249),
    ('IRR', 'Iranian Rial', '伊朗里亚尔', '﷼', 2, true, false, 'IR', false, 250),
    ('ISK', 'Icelandic Króna', '冰岛克朗', 'kr', 2, true, false, 'IS', false, 251),
    ('JMD', 'Jamaican Dollar', '牙买加元', 'J$', 2, true, false, 'JM', false, 252),
    ('JOD', 'Jordanian Dinar', '约旦第纳尔', 'د.ا', 3, true, false, 'JO', false, 253),
    ('KES', 'Kenyan Shilling', '肯尼亚先令', 'Sh', 2, true, false, 'KE', false, 254),
    ('KGS', 'Kyrgystani Som', '吉尔吉斯斯坦索姆', 'с', 2, true, false, 'KG', false, 255),
    ('KHR', 'Cambodian Riel', '柬埔寨瑞尔', '៛', 2, true, false, 'KH', false, 256),
    ('KMF', 'Comorian Franc', '科摩罗法郎', 'Com.F.', 0, true, false, 'KM', false, 257),
    ('KWD', 'Kuwaiti Dinar', '科威特第纳尔', 'د.ك', 3, true, false, 'KW', false, 258),
    ('KYD', 'Cayman Islands Dollar', '开曼群岛元', 'CI$', 2, true, false, 'KY', false, 259),
    ('KZT', 'Kazakhstani Tenge', '哈萨克斯坦坚戈', '₸', 2, true, false, 'KZ', false, 260),
    ('LAK', 'Laotian Kip', '老挝基普', '₭', 2, true, false, 'LA', false, 261),
    ('LBP', 'Lebanese Pound', '黎巴嫩镑', 'ل.ل', 2, true, false, 'LB', false, 262),
    ('LKR', 'Sri Lankan Rupee', '斯里兰卡卢比', 'Rs', 2, true, false, 'LK', false, 263),
    ('LRD', 'Liberian Dollar', '利比里亚元', 'L$', 2, true, false, 'LR', false, 264),
    ('LSL', 'Lesotho Loti', '莱索托洛蒂', 'M', 2, true, false, 'LS', false, 265),
    ('LYD', 'Libyan Dinar', '利比亚第纳尔', 'LD', 3, true, false, 'LY', false, 266),
    ('MAD', 'Moroccan Dirham', '摩洛哥迪拉姆', 'د.م.', 2, true, false, 'MA', false, 267),
    ('MDL', 'Moldovan Leu', '摩尔多瓦列伊', 'L', 2, true, false, 'MD', false, 268),
    ('MKD', 'Macedonian Denar', '北马其顿第纳尔', 'ден', 2, true, false, 'MK', false, 269),
    ('MMK', 'Myanmar Kyat', '缅甸元', 'Ks', 2, true, false, 'MM', false, 270),
    ('MNT', 'Mongolian Tugrik', '蒙古图格里克', '₮', 2, true, false, 'MN', false, 271),
    ('MOP', 'Macanese Pataca', '澳门币', 'MOP$', 2, true, false, 'MO', false, 272),
    ('MRU', 'Mauritanian Ouguiya', '毛里塔尼亚乌吉亚', 'UM', 2, true, false, 'MR', false, 273),
    ('MUR', 'Mauritian Rupee', '毛里求斯卢比', '₨', 2, true, false, 'MU', false, 274),
    ('MVR', 'Maldivian Rufiyaa', '马尔代夫拉菲亚', 'Rf', 2, true, false, 'MV', false, 275),
    ('MWK', 'Malawian Kwacha', '马拉维克瓦查', 'MWK', 2, true, false, 'MW', false, 276),
    ('MXN', 'Mexican Peso', '墨西哥比索', 'Mex$', 2, true, false, 'MX', false, 277),
    ('MZN', 'Mozambican Metical', '莫桑比克梅蒂卡尔', 'MT', 2, true, false, 'MZ', false, 278),
    ('NAD', 'Namibian Dollar', '纳米比亚元', 'N$', 2, true, false, 'NA', false, 279),
    ('NGN', 'Nigerian Naira', '尼日利亚奈拉', '₦', 2, true, false, 'NG', false, 280),
    ('NIO', 'Nicaraguan Córdoba', '尼加拉瓜科多巴', 'C$', 2, true, false, 'NI', false, 281),
    ('NOK', 'Norwegian Krone', '挪威克朗', 'kr', 2, true, false, 'NO', false, 282),
    ('NPR', 'Nepalese Rupee', '尼泊尔卢比', 'N₨', 2, true, false, 'NP', false, 283),
    ('NZD', 'New Zealand Dollar', '新西兰元', 'NZ$', 2, true, false, 'NZ', false, 284),
    ('OMR', 'Omani Rial', '阿曼里亚尔', 'ر.ع.', 3, true, false, 'OM', false, 285),
    ('PAB', 'Panamanian Balboa', '巴拿马巴波亚', 'B/.', 2, true, false, 'PA', false, 286),
    ('PEN', 'Peruvian Nuevo Sol', '秘鲁索尔', 'S/', 2, true, false, 'PE', false, 287),
    ('PGK', 'Papua New Guinean Kina', '巴布亚新几内亚基那', 'PGK', 2, true, false, 'PG', false, 288),
    ('PHP', 'Philippine Peso', '菲律宾比索', '₱', 2, true, false, 'PH', false, 289),
    ('PKR', 'Pakistani Rupee', '巴基斯坦卢比', '₨', 2, true, false, 'PK', false, 290),
    ('PLN', 'Polish Zloty', '波兰兹罗提', 'zł', 2, true, false, 'PL', false, 291),
    ('PYG', 'Paraguayan Guarani', '巴拉圭瓜拉尼', '₲', 0, true, false, 'PY', false, 292),
    ('QAR', 'Qatari Rial', '卡塔尔里亚尔', 'ر.ق', 2, true, false, 'QA', false, 293),
    ('RON', 'Romanian Leu', '罗马尼亚列伊', 'L', 2, true, false, 'RO', false, 294),
    ('RSD', 'Serbian Dinar', '塞尔维亚第纳尔', 'дин.', 2, true, false, 'RS', false, 295),
    ('RUB', 'Russian Ruble', '俄罗斯卢布', '₽', 2, true, false, 'RU', false, 296),
    ('RWF', 'Rwandan Franc', '卢旺达法郎', 'FRw', 0, true, false, 'RW', false, 297),
    ('SAR', 'Saudi Riyal', '沙特里亚尔', 'ر.س', 2, true, false, 'SA', false, 298),
    ('SBD', 'Solomon Islands Dollar', '所罗门群岛元', 'SI$', 2, true, false, 'SB', false, 299),
    ('SDG', 'Sudanese Pound', '苏丹镑', '£SD', 2, true, false, 'SD', false, 300),
    ('SEK', 'Swedish Krona', '瑞典克朗', 'kr', 2, true, false, 'SE', false, 301),
    ('SLL', 'Sierra Leonean Leone', '塞拉利昂利昂', 'Le', 2, true, false, 'SL', false, 302),
    ('SOS', 'Somali Shilling', '索马里先令', 'Sh.So.', 2, true, false, 'SO', false, 303),
    ('SRD', 'Surinamese Dollar', '苏里南元', 'SRD', 2, true, false, 'SR', false, 304),
    ('SSP', 'South Sudanese Pound', '南苏丹镑', 'SS£', 2, true, false, 'SS', false, 305),
    ('SYP', 'Syrian Pound', '叙利亚镑', '£S', 2, true, false, 'SY', false, 306),
    ('SZL', 'Swazi Lilangeni', '斯威士兰里兰吉尼', 'L', 2, true, false, 'SZ', false, 307),
    ('TMT', 'Turkmenistani Manat', '土库曼斯坦马纳特', 'T', 2, true, false, 'TM', false, 308),
    ('TND', 'Tunisian Dinar', '突尼斯第纳尔', 'د.ت', 3, true, false, 'TN', false, 309),
    ('TOP', 'Tongan Paʻanga', '汤加潘加', 'T$', 2, true, false, 'TO', false, 310),
    ('TRY', 'Turkish Lira', '土耳其里拉', '₺', 2, true, false, 'TR', false, 311),
    ('TTD', 'Trinidad and Tobago Dollar', '特立尼达和多巴哥元', 'TT$', 2, true, false, 'TT', false, 312),
    ('TVD', 'Tuvaluan Dollar', '图瓦卢元', 'TV$', 2, true, false, 'TV', false, 313),
    ('TZS', 'Tanzanian Shilling', '坦桑尼亚先令', 'Tsh', 2, true, false, 'TZ', false, 314),
    ('UAH', 'Ukrainian Hryvnia', '乌克兰格里夫纳', '₴', 2, true, false, 'UA', false, 315),
    ('UGX', 'Ugandan Shilling', '乌干达先令', 'USh', 0, true, false, 'UG', false, 316),
    ('UYU', 'Uruguayan Peso', '乌拉圭比索', '$U', 2, true, false, 'UY', false, 317),
    ('UZS', 'Uzbekistan Som', '乌兹别克斯坦索姆', 'soʻm', 2, true, false, 'UZ', false, 318),
    ('VES', 'Venezuelan Bolívar', '委内瑞拉玻利瓦尔', 'Bs.S', 2, true, false, 'VE', false, 319),
    ('VND', 'Vietnamese Dong', '越南盾', '₫', 0, true, false, 'VN', false, 320),
    ('VUV', 'Vanuatuan Vatu', '瓦努阿图瓦图', 'VT', 0, true, false, 'VU', false, 321),
    ('WST', 'Samoan Tala', '萨摩亚塔拉', 'WS$', 2, true, false, 'WS', false, 322),
    ('XAF', 'Central African CFA Franc', '中非法郎', 'FCFA', 0, true, false, 'XF', false, 323),
    ('XCD', 'East Caribbean Dollar', '东加勒比元', 'EC$', 2, true, false, 'XC', false, 324),
    ('XOF', 'West African CFA Franc', '西非法郎', 'CFA', 0, true, false, 'XO', false, 325),
    ('XPF', 'CFP Franc', '太平洋法郎', 'F', 0, true, false, 'XP', false, 326),
    ('YER', 'Yemeni Rial', '也门里亚尔', '﷼', 2, true, false, 'YE', false, 327),
    ('ZAR', 'South African Rand', '南非兰特', 'R', 2, true, false, 'ZA', false, 328),
    ('ZMW', 'Zambian Kwacha', '赞比亚克瓦查', 'ZK', 2, true, false, 'ZM', false, 329),
    ('ZWL', 'Zimbabwean Dollar', '津巴布韦元', 'Z$', 2, true, false, 'ZW', false, 330)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    name_zh = EXCLUDED.name_zh,
    symbol = EXCLUDED.symbol,
    decimal_places = EXCLUDED.decimal_places,
    is_active = EXCLUDED.is_active,
    is_crypto = EXCLUDED.is_crypto,
    country_code = EXCLUDED.country_code,
    is_popular = EXCLUDED.is_popular,
    display_order = EXCLUDED.display_order;

-- 更新现有基础货币的中文名称和符号（确保一致性）
UPDATE currencies SET
    name_zh = '人民币', symbol = '¥' WHERE code = 'CNY';
UPDATE currencies SET
    name_zh = '美元', symbol = '$' WHERE code = 'USD';
UPDATE currencies SET
    name_zh = '欧元', symbol = '€' WHERE code = 'EUR';
UPDATE currencies SET
    name_zh = '英镑', symbol = '£' WHERE code = 'GBP';
UPDATE currencies SET
    name_zh = '日元', symbol = 'J¥', decimal_places = 0 WHERE code = 'JPY';
UPDATE currencies SET
    name_zh = '港币', symbol = 'HK$' WHERE code = 'HKD';
UPDATE currencies SET
    name_zh = '新台币', symbol = 'NT$' WHERE code = 'TWD';
UPDATE currencies SET
    name_zh = '新加坡元', symbol = 'S$' WHERE code = 'SGD';
UPDATE currencies SET
    name_zh = '澳元', symbol = 'A$' WHERE code = 'AUD';
UPDATE currencies SET
    name_zh = '加元', symbol = 'C$' WHERE code = 'CAD';
UPDATE currencies SET
    name_zh = '瑞士法郎', symbol = 'Fr' WHERE code = 'CHF';
UPDATE currencies SET
    name_zh = '韩元', symbol = '₩', decimal_places = 0 WHERE code = 'KRW';
UPDATE currencies SET
    name_zh = '印度卢比', symbol = '₹' WHERE code = 'INR';
UPDATE currencies SET
    name_zh = '泰铢', symbol = '฿' WHERE code = 'THB';
UPDATE currencies SET
    name_zh = '马来西亚林吉特', symbol = 'RM' WHERE code = 'MYR';

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_currencies_is_popular ON currencies(is_popular);
CREATE INDEX IF NOT EXISTS idx_currencies_is_crypto ON currencies(is_crypto);
CREATE INDEX IF NOT EXISTS idx_currencies_country_code ON currencies(country_code);
CREATE INDEX IF NOT EXISTS idx_currencies_display_order ON currencies(display_order);

-- 统计报告
DO $$
DECLARE
    fiat_count INTEGER;
    crypto_count INTEGER;
    total_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO fiat_count FROM currencies WHERE is_crypto = false AND is_active = true;
    SELECT COUNT(*) INTO crypto_count FROM currencies WHERE is_crypto = true AND is_active = true;
    SELECT COUNT(*) INTO total_count FROM currencies WHERE is_active = true;

    RAISE NOTICE '货币添加完成！';
    RAISE NOTICE '法定货币数量: %', fiat_count;
    RAISE NOTICE '加密货币数量: %', crypto_count;
    RAISE NOTICE '总货币数量: %', total_count;
END $$;