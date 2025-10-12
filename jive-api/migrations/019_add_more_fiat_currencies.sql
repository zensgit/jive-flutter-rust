-- Migration: Add more fiat currencies
-- Date: 2025-10-09
-- Description: Add 100+ additional fiat currencies to support global markets

INSERT INTO currencies (code, name, name_zh, symbol, decimal_places, is_active, is_crypto, is_popular, display_order)
VALUES
-- A
('AED', 'UAE Dirham', '阿联酋迪拉姆', 'د.إ', 2, true, false, false, 2001),
('AFN', 'Afghan Afghani', '阿富汗尼', '؋', 2, true, false, false, 2002),
('ALL', 'Albanian Lek', '阿尔巴尼亚列克', 'L', 2, true, false, false, 2003),
('AMD', 'Armenian Dram', '亚美尼亚德拉姆', '֏', 2, true, false, false, 2004),
('AOA', 'Angolan Kwanza', '安哥拉宽扎', 'Kz', 2, true, false, false, 2005),
('ARS', 'Argentine Peso', '阿根廷比索', 'ARS$', 2, true, false, false, 2006),
('AZN', 'Azerbaijani Manat', '阿塞拜疆马纳特', '₼', 2, true, false, false, 2007),

-- B
('BAM', 'Bosnia-Herzegovina Convertible Mark', '波黑可兑换马克', 'KM', 2, true, false, false, 2008),
('BBD', 'Barbadian Dollar', '巴巴多斯元', 'Bds$', 2, true, false, false, 2009),
('BDT', 'Bangladeshi Taka', '孟加拉塔卡', '৳', 2, true, false, false, 2010),
('BGN', 'Bulgarian Lev', '保加利亚列弗', 'лв', 2, true, false, false, 2011),
('BHD', 'Bahraini Dinar', '巴林第纳尔', '.د.ب', 3, true, false, false, 2012),
('BIF', 'Burundian Franc', '布隆迪法郎', 'FBu', 0, true, false, false, 2013),
('BMD', 'Bermudan Dollar', '百慕大元', 'BD$', 2, true, false, false, 2014),
('BND', 'Brunei Dollar', '文莱元', 'B$', 2, true, false, false, 2015),
('BOB', 'Bolivian Boliviano', '玻利维亚诺', 'Bs.', 2, true, false, false, 2016),
('BRL', 'Brazilian Real', '巴西雷亚尔', 'R$', 2, true, false, false, 2017),
('BSD', 'Bahamian Dollar', '巴哈马元', 'B$', 2, true, false, false, 2018),
('BTN', 'Bhutanese Ngultrum', '不丹努尔特鲁姆', 'Nu.', 2, true, false, false, 2019),
('BWP', 'Botswanan Pula', '博茨瓦纳普拉', 'P', 2, true, false, false, 2020),
('BYN', 'Belarusian Ruble', '白俄罗斯卢布', 'Br', 2, true, false, false, 2021),
('BZD', 'Belize Dollar', '伯利兹元', 'BZ$', 2, true, false, false, 2022),

-- C
('CDF', 'Congolese Franc', '刚果法郎', 'FC', 2, true, false, false, 2023),
('CLP', 'Chilean Peso', '智利比索', 'CLP$', 0, true, false, false, 2024),
('COP', 'Colombian Peso', '哥伦比亚比索', 'COP$', 2, true, false, false, 2025),
('CRC', 'Costa Rican Colón', '哥斯达黎加科朗', '₡', 2, true, false, false, 2026),
('CUP', 'Cuban Peso', '古巴比索', '$MN', 2, true, false, false, 2027),
('CVE', 'Cape Verdean Escudo', '佛得角埃斯库多', 'Esc', 2, true, false, false, 2028),
('CZK', 'Czech Koruna', '捷克克朗', 'Kč', 2, true, false, false, 2029),

-- D
('DJF', 'Djiboutian Franc', '吉布提法郎', 'Fdj', 0, true, false, false, 2030),
('DKK', 'Danish Krone', '丹麦克朗', 'kr', 2, true, false, false, 2031),
('DOP', 'Dominican Peso', '多米尼加比索', 'RD$', 2, true, false, false, 2032),
('DZD', 'Algerian Dinar', '阿尔及利亚第纳尔', 'د.ج', 2, true, false, false, 2033),

-- E
('EGP', 'Egyptian Pound', '埃及镑', 'E£', 2, true, false, false, 2034),
('ERN', 'Eritrean Nakfa', '厄立特里亚纳克法', 'Nfk', 2, true, false, false, 2035),
('ETB', 'Ethiopian Birr', '埃塞俄比亚比尔', 'Br', 2, true, false, false, 2036),

-- F
('FJD', 'Fijian Dollar', '斐济元', 'FJ$', 2, true, false, false, 2037),

-- G
('GEL', 'Georgian Lari', '格鲁吉亚拉里', '₾', 2, true, false, false, 2038),
('GHS', 'Ghanaian Cedi', '加纳塞地', '₵', 2, true, false, false, 2039),
('GMD', 'Gambian Dalasi', '冈比亚达拉西', 'D', 2, true, false, false, 2040),
('GNF', 'Guinean Franc', '几内亚法郎', 'GFr', 0, true, false, false, 2041),
('GTQ', 'Guatemalan Quetzal', '危地马拉格查尔', 'Q', 2, true, false, false, 2042),
('GYD', 'Guyanaese Dollar', '圭亚那元', 'G$', 2, true, false, false, 2043),

-- H
('HNL', 'Honduran Lempira', '洪都拉斯伦皮拉', 'L', 2, true, false, false, 2044),
('HRK', 'Croatian Kuna', '克罗地亚库纳', 'kn', 2, true, false, false, 2045),
('HTG', 'Haitian Gourde', '海地古德', 'G', 2, true, false, false, 2046),
('HUF', 'Hungarian Forint', '匈牙利福林', 'Ft', 2, true, false, false, 2047),

-- I
('IDR', 'Indonesian Rupiah', '印尼卢比', 'Rp', 2, true, false, false, 2048),
('ILS', 'Israeli New Shekel', '以色列新谢克尔', '₪', 2, true, false, false, 2049),
('IQD', 'Iraqi Dinar', '伊拉克第纳尔', 'ع.د', 3, true, false, false, 2050),
('IRR', 'Iranian Rial', '伊朗里亚尔', '﷼', 2, true, false, false, 2051),
('ISK', 'Icelandic Króna', '冰岛克朗', 'kr', 0, true, false, false, 2052),

-- J
('JMD', 'Jamaican Dollar', '牙买加元', 'J$', 2, true, false, false, 2053),
('JOD', 'Jordanian Dinar', '约旦第纳尔', 'د.ا', 3, true, false, false, 2054),

-- K
('KES', 'Kenyan Shilling', '肯尼亚先令', 'Sh', 2, true, false, false, 2055),
('KGS', 'Kyrgystani Som', '吉尔吉斯斯坦索姆', 'с', 2, true, false, false, 2056),
('KHR', 'Cambodian Riel', '柬埔寨瑞尔', '៛', 2, true, false, false, 2057),
('KMF', 'Comorian Franc', '科摩罗法郎', 'Com.F.', 0, true, false, false, 2058),
('KWD', 'Kuwaiti Dinar', '科威特第纳尔', 'د.ك', 3, true, false, false, 2059),
('KYD', 'Cayman Islands Dollar', '开曼群岛元', 'CI$', 2, true, false, false, 2060),
('KZT', 'Kazakhstani Tenge', '哈萨克斯坦坚戈', '₸', 2, true, false, false, 2061),

-- L
('LAK', 'Laotian Kip', '老挝基普', '₭', 2, true, false, false, 2062),
('LBP', 'Lebanese Pound', '黎巴嫩镑', 'ل.ل', 2, true, false, false, 2063),
('LKR', 'Sri Lankan Rupee', '斯里兰卡卢比', 'Rs', 2, true, false, false, 2064),
('LRD', 'Liberian Dollar', '利比里亚元', 'L$', 2, true, false, false, 2065),
('LSL', 'Lesotho Loti', '莱索托洛蒂', 'M', 2, true, false, false, 2066),
('LYD', 'Libyan Dinar', '利比亚第纳尔', 'LD', 3, true, false, false, 2067),

-- M
('MAD', 'Moroccan Dirham', '摩洛哥迪拉姆', 'د.م.', 2, true, false, false, 2068),
('MDL', 'Moldovan Leu', '摩尔多瓦列伊', 'L', 2, true, false, false, 2069),
('MKD', 'Macedonian Denar', '北马其顿第纳尔', 'ден', 2, true, false, false, 2070),
('MMK', 'Myanma Kyat', '缅甸元', 'Ks', 2, true, false, false, 2071),
('MNT', 'Mongolian Tugrik', '蒙古图格里克', '₮', 2, true, false, false, 2072),
('MOP', 'Macanese Pataca', '澳门币', 'MOP$', 2, true, false, false, 2073),
('MRU', 'Mauritanian Ouguiya', '毛里塔尼亚乌吉亚', 'UM', 2, true, false, false, 2074),
('MUR', 'Mauritian Rupee', '毛里求斯卢比', '₨', 2, true, false, false, 2075),
('MVR', 'Maldivian Rufiyaa', '马尔代夫拉菲亚', 'Rf', 2, true, false, false, 2076),
('MWK', 'Malawian Kwacha', '马拉维克瓦查', 'MWK', 2, true, false, false, 2077),
('MXN', 'Mexican Peso', '墨西哥比索', 'Mex$', 2, true, false, false, 2078),
('MZN', 'Mozambican Metical', '莫桑比克梅蒂卡尔', 'MT', 2, true, false, false, 2079),

-- N
('NAD', 'Namibian Dollar', '纳米比亚元', 'N$', 2, true, false, false, 2080),
('NGN', 'Nigerian Naira', '尼日利亚奈拉', '₦', 2, true, false, false, 2081),
('NIO', 'Nicaraguan Córdoba', '尼加拉瓜科多巴', 'C$', 2, true, false, false, 2082),
('NOK', 'Norwegian Krone', '挪威克朗', 'kr', 2, true, false, false, 2083),
('NPR', 'Nepalese Rupee', '尼泊尔卢比', 'N₨', 2, true, false, false, 2084),
('NZD', 'New Zealand Dollar', '新西兰元', 'NZ$', 2, true, false, false, 2085),

-- O
('OMR', 'Omani Rial', '阿曼里亚尔', 'ر.ع.', 3, true, false, false, 2086),

-- P
('PAB', 'Panamanian Balboa', '巴拿马巴波亚', 'B/.', 2, true, false, false, 2087),
('PEN', 'Peruvian Nuevo Sol', '秘鲁索尔', 'S/', 2, true, false, false, 2088),
('PGK', 'Papua New Guinean Kina', '巴布亚新几内亚基那', 'PGK', 2, true, false, false, 2089),
('PHP', 'Philippine Peso', '菲律宾比索', '₱', 2, true, false, false, 2090),
('PKR', 'Pakistani Rupee', '巴基斯坦卢比', '₨', 2, true, false, false, 2091),
('PLN', 'Polish Zloty', '波兰兹罗提', 'zł', 2, true, false, false, 2092),
('PYG', 'Paraguayan Guarani', '巴拉圭瓜拉尼', '₲', 0, true, false, false, 2093),

-- Q
('QAR', 'Qatari Rial', '卡塔尔里亚尔', 'ر.ق', 2, true, false, false, 2094),

-- R
('RON', 'Romanian Leu', '罗马尼亚列伊', 'L', 2, true, false, false, 2095),
('RSD', 'Serbian Dinar', '塞尔维亚第纳尔', 'дин.', 2, true, false, false, 2096),
('RUB', 'Russian Ruble', '俄罗斯卢布', '₽', 2, true, false, false, 2097),
('RWF', 'Rwandan Franc', '卢旺达法郎', 'FRw', 0, true, false, false, 2098),

-- S
('SAR', 'Saudi Riyal', '沙特里亚尔', 'ر.س', 2, true, false, false, 2099),
('SBD', 'Solomon Islands Dollar', '所罗门群岛元', 'SI$', 2, true, false, false, 2100),
('SDG', 'Sudanese Pound', '苏丹镑', '£SD', 2, true, false, false, 2101),
('SEK', 'Swedish Krona', '瑞典克朗', 'kr', 2, true, false, false, 2102),
('SLL', 'Sierra Leonean Leone', '塞拉利昂利昂', 'Le', 2, true, false, false, 2103),
('SOS', 'Somali Shilling', '索马里先令', 'Sh.So.', 2, true, false, false, 2104),
('SRD', 'Surinamese Dollar', '苏里南元', 'SRD', 2, true, false, false, 2105),
('SSP', 'South Sudanese Pound', '南苏丹镑', 'SS£', 2, true, false, false, 2106),
('SYP', 'Syrian Pound', '叙利亚镑', '£S', 2, true, false, false, 2107),
('SZL', 'Swazi Lilangeni', '斯威士兰里兰吉尼', 'L', 2, true, false, false, 2108),

-- T
('TMT', 'Turkmenistani Manat', '土库曼斯坦马纳特', 'T', 2, true, false, false, 2109),
('TND', 'Tunisian Dinar', '突尼斯第纳尔', 'د.ت', 3, true, false, false, 2110),
('TOP', 'Tongan Paʻanga', '汤加潘加', 'T$', 2, true, false, false, 2111),
('TRY', 'Turkish Lira', '土耳其里拉', '₺', 2, true, false, false, 2112),
('TTD', 'Trinidad and Tobago Dollar', '特立尼达和多巴哥元', 'TT$', 2, true, false, false, 2113),
('TVD', 'Tuvaluan Dollar', '图瓦卢元', 'TV$', 2, true, false, false, 2114),
('TZS', 'Tanzanian Shilling', '坦桑尼亚先令', 'Tsh', 2, true, false, false, 2115),

-- U
('UAH', 'Ukrainian Hryvnia', '乌克兰格里夫纳', '₴', 2, true, false, false, 2116),
('UGX', 'Ugandan Shilling', '乌干达先令', 'USh', 0, true, false, false, 2117),
('UYU', 'Uruguayan Peso', '乌拉圭比索', '$U', 2, true, false, false, 2118),
('UZS', 'Uzbekistan Som', '乌兹别克斯坦索姆', 'so''m', 2, true, false, false, 2119),

-- V
('VES', 'Venezuelan Bolívar', '委内瑞拉玻利瓦尔', 'Bs.S.', 2, true, false, false, 2120),
('VND', 'Vietnamese Dong', '越南盾', '₫', 0, true, false, false, 2121),
('VUV', 'Vanuatu Vatu', '瓦努阿图瓦图', 'VT', 0, true, false, false, 2122),

-- W
('WST', 'Samoan Tala', '萨摩亚塔拉', 'T', 2, true, false, false, 2123),

-- X
('XAF', 'Central African CFA Franc', '中非法郎', 'FCFA', 0, true, false, false, 2124),
('XCD', 'East Caribbean Dollar', '东加勒比元', 'EC$', 2, true, false, false, 2125),
('XOF', 'West African CFA Franc', '西非法郎', 'CFA', 0, true, false, false, 2126),
('XPF', 'CFP Franc', '太平洋法郎', '₣', 0, true, false, false, 2127),

-- Y
('YER', 'Yemeni Rial', '也门里亚尔', '﷼', 2, true, false, false, 2128),

-- Z
('ZAR', 'South African Rand', '南非兰特', 'R', 2, true, false, false, 2129),
('ZMW', 'Zambian Kwacha', '赞比亚克瓦查', 'ZK', 2, true, false, false, 2130),
('ZWL', 'Zimbabwean Dollar', '津巴布韦元', 'Z$', 2, true, false, false, 2131)

ON CONFLICT (code) DO NOTHING;
