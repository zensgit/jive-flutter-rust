class Bank {
  final String id;
  final String code;
  final String name;
  final String? nameCn;
  final String? nameEn;
  final String? iconFilename;
  final bool isCrypto;

  Bank({
    required this.id,
    required this.code,
    required this.name,
    this.nameCn,
    this.nameEn,
    this.iconFilename,
    this.isCrypto = false,
  });

  String get displayName => nameCn ?? name;

  String? get iconUrl => iconFilename != null
      ? '/static/bank_icons/$iconFilename'
      : null;

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String?,
      nameEn: json['name_en'] as String?,
      iconFilename: json['icon_filename'] as String?,
      isCrypto: json['is_crypto'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'name_cn': nameCn,
      'name_en': nameEn,
      'icon_filename': iconFilename,
      'is_crypto': isCrypto,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bank &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Bank($displayName, $code)';
}