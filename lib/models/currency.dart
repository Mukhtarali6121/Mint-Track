class Currency {
  final String? name;
  final String? code;
  final String? country;
  final String? flag;

  Currency({this.name, this.code, this.country, this.flag});

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      name: json['name'] as String?,
      code: json['code'] as String?,
      country: json['country'] as String?,
      flag: json['flag'] as String?,
    );
  }
}
