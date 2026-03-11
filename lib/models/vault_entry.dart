import 'package:hive/hive.dart';

class VaultEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String category; // 'password', 'card', 'note', 'identity'

  @HiveField(3)
  Map<String, String> fields; // encrypted key-value pairs

  @HiveField(4)
  String? iconName;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime updatedAt;

  @HiveField(7)
  bool isFavorite;

  @HiveField(8)
  List<String> tags;

  VaultEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.fields,
    this.iconName,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'fields': fields,
        'iconName': iconName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isFavorite': isFavorite,
        'tags': tags,
      };

  factory VaultEntry.fromJson(Map<String, dynamic> json) => VaultEntry(
        id: json['id'],
        title: json['title'],
        category: json['category'],
        fields: Map<String, String>.from(json['fields']),
        iconName: json['iconName'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
        isFavorite: json['isFavorite'] ?? false,
        tags: List<String>.from(json['tags'] ?? []),
      );
}
