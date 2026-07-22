class Bike {
  const Bike({
    required this.id,
    required this.brand,
    required this.model,
    this.year,
    this.nickname,
    this.engineCc,
  });

  final int id;
  final String brand;
  final String model;
  final int? year;
  final String? nickname;
  final int? engineCc;

  String get displayName => nickname?.isNotEmpty == true ? nickname! : '$brand $model';

  factory Bike.fromJson(Map<String, dynamic> json) {
    return Bike(
      id: json['id'] as int,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'] as int?,
      nickname: json['nickname'] as String?,
      engineCc: json['engine_cc'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'brand': brand,
        'model': model,
        if (year != null) 'year': year,
        if (nickname != null) 'nickname': nickname,
        if (engineCc != null) 'engine_cc': engineCc,
      };
}
