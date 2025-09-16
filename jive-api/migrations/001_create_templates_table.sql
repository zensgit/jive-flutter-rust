-- 创建系统分类模板表
CREATE TABLE IF NOT EXISTS system_category_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50) NOT NULL,
    color VARCHAR(10) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('expense', 'income')),
    parent_id UUID REFERENCES system_category_templates(id) ON DELETE CASCADE,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    lang VARCHAR(10) DEFAULT 'zh-CN',
    version INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_templates_type ON system_category_templates(type);
CREATE INDEX IF NOT EXISTS idx_templates_parent ON system_category_templates(parent_id);
CREATE INDEX IF NOT EXISTS idx_templates_lang ON system_category_templates(lang);
CREATE INDEX IF NOT EXISTS idx_templates_active ON system_category_templates(is_active);

-- 插入默认数据
INSERT INTO system_category_templates (name, icon, color, type, display_order) VALUES
('餐饮', 'restaurant', '#FF6B6B', 'expense', 1),
('交通', 'directions_car', '#4ECDC4', 'expense', 2),
('购物', 'shopping_cart', '#45B7D1', 'expense', 3),
('娱乐', 'sports_esports', '#96CEB4', 'expense', 4),
('医疗', 'local_hospital', '#FF8E53', 'expense', 5),
('教育', 'school', '#DDA0DD', 'expense', 6),
('居家', 'home', '#98D8C8', 'expense', 7),
('工资', 'account_balance_wallet', '#66BB6A', 'income', 1),
('奖金', 'card_giftcard', '#FFA726', 'income', 2),
('投资', 'trending_up', '#42A5F5', 'income', 3)
ON CONFLICT DO NOTHING;