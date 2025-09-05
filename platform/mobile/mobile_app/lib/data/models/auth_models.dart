/// Authentication related data models
library;

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;
  final int? expiresAt;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.expiresAt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      user: json['user'],
      expiresAt: json['expires_at'],
    );
  }
}

class EmailSignUpRequest {
  final String email;
  final String password;
  final String? displayName;

  EmailSignUpRequest({
    required this.email,
    required this.password,
    this.displayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      if (displayName != null) 'display_name': displayName,
    };
  }
}

class EmailSignInRequest {
  final String email;
  final String password;

  EmailSignInRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
    };
  }
}