import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:jive_money/utils/constants.dart';
import 'package:jive_money/services/auth_service.dart';

/// Social login provider types
enum SocialProvider {
  wechat,
  qq,
  tiktok,
}

/// Social account binding result
class SocialAuthResult {
  final String provider;
  final String socialId;
  final String? nickname;
  final String? avatarUrl;
  final String? email;
  final Map<String, dynamic>? additionalData;

  SocialAuthResult({
    required this.provider,
    required this.socialId,
    this.nickname,
    this.avatarUrl,
    this.email,
    this.additionalData,
  });

  factory SocialAuthResult.fromJson(Map<String, dynamic> json) {
    return SocialAuthResult(
      provider: json['provider'],
      socialId: json['social_id'],
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      email: json['email'],
      additionalData: json['additional_data'],
    );
  }
}

/// Service for handling social authentication
class SocialAuthService {
  final String baseUrl = ApiConstants.baseUrl;
  final AuthService _authService = AuthService();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authService.token != null)
          'Authorization': 'Bearer ${_authService.token}',
      };

  // ========== WeChat Integration ==========

  /// Bind WeChat account to current user
  Future<SocialAuthResult?> bindWeChat() async {
    try {
      // TODO: Implement WeChat SDK integration
      // This is a placeholder implementation

      // Step 1: Get WeChat authorization code
      final authCode = await _getWeChatAuthCode();
      if (authCode == null) return null;

      // Step 2: Exchange code for access token on server
      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/wechat/bind'),
        headers: _headers,
        body: json.encode({'auth_code': authCode}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SocialAuthResult.fromJson(data['data']);
      }

      throw Exception('Failed to bind WeChat: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error binding WeChat: $e');
      return null;
    }
  }

  /// Login with WeChat
  Future<Map<String, dynamic>?> loginWithWeChat() async {
    try {
      // Step 1: Get WeChat authorization code
      final authCode = await _getWeChatAuthCode();
      if (authCode == null) return null;

      // Step 2: Login with auth code
      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/wechat/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'auth_code': authCode}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Save token
        if (data['token'] != null) {
          await _authService.saveToken(data['token']);
        }

        return data;
      }

      throw Exception('Failed to login with WeChat: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error logging in with WeChat: $e');
      return null;
    }
  }

  /// Register with WeChat
  Future<Map<String, dynamic>?> registerWithWeChat() async {
    try {
      // Step 1: Get WeChat authorization code and user info
      final authCode = await _getWeChatAuthCode();
      if (authCode == null) return null;

      // Step 2: Register with auth code
      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/wechat/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'auth_code': authCode,
          // Additional registration data can be added here
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Save token
        if (data['token'] != null) {
          await _authService.saveToken(data['token']);
        }

        return data;
      }

      throw Exception('Failed to register with WeChat: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error registering with WeChat: $e');
      return null;
    }
  }

  /// Unbind WeChat account
  Future<bool> unbindWeChat() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/social/wechat/unbind'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error unbinding WeChat: $e');
      return false;
    }
  }

  // ========== QQ Integration ==========

  /// Bind QQ account to current user
  Future<SocialAuthResult?> bindQQ() async {
    try {
      // TODO: Implement QQ SDK integration
      // This is a placeholder implementation

      // Step 1: Get QQ authorization
      final authData = await _getQQAuthData();
      if (authData == null) return null;

      // Step 2: Bind on server
      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/qq/bind'),
        headers: _headers,
        body: json.encode(authData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SocialAuthResult.fromJson(data['data']);
      }

      throw Exception('Failed to bind QQ: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error binding QQ: $e');
      return null;
    }
  }

  /// Login with QQ
  Future<Map<String, dynamic>?> loginWithQQ() async {
    try {
      final authData = await _getQQAuthData();
      if (authData == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/qq/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(authData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Save token
        if (data['token'] != null) {
          await _authService.saveToken(data['token']);
        }

        return data;
      }

      throw Exception('Failed to login with QQ: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error logging in with QQ: $e');
      return null;
    }
  }

  /// Register with QQ
  Future<Map<String, dynamic>?> registerWithQQ() async {
    try {
      final authData = await _getQQAuthData();
      if (authData == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/qq/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(authData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Save token
        if (data['token'] != null) {
          await _authService.saveToken(data['token']);
        }

        return data;
      }

      throw Exception('Failed to register with QQ: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error registering with QQ: $e');
      return null;
    }
  }

  /// Unbind QQ account
  Future<bool> unbindQQ() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/social/qq/unbind'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error unbinding QQ: $e');
      return false;
    }
  }

  // ========== TikTok/抖音 Integration ==========

  /// Bind TikTok account to current user
  Future<SocialAuthResult?> bindTikTok() async {
    try {
      // TODO: Implement TikTok/抖音 SDK integration
      // This is a placeholder implementation

      // Step 1: Get TikTok authorization
      final authData = await _getTikTokAuthData();
      if (authData == null) return null;

      // Step 2: Bind on server
      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/tiktok/bind'),
        headers: _headers,
        body: json.encode(authData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SocialAuthResult.fromJson(data['data']);
      }

      throw Exception('Failed to bind TikTok: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error binding TikTok: $e');
      return null;
    }
  }

  /// Login with TikTok
  Future<Map<String, dynamic>?> loginWithTikTok() async {
    try {
      final authData = await _getTikTokAuthData();
      if (authData == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/tiktok/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(authData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Save token
        if (data['token'] != null) {
          await _authService.saveToken(data['token']);
        }

        return data;
      }

      throw Exception('Failed to login with TikTok: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error logging in with TikTok: $e');
      return null;
    }
  }

  /// Register with TikTok
  Future<Map<String, dynamic>?> registerWithTikTok() async {
    try {
      final authData = await _getTikTokAuthData();
      if (authData == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/social/tiktok/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(authData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        // Save token
        if (data['token'] != null) {
          await _authService.saveToken(data['token']);
        }

        return data;
      }

      throw Exception('Failed to register with TikTok: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error registering with TikTok: $e');
      return null;
    }
  }

  /// Unbind TikTok account
  Future<bool> unbindTikTok() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/social/tiktok/unbind'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error unbinding TikTok: $e');
      return false;
    }
  }

  // ========== Private Helper Methods ==========

  /// Get WeChat authorization code
  /// NOTE: This requires WeChat SDK integration
  Future<String?> _getWeChatAuthCode() async {
    // TODO: Implement WeChat SDK
    // For now, return mock data for development
    debugPrint('WeChat SDK not implemented. Using mock data.');

    // In production, this would:
    // 1. Call WeChat SDK to open WeChat app
    // 2. User authorizes in WeChat
    // 3. WeChat returns auth code

    return 'mock_wechat_auth_code';
  }

  /// Get QQ authorization data
  /// NOTE: This requires QQ SDK integration
  Future<Map<String, dynamic>?> _getQQAuthData() async {
    // TODO: Implement QQ SDK
    // For now, return mock data for development
    debugPrint('QQ SDK not implemented. Using mock data.');

    // In production, this would:
    // 1. Call QQ SDK to open QQ app or web view
    // 2. User authorizes in QQ
    // 3. QQ returns access token and openid

    return {
      'access_token': 'mock_qq_access_token',
      'openid': 'mock_qq_openid',
    };
  }

  /// Get TikTok authorization data
  /// NOTE: This requires TikTok SDK integration
  Future<Map<String, dynamic>?> _getTikTokAuthData() async {
    // TODO: Implement TikTok/抖音 SDK
    // For now, return mock data for development
    debugPrint('TikTok SDK not implemented. Using mock data.');

    // In production, this would:
    // 1. Call TikTok SDK to open TikTok app
    // 2. User authorizes in TikTok
    // 3. TikTok returns auth data

    return {
      'auth_code': 'mock_tiktok_auth_code',
      'state': 'mock_state',
    };
  }
}

/// Social login button widget
class SocialLoginButton extends StatelessWidget {
  final SocialProvider provider;
  final VoidCallback onPressed;
  final bool isLoading;

  const SocialLoginButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getProviderConfig(provider);

    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(config['icon'], color: config['iconColor']),
      label: Text(config['label']),
      style: ElevatedButton.styleFrom(
        backgroundColor: config['backgroundColor'],
        foregroundColor: config['textColor'],
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Map<String, dynamic> _getProviderConfig(SocialProvider provider) {
    switch (provider) {
      case SocialProvider.wechat:
        return {
          'icon': Icons.chat,
          'iconColor': Colors.white,
          'label': '微信登录',
          'backgroundColor': const Color(0xFF07C160),
          'textColor': Colors.white,
        };
      case SocialProvider.qq:
        return {
          'icon': Icons.message,
          'iconColor': Colors.white,
          'label': 'QQ登录',
          'backgroundColor': const Color(0xFF12B7F5),
          'textColor': Colors.white,
        };
      case SocialProvider.tiktok:
        return {
          'icon': Icons.music_video,
          'iconColor': Colors.white,
          'label': '抖音登录',
          'backgroundColor': Colors.black,
          'textColor': Colors.white,
        };
    }
  }
}
