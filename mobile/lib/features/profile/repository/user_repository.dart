import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/user_model.dart';

export '../../../models/user_model.dart';

class UserRepository {
  final Dio _dio;

  const UserRepository(this._dio);

  Future<UserModel> getMe() async {
    final response = await _dio.get('/me');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserModel> updateMe({required String username, String? avatarUrl}) async {
    final response = await _dio.patch('/me/update', data: {
      'username': username,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    });
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      '/upload',
      queryParameters: {'type': 'avatar'},
      data: formData,
    );
    return (response.data as Map<String, dynamic>)['url'] as String;
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(dioClientProvider));
});

final meProvider = FutureProvider<UserModel>((ref) async {
  return ref.read(userRepositoryProvider).getMe();
});
