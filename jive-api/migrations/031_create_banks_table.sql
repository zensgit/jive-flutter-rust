-- 创建银行表，支持拼音搜索
CREATE TABLE banks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    name_cn VARCHAR(100),
    name_en VARCHAR(200),
    name_cn_pinyin VARCHAR(200),
    name_cn_abbr VARCHAR(50),
    icon_filename VARCHAR(100),
    icon_url TEXT,
    is_crypto BOOLEAN DEFAULT FALSE,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_banks_code ON banks(code);
CREATE INDEX idx_banks_name_cn ON banks(name_cn);
CREATE INDEX idx_banks_pinyin ON banks(name_cn_pinyin);
CREATE INDEX idx_banks_abbr ON banks(name_cn_abbr);
CREATE INDEX idx_banks_is_active ON banks(is_active);
CREATE INDEX idx_banks_sort_order ON banks(sort_order DESC, name_cn);

COMMENT ON TABLE banks IS '银行和金融机构表';
COMMENT ON COLUMN banks.code IS '唯一标识码（从icon文件名提取）';
COMMENT ON COLUMN banks.name IS '银行名称（主名称）';
COMMENT ON COLUMN banks.name_cn IS '中文名称';
COMMENT ON COLUMN banks.name_en IS '英文名称';
COMMENT ON COLUMN banks.name_cn_pinyin IS '中文全拼（用于拼音搜索）';
COMMENT ON COLUMN banks.name_cn_abbr IS '中文简拼（用于首字母搜索）';
COMMENT ON COLUMN banks.icon_filename IS '图标文件名';
COMMENT ON COLUMN banks.is_crypto IS '是否为加密货币';
COMMENT ON COLUMN banks.sort_order IS '排序权重（热门银行可设置更高值）';
COMMENT ON COLUMN banks.is_active IS '是否启用';