import 'package:json_annotation/json_annotation.dart';

// Force rebuild

part 'category.g.dart';

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class Category {
  final String boxArtUrl;
  final String id;
  final String name;

  const Category(this.boxArtUrl, this.id, this.name);

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class Categories {
  final List<Category> data;
  final Map<String, String>? pagination;

  const Categories(this.data, this.pagination);

  factory Categories.fromJson(Map<String, dynamic> json) =>
      _$CategoriesFromJson(json);
}
