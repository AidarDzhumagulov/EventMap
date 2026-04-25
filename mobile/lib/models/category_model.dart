class CategoryModel {
  final int id;
  final String alias;
  final String nameRu;
  final int categoryTypeId;

  const CategoryModel({
    required this.id,
    required this.alias,
    required this.nameRu,
    required this.categoryTypeId,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      alias: json['alias'] as String,
      nameRu: json['name_ru'] as String,
      categoryTypeId: json['category_type_id'] as int,
    );
  }
}

class CategoryTypeModel {
  final int id;
  final String alias;
  final String nameRu;
  final List<CategoryModel> categories;

  const CategoryTypeModel({
    required this.id,
    required this.alias,
    required this.nameRu,
    required this.categories,
  });

  factory CategoryTypeModel.fromJson(Map<String, dynamic> json) {
    final cats = (json['categories'] as List<dynamic>? ?? [])
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return CategoryTypeModel(
      id: json['id'] as int,
      alias: json['alias'] as String,
      nameRu: json['name_ru'] as String,
      categories: cats,
    );
  }
}
