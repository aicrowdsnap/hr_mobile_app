import 'dart:convert';

import 'api_client.dart';

class AuthService {
  AuthService();

  final ApiClient _api =
      ApiClient();

  Future<void> login({
    required String identifier,
    required String organizationSlug,
    required String password,
  }) async {
    
    final resolvedData =
        await _api.postTrpc(
      'employee.resolveLoginCredentials',
      {
        'identifier': identifier,
        'organizationSlug':
            organizationSlug,
      },
    );

    final resolvedEmail =
        resolvedData?['resolvedEmail'];

    if (resolvedEmail == null ||
        resolvedEmail
            .toString()
            .isEmpty) {
      throw Exception(
        'Invalid employee credentials '
        'or company slug.',
      );
    }

   
    final response =
        await _api.postRest(
      '/api/auth/sign-in/email',
      {
        'email': resolvedEmail,
        'password': password,
        'rememberMe': true,
      },
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String message =
          'Sign in failed';

      try {
        final error =
            jsonDecode(response.body);

        if (error is Map &&
            error['message'] != null) {
          message =
              error['message']
                  .toString();
        }
      } catch (_) {
        // Ignore JSON parsing error
      }

      throw Exception(message);
    }

    
    final token =
        response.headers[
          'set-auth-token'
        ];

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'Login succeeded, but the '
        'authentication token was not returned.',
      );
    }
    await _api.saveToken(
      token.trim(),
    );
  }

  Future<void> logout() async {
    try {
      await _api.postRest(
        '/api/auth/sign-out',
        {},
      );
    } finally {
      await _api.clearSession();
    }
  }

  Future<bool> isLoggedIn() async {
    return _api.hasSession();
  }
}