import 'package:uuid/uuid.dart';

class SavedAddress {
  final String id;
  final String city;
  final String street;
  final String house;
  final String? group; // e.g. GPV5.1 — primary group
  final List<String> groups; // all groups if multi
  final bool isPinned;
  final DateTime addedAt;

  SavedAddress({
    String? id,
    required this.city,
    required this.street,
    required this.house,
    this.group,
    this.groups = const [],
    this.isPinned = false,
    DateTime? addedAt,
  })  : id = id ?? const Uuid().v4(),
        addedAt = addedAt ?? DateTime.now();

  String get displayName => '$city, $street, $house';

  String get shortName => '$street, $house';

  SavedAddress copyWith({
    String? city,
    String? street,
    String? house,
    String? group,
    List<String>? groups,
    bool? isPinned,
  }) {
    return SavedAddress(
      id: id,
      city: city ?? this.city,
      street: street ?? this.street,
      house: house ?? this.house,
      group: group ?? this.group,
      groups: groups ?? this.groups,
      isPinned: isPinned ?? this.isPinned,
      addedAt: addedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'city': city,
        'street': street,
        'house': house,
        'group': group,
        'groups': groups,
        'isPinned': isPinned,
        'addedAt': addedAt.toIso8601String(),
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as String?,
      city: json['city'] as String,
      street: json['street'] as String,
      house: json['house'] as String,
      group: json['group'] as String?,
      groups: (json['groups'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isPinned: json['isPinned'] as bool? ?? false,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : null,
    );
  }
}
