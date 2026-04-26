class Friend {
  final String id;
  final String name;
  final String role;
  final String code;
  final String? email;
  final String? avatarUrl;

  Friend({
    required this.id,
    required this.name,
    required this.role,
    required this.code,
    this.email,
    this.avatarUrl,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? 'Viewer',
      code: json['code'] ?? '',
      email: json['email'],
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'code': code,
      'email': email,
      'avatarUrl': avatarUrl,
    };
  }
}
