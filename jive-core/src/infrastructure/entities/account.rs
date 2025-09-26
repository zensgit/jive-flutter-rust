use super::*;

// Account entity - polymorphic with accountable_type/id
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Account {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub accountable_type: String,
    pub accountable_id: Uuid,
    pub subtype: Option<String>,
    pub balance: Option<Decimal>,
    pub balance_currency: Option<String>,
    pub currency: String,
    pub cash_balance: Option<Decimal>,
    pub status: String,
    pub description: Option<String>,
    pub include_in_net_worth: bool,
    pub plaid_account_id: Option<Uuid>,
    pub import_id: Option<Uuid>,
    pub locked_attributes: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Entity for Account {
    type Id = Uuid;

    fn id(&self) -> Self::Id {
        self.id
    }

    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }

    fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
}

impl Account {
    pub fn new(
        family_id: Uuid,
        name: String,
        accountable_type: String,
        accountable_id: Uuid,
    ) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            family_id,
            name,
            accountable_type,
            accountable_id,
            subtype: None,
            balance: Some(Decimal::ZERO),
            balance_currency: None,
            currency: "USD".to_string(),
            cash_balance: Some(Decimal::ZERO),
            status: "active".to_string(),
            description: None,
            include_in_net_worth: true,
            plaid_account_id: None,
            import_id: None,
            locked_attributes: serde_json::json!({}),
            created_at: now,
            updated_at: now,
        }
    }

    pub fn classification(&self) -> AccountClassification {
        match self.accountable_type.as_str() {
            "CreditCard" | "Loan" | "OtherLiability" => AccountClassification::Liability,
            _ => AccountClassification::Asset,
        }
    }

    pub fn is_syncing(&self) -> bool {
        self.status == "syncing"
    }

    pub fn has_error(&self) -> bool {
        self.status == "error"
    }
}

// Depository (checking/savings) account
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Depository {
    pub id: Uuid,
    pub name: String,
    pub bank_name: Option<String>,
    pub account_number: Option<String>,
    pub routing_number: Option<String>,
    pub apy: Option<Decimal>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Accountable for Depository {
    const TYPE_NAME: &'static str = "Depository";

    async fn save(&self, tx: &mut sqlx::PgConnection) -> Result<Uuid, sqlx::Error> {
        let id = sqlx::query!(
            r#"
            INSERT INTO depositories (id, name, bank_name, account_number, routing_number, apy, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                bank_name = EXCLUDED.bank_name,
                account_number = EXCLUDED.account_number,
                routing_number = EXCLUDED.routing_number,
                apy = EXCLUDED.apy,
                updated_at = EXCLUDED.updated_at
            RETURNING id
            "#,
            self.id,
            self.name,
            self.bank_name,
            self.account_number,
            self.routing_number,
            self.apy,
            self.created_at,
            self.updated_at
        )
        .fetch_one(&mut *tx)
        .await?
        .id;

        Ok(id)
    }

    async fn load(id: Uuid, conn: &sqlx::PgPool) -> Result<Self, sqlx::Error> {
        sqlx::query_as!(Depository, "SELECT * FROM depositories WHERE id = $1", id)
            .fetch_one(conn)
            .await
    }
}

// Credit Card account
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct CreditCard {
    pub id: Uuid,
    pub name: String,
    pub issuer: Option<String>,
    pub credit_limit: Option<Decimal>,
    pub apr: Option<Decimal>,
    pub annual_fee: Option<Decimal>,
    pub minimum_payment: Option<Decimal>,
    pub bill_date: Option<i32>,
    pub payment_date: Option<i32>,
    pub is_multi_currency_card: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Accountable for CreditCard {
    const TYPE_NAME: &'static str = "CreditCard";

    async fn save(&self, tx: &mut sqlx::PgConnection) -> Result<Uuid, sqlx::Error> {
        let id = sqlx::query!(
            r#"
            INSERT INTO credit_cards (
                id, name, issuer, credit_limit, apr, annual_fee, 
                minimum_payment, bill_date, payment_date, is_multi_currency_card,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                issuer = EXCLUDED.issuer,
                credit_limit = EXCLUDED.credit_limit,
                apr = EXCLUDED.apr,
                annual_fee = EXCLUDED.annual_fee,
                minimum_payment = EXCLUDED.minimum_payment,
                bill_date = EXCLUDED.bill_date,
                payment_date = EXCLUDED.payment_date,
                is_multi_currency_card = EXCLUDED.is_multi_currency_card,
                updated_at = EXCLUDED.updated_at
            RETURNING id
            "#,
            self.id,
            self.name,
            self.issuer,
            self.credit_limit,
            self.apr,
            self.annual_fee,
            self.minimum_payment,
            self.bill_date,
            self.payment_date,
            self.is_multi_currency_card,
            self.created_at,
            self.updated_at
        )
        .fetch_one(&mut *tx)
        .await?
        .id;

        Ok(id)
    }

    async fn load(id: Uuid, conn: &sqlx::PgPool) -> Result<Self, sqlx::Error> {
        sqlx::query_as!(CreditCard, "SELECT * FROM credit_cards WHERE id = $1", id)
            .fetch_one(conn)
            .await
    }
}

// Investment account
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Investment {
    pub id: Uuid,
    pub name: String,
    pub provider: Option<String>,
    pub account_type: Option<String>, // '401k', 'IRA', 'Roth IRA', 'Brokerage', etc.
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Accountable for Investment {
    const TYPE_NAME: &'static str = "Investment";

    async fn save(&self, tx: &mut sqlx::PgConnection) -> Result<Uuid, sqlx::Error> {
        let id = sqlx::query!(
            r#"
            INSERT INTO investments (id, name, provider, account_type, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                provider = EXCLUDED.provider,
                account_type = EXCLUDED.account_type,
                updated_at = EXCLUDED.updated_at
            RETURNING id
            "#,
            self.id,
            self.name,
            self.provider,
            self.account_type,
            self.created_at,
            self.updated_at
        )
        .fetch_one(&mut *tx)
        .await?
        .id;

        Ok(id)
    }

    async fn load(id: Uuid, conn: &sqlx::PgPool) -> Result<Self, sqlx::Error> {
        sqlx::query_as!(Investment, "SELECT * FROM investments WHERE id = $1", id)
            .fetch_one(conn)
            .await
    }
}

// Property account
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Property {
    pub id: Uuid,
    pub name: String,
    pub address_line1: Option<String>,
    pub address_line2: Option<String>,
    pub city: Option<String>,
    pub state: Option<String>,
    pub postal_code: Option<String>,
    pub country: Option<String>,
    pub property_type: Option<String>,
    pub year_built: Option<i32>,
    pub square_feet: Option<i32>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Accountable for Property {
    const TYPE_NAME: &'static str = "Property";

    async fn save(&self, tx: &mut sqlx::PgConnection) -> Result<Uuid, sqlx::Error> {
        let id = sqlx::query!(
            r#"
            INSERT INTO properties (
                id, name, address_line1, address_line2, city, state, 
                postal_code, country, property_type, year_built, square_feet,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                address_line1 = EXCLUDED.address_line1,
                address_line2 = EXCLUDED.address_line2,
                city = EXCLUDED.city,
                state = EXCLUDED.state,
                postal_code = EXCLUDED.postal_code,
                country = EXCLUDED.country,
                property_type = EXCLUDED.property_type,
                year_built = EXCLUDED.year_built,
                square_feet = EXCLUDED.square_feet,
                updated_at = EXCLUDED.updated_at
            RETURNING id
            "#,
            self.id,
            self.name,
            self.address_line1,
            self.address_line2,
            self.city,
            self.state,
            self.postal_code,
            self.country,
            self.property_type,
            self.year_built,
            self.square_feet,
            self.created_at,
            self.updated_at
        )
        .fetch_one(&mut *tx)
        .await?
        .id;

        Ok(id)
    }

    async fn load(id: Uuid, conn: &sqlx::PgPool) -> Result<Self, sqlx::Error> {
        sqlx::query_as!(Property, "SELECT * FROM properties WHERE id = $1", id)
            .fetch_one(conn)
            .await
    }
}

// Loan account
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Loan {
    pub id: Uuid,
    pub name: String,
    pub loan_type: Option<String>, // 'mortgage', 'auto', 'student', 'personal'
    pub interest_rate: Option<Decimal>,
    pub term_months: Option<i32>,
    pub origination_date: Option<NaiveDate>,
    pub maturity_date: Option<NaiveDate>,
    pub original_amount: Option<Decimal>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Accountable for Loan {
    const TYPE_NAME: &'static str = "Loan";

    async fn save(&self, tx: &mut sqlx::PgConnection) -> Result<Uuid, sqlx::Error> {
        let id = sqlx::query!(
            r#"
            INSERT INTO loans (
                id, name, loan_type, interest_rate, term_months,
                origination_date, maturity_date, original_amount,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                loan_type = EXCLUDED.loan_type,
                interest_rate = EXCLUDED.interest_rate,
                term_months = EXCLUDED.term_months,
                origination_date = EXCLUDED.origination_date,
                maturity_date = EXCLUDED.maturity_date,
                original_amount = EXCLUDED.original_amount,
                updated_at = EXCLUDED.updated_at
            RETURNING id
            "#,
            self.id,
            self.name,
            self.loan_type,
            self.interest_rate,
            self.term_months,
            self.origination_date,
            self.maturity_date,
            self.original_amount,
            self.created_at,
            self.updated_at
        )
        .fetch_one(&mut *tx)
        .await?
        .id;

        Ok(id)
    }

    async fn load(id: Uuid, conn: &sqlx::PgPool) -> Result<Self, sqlx::Error> {
        sqlx::query_as!(Loan, "SELECT * FROM loans WHERE id = $1", id)
            .fetch_one(conn)
            .await
    }
}
