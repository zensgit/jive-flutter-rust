const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// Mock user data
const mockUser = {
  id: "00000000-0000-0000-0000-000000000001",
  email: "test@example.com",
  name: "Test User",
  avatar_url: null,
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString()
};

// Auth endpoints
app.get('/api/v1/auth/profile', (req, res) => {
  res.json({
    success: true,
    data: mockUser
  });
});

app.get('/api/v1/auth/profile-enhanced', (req, res) => {
  res.json({
    success: true,
    data: {
      ...mockUser,
      country: 'CN',
      preferred_currency: 'CNY',
      preferred_language: 'zh-CN',
      preferred_timezone: 'Asia/Shanghai',
      preferred_date_format: 'YYYY-MM-DD'
    }
  });
});

app.put('/api/v1/auth/user', (req, res) => {
  res.json({ success: true, data: { ...mockUser, ...req.body } });
});

app.put('/api/v1/auth/avatar', (req, res) => {
  res.json({ success: true, data: { message: 'Avatar updated' } });
});

app.put('/api/v1/auth/preferences', (req, res) => {
  res.json({ success: true, data: { message: 'Preferences updated' } });
});

app.post('/api/v1/auth/reset-account', (req, res) => {
  res.json({ success: true, data: { message: 'Account reset successfully' } });
});

app.get('/api/v1/locales', (req, res) => {
  res.json({
    success: true,
    data: {
      countries: [
        { code: 'CN', name: '中国' },
        { code: 'US', name: '美国' },
        { code: 'GB', name: '英国' },
        { code: 'JP', name: '日本' }
      ],
      currencies: [
        { code: 'CNY', name: '人民币', symbol: '¥' },
        { code: 'USD', name: '美元', symbol: '$' },
        { code: 'EUR', name: '欧元', symbol: '€' },
        { code: 'GBP', name: '英镑', symbol: '£' },
        { code: 'JPY', name: '日元', symbol: '¥' }
      ],
      languages: [
        { code: 'zh-CN', name: '简体中文' },
        { code: 'en-US', name: 'English' },
        { code: 'ja-JP', name: '日本語' }
      ],
      timezones: [
        { zone: 'Asia/Shanghai', name: '北京时间' },
        { zone: 'America/New_York', name: '纽约时间' },
        { zone: 'Europe/London', name: '伦敦时间' },
        { zone: 'Asia/Tokyo', name: '东京时间' }
      ],
      date_formats: [
        { format: 'YYYY-MM-DD', example: '2024-12-31' },
        { format: 'MM/DD/YYYY', example: '12/31/2024' },
        { format: 'DD/MM/YYYY', example: '31/12/2024' }
      ]
    }
  });
});

// Ledger endpoints
app.get('/api/v1/ledgers/current', (req, res) => {
  res.json({
    success: true,
    data: {
      id: "00000000-0000-0000-0000-000000000001",
      name: "个人账本",
      type: "personal",
      currency: "CNY",
      is_default: true,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }
  });
});

app.get('/api/v1/ledgers', (req, res) => {
  res.json({
    success: true,
    data: {
      ledgers: [{
        id: "00000000-0000-0000-0000-000000000001",
        name: "个人账本",
        type: "personal",
        currency: "CNY",
        is_default: true,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }],
      total: 1,
      page: 1,
      per_page: 20
    }
  });
});

app.post('/api/v1/ledgers', (req, res) => {
  res.json({
    success: true,
    data: {
      id: "00000000-0000-0000-0000-000000000002",
      name: req.body.name || "新账本",
      type: req.body.type || "personal",
      currency: req.body.currency || "CNY",
      is_default: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }
  });
});

// Budget endpoints
app.get('/api/v1/budgets/summary', (req, res) => {
  res.json({
    success: true,
    data: {
      total_budget: 10000,
      spent: 3500,
      remaining: 6500,
      percentage: 35,
      budgets: []
    }
  });
});

// Transaction endpoints
app.get('/api/v1/transactions', (req, res) => {
  res.json({
    success: true,
    data: {
      transactions: [],
      total: 0,
      page: 1,
      per_page: 20
    }
  });
});

app.get('/api/v1/transactions/recent', (req, res) => {
  res.json({
    success: true,
    data: []
  });
});

// Account endpoints
app.get('/api/v1/accounts', (req, res) => {
  res.json({
    success: true,
    data: {
      accounts: [],
      total: 0,
      page: 1,
      per_page: 20
    }
  });
});

app.get('/api/v1/accounts/summary', (req, res) => {
  res.json({
    success: true,
    data: {
      total_assets: 0,
      total_liabilities: 0,
      net_worth: 0,
      accounts_by_type: []
    }
  });
});

// Categories endpoints
app.get('/api/v1/categories', (req, res) => {
  res.json({
    success: true,
    data: {
      categories: [
        { id: "1", name: "餐饮", type: "expense", icon: "restaurant", color: "#FF5722" },
        { id: "2", name: "交通", type: "expense", icon: "directions_car", color: "#2196F3" },
        { id: "3", name: "购物", type: "expense", icon: "shopping_cart", color: "#9C27B0" },
        { id: "4", name: "工资", type: "income", icon: "attach_money", color: "#4CAF50" }
      ]
    }
  });
});

// Statistics endpoints
app.get('/api/v1/statistics/overview', (req, res) => {
  res.json({
    success: true,
    data: {
      total_income: 0,
      total_expense: 0,
      balance: 0,
      monthly_average_income: 0,
      monthly_average_expense: 0
    }
  });
});

app.get('/api/v1/statistics/trend', (req, res) => {
  res.json({
    success: true,
    data: {
      trend: []
    }
  });
});

// Family endpoints
app.get('/api/v1/families/current', (req, res) => {
  res.json({
    success: true,
    data: null
  });
});

// Default response
app.get('/', (req, res) => {
  res.json({
    name: "Jive Money API (Mock)",
    version: "1.0.0",
    status: "running"
  });
});

// Catch all other routes
app.all('*', (req, res) => {
  console.log(`Unhandled route: ${req.method} ${req.path}`);
  res.status(404).json({
    success: false,
    error: {
      code: "NOT_FOUND",
      message: `Route ${req.method} ${req.path} not found`
    }
  });
});

const PORT = 8012;
app.listen(PORT, () => {
  console.log(`Mock API server running on http://localhost:${PORT}`);
});