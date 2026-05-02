class User {
  final String email;
  final String name;
  final String? avatarUrl;
  User({required this.email, required this.name, this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }
}
