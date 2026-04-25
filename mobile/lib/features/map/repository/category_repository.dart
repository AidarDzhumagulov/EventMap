import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/category_model.dart';

class CategoryRepository {
  final Dio _dio;

  const CategoryRepository(this._dio);

  Future<List<CategoryTypeModel>> getCategories() async {
    final response = await _dio.get('/categories');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => CategoryTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.read(dioClientProvider));
});

final categoriesProvider =
    FutureProvider<List<CategoryTypeModel>>((ref) async {
  return ref.read(categoryRepositoryProvider).getCategories();
});
