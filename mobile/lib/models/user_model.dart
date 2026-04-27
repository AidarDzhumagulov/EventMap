class UserModel {
  final String id;
  final String email;
  final String username;
  final String role;
  final double rating;
  final String? avatarUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.rating,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      role: json['role'] as String,
      rating: (json['rating'] as num).toDouble(),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  String get rankLabel {
    if (rating >= 100) return 'King of the Night';
    if (rating >= 50) return 'Event Master';
    if (rating >= 20) return 'Party Animal';
    if (rating >= 5) return 'Local Guide';
    return 'Новичок';
  }

  String get rankEmoji {
    if (rating >= 100) return '👑';
    if (rating >= 50) return '🌟';
    if (rating >= 20) return '🎉';
    if (rating >= 5) return '📍';
    return '🌱';
  }
}
