use std::{net::{IpAddr, Ipv4Addr, Ipv6Addr, SocketAddr}, str::FromStr};
use axum::{http::{Request, StatusCode}, response::Response, middleware::Next, body::Body};
use tokio::net::lookup_host;

#[derive(Clone, Debug)]
pub struct Cidr { network: IpAddr, mask: u32 }

impl Cidr {
    pub fn parse(s: &str) -> Option<Self> {
        if s.is_empty() { return None; }
        let mut parts = s.split('/');
        let ip = parts.next()?;
        let mask: u32 = parts.next().unwrap_or("32").parse().ok()?;
        let ipaddr = IpAddr::from_str(ip).ok()?;
        Some(Self { network: ipaddr, mask })
    }
    pub fn contains(&self, ip: &IpAddr) -> bool {
        match (self.network, ip) {
            (IpAddr::V4(n), IpAddr::V4(t)) => {
                if self.mask > 32 { return false; }
                let nm = u32::from(n);
                let tm = u32::from(*t);
                let m = if self.mask == 0 { 0 } else { u32::MAX.checked_shl(32 - self.mask).unwrap_or(0) };
                (nm & m) == (tm & m)
            }
            (IpAddr::V6(n), IpAddr::V6(t)) => {
                if self.mask > 128 { return false; }
                let nb = u128::from(n);
                let tb = u128::from(*t);
                let m = if self.mask == 0 { 0 } else { u128::MAX.checked_shl(128 - self.mask).unwrap_or(0) };
                (nb & m) == (tb & m)
            }
            _ => false,
        }
    }
}

#[derive(Clone)]
pub struct MetricsGuardState { pub allow: Vec<Cidr>, pub deny: Vec<Cidr>, pub enabled: bool }

pub async fn metrics_guard(
    axum::extract::ConnectInfo(addr): axum::extract::ConnectInfo<SocketAddr>,
    axum::extract::State(state): axum::extract::State<MetricsGuardState>,
    req: Request<Body>,
    next: Next,
) -> Result<Response, StatusCode> {
    if !state.enabled { return Ok(next.run(req).await); }
    // Prefer X-Forwarded-For first hop if present (left-most)
    let mut ip = addr.ip();
    if let Some(xff) = req.headers().get("x-forwarded-for").and_then(|v| v.to_str().ok()) {
        if let Some(first) = xff.split(',').next() { if let Ok(parsed) = first.trim().parse() { ip = parsed; } }
    }
    // Deny precedence
    for d in &state.deny { if d.contains(&ip) { return Err(StatusCode::FORBIDDEN); } }
    for a in &state.allow { if a.contains(&ip) { return Ok(next.run(req).await); } }
    Err(StatusCode::FORBIDDEN)
}
