/// 全球加密货币市场统计数据
class GlobalMarketStats {
  /// 总市值 (USD)
  final String totalMarketCapUsd;

  /// 24小时总交易量 (USD)
  final String totalVolume24hUsd;

  /// BTC市值占比 (百分比)
  final String btcDominancePercentage;

  /// ETH市值占比 (百分比，可选)
  final String? ethDominancePercentage;

  /// 活跃加密货币数量
  final int activeCryptocurrencies;

  /// 活跃交易市场数量（可选）
  final int? markets;

  /// 数据最后更新时间戳 (Unix timestamp)
  final int updatedAt;

  GlobalMarketStats({
    required this.totalMarketCapUsd,
    required this.totalVolume24hUsd,
    required this.btcDominancePercentage,
    this.ethDominancePercentage,
    required this.activeCryptocurrencies,
    this.markets,
    required this.updatedAt,
  });

  factory GlobalMarketStats.fromJson(Map<String, dynamic> json) {
    return GlobalMarketStats(
      totalMarketCapUsd: json['total_market_cap_usd']?.toString() ?? '0',
      totalVolume24hUsd: json['total_volume_24h_usd']?.toString() ?? '0',
      btcDominancePercentage: json['btc_dominance_percentage']?.toString() ?? '0',
      ethDominancePercentage: json['eth_dominance_percentage']?.toString(),
      activeCryptocurrencies: json['active_cryptocurrencies'] ?? 0,
      markets: json['markets'],
      updatedAt: json['updated_at'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_market_cap_usd': totalMarketCapUsd,
      'total_volume_24h_usd': totalVolume24hUsd,
      'btc_dominance_percentage': btcDominancePercentage,
      'eth_dominance_percentage': ethDominancePercentage,
      'active_cryptocurrencies': activeCryptocurrencies,
      'markets': markets,
      'updated_at': updatedAt,
    };
  }

  /// 格式化总市值（简洁显示）
  String get formattedMarketCap {
    final value = double.tryParse(totalMarketCapUsd) ?? 0;
    if (value >= 1000000000000) {
      // >= 1T
      return '\$${(value / 1000000000000).toStringAsFixed(2)}T';
    } else if (value >= 1000000000) {
      // >= 1B
      return '\$${(value / 1000000000).toStringAsFixed(2)}B';
    } else {
      return '\$${value.toStringAsFixed(0)}';
    }
  }

  /// 格式化24h交易量（简洁显示）
  String get formatted24hVolume {
    final value = double.tryParse(totalVolume24hUsd) ?? 0;
    if (value >= 1000000000000) {
      // >= 1T
      return '\$${(value / 1000000000000).toStringAsFixed(2)}T';
    } else if (value >= 1000000000) {
      // >= 1B
      return '\$${(value / 1000000000).toStringAsFixed(2)}B';
    } else {
      return '\$${value.toStringAsFixed(0)}';
    }
  }

  /// 格式化BTC占比
  String get formattedBtcDominance {
    final value = double.tryParse(btcDominancePercentage) ?? 0;
    return '${value.toStringAsFixed(1)}%';
  }
}
