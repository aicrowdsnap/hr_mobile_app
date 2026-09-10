import 'dart:convert';
import 'api_client.dart';

class AuthService {
  AuthService();
  final ApiClient _api = ApiClient();

  Future<bool> login({
    required String identifier,
    required String organizationSlug,
    required String password,
  }) async {
    final resolvedData = await _api.postTrpc(
      'employee.resolveLoginCredentials',
      {
        'identifier': identifier.trim(),
        'organizationSlug':
            organizationSlug.trim().toLowerCase(),
      },
    );

    final resolvedEmail =
        resolvedData?['resolvedEmail']?.toString();

    final organizationId =
        resolvedData?['organizationId']?.toString();

    final requiresPasswordChange =
        resolvedData?['requiresPasswordChange'] == true;

    if (resolvedEmail == null ||
        resolvedEmail.isEmpty ||
        organizationId == null ||
        organizationId.isEmpty) {
      throw ApiException(
        'Invalid employee credentials or organization.',
      );
    }

    final response = await _api.postRest(
      '/api/auth/sign-in/email',
      {
        'email': resolvedEmail,
        'password': password,
        'rememberMe': true,
      },
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      String message = 'Invalid credentials';

      try {
        final error = jsonDecode(response.body);

        if (error is Map &&
            error['message'] != null) {
          message = error['message'].toString();
        }
      } catch (_) {}

      throw ApiException(message);
    }

    final token =
        response.headers['set-auth-token'];

    if (token == null ||
        token.trim().isEmpty) {
      throw ApiException(
        'Authentication token was not returned.',
      );
    }

    final cleanToken = token.trim();

    await _api.saveToken(cleanToken);

    final orgResponse = await _api.postRest(
      '/api/auth/organization/set-active',
      {
        'organizationId': organizationId,
      },
    );

    if (orgResponse.statusCode < 200 ||
        orgResponse.statusCode >= 300) {
      await _api.clearSession();

      throw ApiException(
        'Unable to activate the selected organization.',
      );
    }

    await _api.setActiveOrgId(organizationId);

    return requiresPasswordChange;
  }

  Future<void> forcePasswordChange({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.postTrpc(
      'employee.rotateInitialPassword',
      {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> logout() async {
    try {
      await _api.postRest('/api/auth/sign-out', {});
    } finally {
      await _api.clearSession();
    }
  }

  Future<bool> isLoggedIn() async {
    return _api.hasSession();
  }
}