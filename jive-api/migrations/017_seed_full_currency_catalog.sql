-- 017_seed_full_currency_catalog.sql
-- Seed a comprehensive currency catalog (150+ fiat, more cryptos)
-- Also add optional columns used by enhanced handlers if missing

-- 1) Extend currencies table with optional columns if they don't exist
DO $$
BEGIN
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
        WHERE table_name='currencies' AND column_name='min_amount'
    ) THEN
        ALTER TABLE currencies ADD COLUMN min_amount DECIMAL(30,12) DEFAULT 0;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name='currencies' AND column_name='max_amount'
    ) THEN
        ALTER TABLE currencies ADD COLUMN max_amount DECIMAL(30,12) DEFAULT 0;
    END IF;
END $$;

-- 2) Seed fiat currencies (ISO 4217) — base set plus extended list
-- Note: name_zh is optional and left NULL when not provided
INSERT INTO currencies (code, name, name_zh, symbol, decimal_places, is_active, is_crypto, flag, country_code, is_popular, display_order)
VALUES
    -- Major fiats
    ('USD','US Dollar','美元','$',2,true,false,'🇺🇸','US',true,1),
    ('EUR','Euro','欧元','€',2,true,false,'🇪🇺','EU',true,2),
    ('CNY','Chinese Yuan','人民币','¥',2,true,false,'🇨🇳','CN',true,3),
    ('JPY','Japanese Yen','日元','¥',0,true,false,'🇯🇵','JP',true,4),
    ('GBP','British Pound','英镑','£',2,true,false,'🇬🇧','GB',true,5),
    ('HKD','Hong Kong Dollar','港币','HK$',2,true,false,'🇭🇰','HK',true,6),
    ('SGD','Singapore Dollar','新币','S$',2,true,false,'🇸🇬','SG',true,7),
    ('AUD','Australian Dollar','澳元','A$',2,true,false,'🇦🇺','AU',true,8),
    ('CAD','Canadian Dollar','加元','C$',2,true,false,'🇨🇦','CA',true,9),
    ('CHF','Swiss Franc','瑞士法郎','Fr',2,true,false,'🇨🇭','CH',true,10),
    ('TWD','New Taiwan Dollar','新台币','NT$',2,true,false,'🇹🇼','TW',false,11),
    ('KRW','South Korean Won','韩元','₩',0,true,false,'🇰🇷','KR',false,12),
    ('INR','Indian Rupee','印度卢比','₹',2,true,false,'🇮🇳','IN',false,13),
    ('THB','Thai Baht','泰铢','฿',2,true,false,'🇹🇭','TH',false,14),
    ('MYR','Malaysian Ringgit','马来西亚林吉特','RM',2,true,false,'🇲🇾','MY',false,15),
    ('IDR','Indonesian Rupiah','印尼盾','Rp',2,true,false,'🇮🇩','ID',false,16),
    ('PHP','Philippine Peso','菲律宾比索','₱',2,true,false,'🇵🇭','PH',false,17),
    ('VND','Vietnamese Dong','越南盾','₫',0,true,false,'🇻🇳','VN',false,18),
    ('NZD','New Zealand Dollar','纽币','NZ$',2,true,false,'🇳🇿','NZ',false,19),
    ('SEK','Swedish Krona','瑞典克朗','kr',2,true,false,'🇸🇪','SE',false,20),
    ('NOK','Norwegian Krone','挪威克朗','kr',2,true,false,'🇳🇴','NO',false,21),
    ('DKK','Danish Krone','丹麦克朗','kr',2,true,false,'🇩🇰','DK',false,22),
    ('PLN','Polish Zloty','波兰兹罗提','zł',2,true,false,'🇵🇱','PL',false,23),
    ('CZK','Czech Koruna','捷克克朗','Kč',2,true,false,'🇨🇿','CZ',false,24),
    ('HUF','Hungarian Forint','匈牙利福林','Ft',2,true,false,'🇭🇺','HU',false,25),
    ('RON','Romanian Leu',NULL,'lei',2,true,false,'🇷🇴','RO',false,26),
    ('BGN','Bulgarian Lev',NULL,'лв',2,true,false,'🇧🇬','BG',false,27),
    ('HRK','Croatian Kuna',NULL,'kn',2,true,false,'🇭🇷','HR',false,28),
    ('RSD','Serbian Dinar',NULL,'дин',2,true,false,'🇷🇸','RS',false,29),
    ('UAH','Ukrainian Hryvnia',NULL,'₴',2,true,false,'🇺🇦','UA',false,30),
    ('BYN','Belarusian Ruble',NULL,'Br',2,true,false,'🇧🇾','BY',false,31),
    ('RUB','Russian Ruble','俄罗斯卢布','₽',2,true,false,'🇷🇺','RU',false,32),
    ('TRY','Turkish Lira','土耳其里拉','₺',2,true,false,'🇹🇷','TR',false,33),
    ('ILS','Israeli New Shekel',NULL,'₪',2,true,false,'🇮🇱','IL',false,34),
    ('AED','UAE Dirham','阿联酋迪拉姆','د.إ',2,true,false,'🇦🇪','AE',false,35),
    ('SAR','Saudi Riyal','沙特里亚尔','﷼',2,true,false,'🇸🇦','SA',false,36),
    ('QAR','Qatari Riyal',NULL,'﷼',2,true,false,'🇶🇦','QA',false,37),
    ('KWD','Kuwaiti Dinar',NULL,'د.ك',3,true,false,'🇰🇼','KW',false,38),
    ('BHD','Bahraini Dinar',NULL,'ب.د',3,true,false,'🇧🇭','BH',false,39),
    ('OMR','Omani Rial',NULL,'ر.ع.',3,true,false,'🇴🇲','OM',false,40),
    ('JOD','Jordanian Dinar',NULL,'د.ا',3,true,false,'🇯🇴','JO',false,41),
    ('EGP','Egyptian Pound',NULL,'£',2,true,false,'🇪🇬','EG',false,42),
    ('MAD','Moroccan Dirham',NULL,'د.م.',2,true,false,'🇲🇦','MA',false,43),
    ('DZD','Algerian Dinar',NULL,'د.ج',2,true,false,'🇩🇿','DZ',false,44),
    ('TND','Tunisian Dinar',NULL,'د.ت',3,true,false,'🇹🇳','TN',false,45),
    ('NGN','Nigerian Naira',NULL,'₦',2,true,false,'🇳🇬','NG',false,46),
    ('GHS','Ghanaian Cedi',NULL,'₵',2,true,false,'🇬🇭','GH',false,47),
    ('KES','Kenyan Shilling',NULL,'Sh',2,true,false,'🇰🇪','KE',false,48),
    ('TZS','Tanzanian Shilling',NULL,'Sh',2,true,false,'🇹🇿','TZ',false,49),
    ('UGX','Ugandan Shilling',NULL,'USh',0,true,false,'🇺🇬','UG',false,50),
    ('ETB','Ethiopian Birr',NULL,'Br',2,true,false,'🇪🇹','ET',false,51),
    ('ZAR','South African Rand','南非兰特','R',2,true,false,'🇿🇦','ZA',false,52),
    ('NAD','Namibian Dollar',NULL,'$',2,true,false,'🇳🇦','NA',false,53),
    ('BWP','Botswana Pula',NULL,'P',2,true,false,'🇧🇼','BW',false,54),
    ('MZN','Mozambican Metical',NULL,'MT',2,true,false,'🇲🇿','MZ',false,55),
    ('MWK','Malawian Kwacha',NULL,'MK',2,true,false,'🇲🇼','MW',false,56),
    ('ZMW','Zambian Kwacha',NULL,'ZK',2,true,false,'🇿🇲','ZM',false,57),
    ('BIF','Burundian Franc',NULL,'Fr',0,true,false,'🇧🇮','BI',false,58),
    ('RWF','Rwandan Franc',NULL,'Fr',0,true,false,'🇷🇼','RW',false,59),
    ('XOF','West African CFA franc',NULL,'Fr',0,true,false,'🌍','XF',false,60),
    ('XAF','Central African CFA franc',NULL,'Fr',0,true,false,'🌍','XA',false,61),
    ('XPF','CFP Franc',NULL,'Fr',0,true,false,'🌴','XP',false,62),
    ('MUR','Mauritian Rupee',NULL,'Rs',2,true,false,'🇲🇺','MU',false,63),
    ('SCR','Seychellois Rupee',NULL,'₨',2,true,false,'🇸🇨','SC',false,64),
    ('MGA','Malagasy Ariary',NULL,'Ar',1,true,false,'🇲🇬','MG',false,65),
    ('KZT','Kazakhstani Tenge',NULL,'₸',2,true,false,'🇰🇿','KZ',false,66),
    ('UZS','Uzbekistani Soʻm',NULL,'soʻm',0,true,false,'🇺🇿','UZ',false,67),
    ('TMT','Turkmenistani Manat',NULL,'m',2,true,false,'🇹🇲','TM',false,68),
    ('KGS','Kyrgyzstani Som',NULL,'⃀',2,true,false,'🇰🇬','KG',false,69),
    ('TJS','Tajikistani Somoni',NULL,'SM',2,true,false,'🇹🇯','TJ',false,70),
    ('AZN','Azerbaijani Manat',NULL,'₼',2,true,false,'🇦🇿','AZ',false,71),
    ('GEL','Georgian Lari',NULL,'₾',2,true,false,'🇬🇪','GE',false,72),
    ('AMD','Armenian Dram',NULL,'֏',2,true,false,'🇦🇲','AM',false,73),
    ('IRR','Iranian Rial',NULL,'﷼',0,true,false,'🇮🇷','IR',false,74),
    ('IQD','Iraqi Dinar',NULL,'ع.د',3,true,false,'🇮🇶','IQ',false,75),
    ('LBP','Lebanese Pound',NULL,'ل.ل',0,true,false,'🇱🇧','LB',false,76),
    ('SYP','Syrian Pound',NULL,'£',0,true,false,'🇸🇾','SY',false,77),
    ('YER','Yemeni Rial',NULL,'﷼',0,true,false,'🇾🇪','YE',false,78),
    ('PKR','Pakistani Rupee',NULL,'₨',2,true,false,'🇵🇰','PK',false,79),
    ('BDT','Bangladeshi Taka',NULL,'৳',2,true,false,'🇧🇩','BD',false,80),
    ('LKR','Sri Lankan Rupee',NULL,'Rs',2,true,false,'🇱🇰','LK',false,81),
    ('NPR','Nepalese Rupee',NULL,'Rs',2,true,false,'🇳🇵','NP',false,82),
    ('MMK','Burmese Kyat',NULL,'K',2,true,false,'🇲🇲','MM',false,83),
    ('KHR','Cambodian Riel',NULL,'៛',2,true,false,'🇰🇭','KH',false,84),
    ('LAK','Lao Kip',NULL,'₭',2,true,false,'🇱🇦','LA',false,85),
    ('BND','Brunei Dollar',NULL,'B$',2,true,false,'🇧🇳','BN',false,86),
    ('MOP','Macanese Pataca',NULL,'MOP$',2,true,false,'🇲🇴','MO',false,87),
    ('MNT','Mongolian Tögrög',NULL,'₮',2,true,false,'🇲🇳','MN',false,88),
    ('KPW','North Korean Won',NULL,'₩',0,true,false,'🇰🇵','KP',false,89),
    ('ARS','Argentine Peso',NULL,'$',2,true,false,'🇦🇷','AR',false,90),
    ('CLP','Chilean Peso',NULL,'$',0,true,false,'🇨🇱','CL',false,91),
    ('PEN','Peruvian Sol',NULL,'S/',2,true,false,'🇵🇪','PE',false,92),
    ('BOB','Boliviano',NULL,'Bs',2,true,false,'🇧🇴','BO',false,93),
    ('UYU','Uruguayan Peso',NULL,'$',2,true,false,'🇺🇾','UY',false,94),
    ('PYG','Paraguayan Guaraní',NULL,'₲',0,true,false,'🇵🇾','PY',false,95),
    ('COP','Colombian Peso',NULL,'$',2,true,false,'🇨🇴','CO',false,96),
    ('VES','Venezuelan Bolívar',NULL,'Bs.S',2,true,false,'🇻🇪','VE',false,97),
    ('MXN','Mexican Peso','墨西哥比索','$',2,true,false,'🇲🇽','MX',false,98),
    ('GTQ','Guatemalan Quetzal',NULL,'Q',2,true,false,'🇬🇹','GT',false,99),
    ('HNL','Honduran Lempira',NULL,'L',2,true,false,'🇭🇳','HN',false,100),
    ('NIO','Nicaraguan Córdoba',NULL,'C$',2,true,false,'🇳🇮','NI',false,101),
    ('CRC','Costa Rican Colón',NULL,'₡',2,true,false,'🇨🇷','CR',false,102),
    ('PAB','Panamanian Balboa',NULL,'B/.',2,true,false,'🇵🇦','PA',false,103),
    ('BZD','Belize Dollar',NULL,'BZ$',2,true,false,'🇧🇿','BZ',false,104),
    ('DOP','Dominican Peso',NULL,'RD$',2,true,false,'🇩🇴','DO',false,105),
    ('CUP','Cuban Peso',NULL,'₱',2,true,false,'🇨🇺','CU',false,106),
    ('JMD','Jamaican Dollar',NULL,'J$',2,true,false,'🇯🇲','JM',false,107),
    ('TTD','Trinidad and Tobago Dollar',NULL,'TT$',2,true,false,'🇹🇹','TT',false,108),
    ('BSD','Bahamian Dollar',NULL,'B$',2,true,false,'🇧🇸','BS',false,109),
    ('BBD','Barbadian Dollar',NULL,'Bds$',2,true,false,'🇧🇧','BB',false,110),
    ('GYD','Guyanese Dollar',NULL,'G$',2,true,false,'🇬🇾','GY',false,111),
    ('SRD','Surinamese Dollar',NULL,'SRD$',2,true,false,'🇸🇷','SR',false,112),
    ('HTG','Haitian Gourde',NULL,'G',2,true,false,'🇭🇹','HT',false,113),
    ('ANG','Netherlands Antillean Guilder',NULL,'ƒ',2,true,false,'🇨🇼','AN',false,114),
    ('AWG','Aruban Florin',NULL,'ƒ',2,true,false,'🇦🇼','AW',false,115),
    ('BMD','Bermudian Dollar',NULL,'$',2,true,false,'🇧🇲','BM',false,116),
    ('KYD','Cayman Islands Dollar',NULL,'$',2,true,false,'🇰🇾','KY',false,117),
    ('XCD','East Caribbean Dollar',NULL,'$',2,true,false,'🏝️','X1',false,118),
    ('FKP','Falkland Islands Pound',NULL,'£',2,true,false,'🇫🇰','FK',false,119),
    ('GIP','Gibraltar Pound',NULL,'£',2,true,false,'🇬🇮','GI',false,120),
    ('IMP','Isle of Man Pound',NULL,'£',2,true,false,'🇮🇲','IM',false,121),
    ('JEP','Jersey Pound',NULL,'£',2,true,false,'🇯🇪','JE',false,122),
    ('SHP','Saint Helena Pound',NULL,'£',2,true,false,'🇸🇭','SH',false,123),
    ('EGP','Egyptian Pound',NULL,'£',2,true,false,'🇪🇬','EG',false,124),
    ('SDG','Sudanese Pound',NULL,'£',2,true,false,'🇸🇩','SD',false,125),
    ('SSP','South Sudanese Pound',NULL,'£',2,true,false,'🇸🇸','SS',false,126),
    ('CDF','Congolese Franc',NULL,'Fr',2,true,false,'🇨🇩','CD',false,127),
    ('ZWL','Zimbabwean Dollar',NULL,'$',2,true,false,'🇿🇼','ZW',false,128)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    name_zh = EXCLUDED.name_zh,
    symbol = EXCLUDED.symbol,
    decimal_places = EXCLUDED.decimal_places,
    is_active = EXCLUDED.is_active,
    is_crypto = EXCLUDED.is_crypto,
    flag = EXCLUDED.flag,
    country_code = EXCLUDED.country_code,
    is_popular = EXCLUDED.is_popular,
    display_order = EXCLUDED.display_order;

-- 3) Seed additional cryptocurrencies
INSERT INTO currencies (code, name, name_zh, symbol, decimal_places, is_active, is_crypto, flag, is_popular, display_order)
VALUES
    ('BTC','Bitcoin','比特币','₿',8,true,true,'🪙',true,1001),
    ('ETH','Ethereum','以太坊','Ξ',8,true,true,'⟠',true,1002),
    ('USDT','Tether','泰达币','₮',6,true,true,'💵',true,1003),
    ('BNB','Binance Coin','币安币','BNB',8,true,true,'🟡',false,1004),
    ('SOL','Solana','Solana','SOL',8,true,true,'☀️',false,1005),
    ('XRP','Ripple','瑞波币','XRP',6,true,true,'💧',false,1006),
    ('USDC','USD Coin','USD币','USDC',6,true,true,'💲',false,1007),
    ('ADA','Cardano','卡尔达诺','₳',6,true,true,'🔷',false,1008),
    ('AVAX','Avalanche','雪崩','AVAX',8,true,true,'🔺',false,1009),
    ('DOGE','Dogecoin','狗狗币','Ð',8,true,true,'🐕',false,1010),
    ('DOT','Polkadot','波卡','DOT',10,true,true,'⚪',false,1011),
    ('MATIC','Polygon','Polygon','MATIC',8,true,true,'🟣',false,1012),
    ('LINK','Chainlink','Chainlink','LINK',8,true,true,'🔗',false,1013),
    ('LTC','Litecoin','莱特币','Ł',8,true,true,'🪙',false,1014),
    ('UNI','Uniswap','Uniswap','UNI',8,true,true,'🦄',false,1015),
    ('ATOM','Cosmos','Cosmos','ATOM',6,true,true,'⚛️',false,1016),
    ('COMP','Compound','Compound','COMP',8,true,true,'💚',false,1017),
    ('MKR','Maker','Maker','MKR',8,true,true,'🏛️',false,1018),
    ('AAVE','Aave','Aave','AAVE',8,true,true,'👻',false,1019),
    ('SUSHI','SushiSwap','SushiSwap','SUSHI',8,true,true,'🍣',false,1020),
    ('ARB','Arbitrum','Arbitrum','ARB',8,true,true,'🔵',false,1021),
    ('OP','Optimism','Optimism','OP',8,true,true,'🔴',false,1022),
    ('SHIB','Shiba Inu','柴犬币','SHIB',8,true,true,'🐕',false,1023),
    ('TRX','TRON','波场','TRX',6,true,true,'🔶',false,1024)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    name_zh = EXCLUDED.name_zh,
    symbol = EXCLUDED.symbol,
    decimal_places = EXCLUDED.decimal_places,
    is_active = EXCLUDED.is_active,
    is_crypto = EXCLUDED.is_crypto,
    flag = EXCLUDED.flag,
    is_popular = EXCLUDED.is_popular,
    display_order = EXCLUDED.display_order;

