import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:jive_money/services/storage_service.dart';
import 'package:jive_money/services/wechat_service.dart';

/// 用户认证服务
/// 处理登录、注册、微信认证等功能
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final StorageService _storage = StorageService();
  UserData? _currentUser;
  String? _token;

  /// 获取当前用户
  UserData? get currentUser => _currentUser;

  /// 获取认证令牌
  String? get token => _token;

  /// 是否已登录
  bool get isLoggedIn => _currentUser != null;

  /// 初始化认证服务
  Future<void> initialize() async {
    try {
      final userData = await _storage.getUserData();
      final authToken = await _storage.getAuthToken();

      if (userData != null && authToken != null) {
        _currentUser = userData;
        _token = authToken;
        debugPrint('用户认证状态已恢复: ${userData.username}');
      }
    } catch (e) {
      debugPrint('初始化认证服务失败: $e');
    }
  }

  /// 保存认证令牌
  Future<void> saveToken(String token) async {
    _token = token;
    await _storage.saveAuthToken(token);
  }

  /// 保存用户ID
  Future<void> saveUserId(String userId) async {
    // 如果有当前用户，更新ID
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(id: userId);
      await _storage.saveUserData(_currentUser!);
    }
  }

  /// 用户名/邮箱密码登录
  Future<AuthResult> login(String usernameOrEmail, String password) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // 模拟网络请求

      // 验证输入
      if (usernameOrEmail.isEmpty || password.isEmpty) {
        return AuthResult(success: false, message: '用户名和密码不能为空');
      }

      // 模拟登录验证逻辑
      final loginResult = await _simulateLogin(usernameOrEmail, password);

      if (loginResult.success && loginResult.userData != null) {
        // 保存用户数据和认证令牌
        await _storage.saveUserData(loginResult.userData!);
        await _storage.saveAuthToken(_generateToken());

        // 更新最后登录时间
        _currentUser = loginResult.userData!.copyWith(
          lastLoginTime: DateTime.now(),
        );
        await _storage.saveUserData(_currentUser!);

        // 记录登录历史
        final isEmail = usernameOrEmail.contains('@');
        await _storage.addLoginHistory(LoginHistoryItem(
          loginTime: DateTime.now(),
          loginMethod: isEmail ? 'email' : 'username',
          deviceInfo: 'Web Browser',
          location: '未知位置',
          success: true,
        ));

        debugPrint('用户登录成功: ${_currentUser!.username}');
        return AuthResult(
          success: true,
          message: '登录成功',
          userData: _currentUser,
        );
      } else {
        // 记录失败登录历史
        await _storage.addLoginHistory(LoginHistoryItem(
          loginTime: DateTime.now(),
          loginMethod: usernameOrEmail.contains('@') ? 'email' : 'username',
          deviceInfo: 'Web Browser',
          location: '未知位置',
          success: false,
        ));

        return AuthResult(
          success: false,
          message: loginResult.message ?? '用户名或密码错误',
        );
      }
    } catch (e) {
      debugPrint('登录异常: $e');
      return AuthResult(success: false, message: '登录过程中发生错误');
    }
  }

  /// 用户注册
  Future<AuthResult> register(String username, String email, String password,
      {String? inviteCode}) async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // 模拟网络请求

      // 验证输入
      if (username.isEmpty || email.isEmpty || password.isEmpty) {
        return AuthResult(success: false, message: '所有字段都必须填写');
      }

      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email)) {
        return AuthResult(success: false, message: '邮箱格式不正确');
      }

      if (!RegExp(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$').hasMatch(username) ||
          username.length < 3 ||
          username.length > 20) {
        return AuthResult(success: false, message: '用户名格式不正确');
      }

      // 模拟检查用户名和邮箱是否已存在
      final existsResult = await _checkUserExists(username, email);
      if (!existsResult.success) {
        return existsResult;
      }

      // 创建新用户
      final newUser = UserData(
        id: _generateUserId(),
        username: username,
        email: email,
        registerTime: DateTime.now(),
        lastLoginTime: DateTime.now(),
        role: 'Owner', // 注册用户默认为家庭拥有者
      );

      // 保存用户数据
      await _storage.saveUserData(newUser);

      debugPrint('用户注册成功: $username');
      return AuthResult(
        success: true,
        message: '注册成功！请使用您的账户登录',
        userData: newUser,
      );
    } catch (e) {
      debugPrint('注册异常: $e');
      return AuthResult(success: false, message: '注册过程中发生错误');
    }
  }

  /// 微信登录
  Future<AuthResult> wechatLogin() async {
    try {
      // 获取微信授权
      WeChatAuthResult? authResult;
      WeChatUserInfo? userInfo;

      // 检查微信是否安装
      bool isInstalled = await WeChatService.isWeChatInstalled();
      if (isInstalled) {
        authResult = await WeChatService.login();
        if (authResult != null && authResult.accessToken != null) {
          userInfo = await WeChatService.getUserInfo(
            authResult.accessToken!,
            authResult.openId,
          );
        }
      } else {
        // 使用模拟登录
        authResult = await WeChatService.simulateLogin();
        userInfo = await WeChatService.simulateGetUserInfo();
      }

      if (authResult == null || userInfo == null) {
        return AuthResult(success: false, message: '微信授权失败');
      }

      // 检查是否已有绑定的用户账户
      final existingUser = await _findUserByWeChatOpenId(authResult.openId);

      if (existingUser != null) {
        // 已有账户，直接登录
        await _storage.saveAuthToken(_generateToken());
        _currentUser = existingUser.copyWith(lastLoginTime: DateTime.now());
        await _storage.saveUserData(_currentUser!);

        // 记录登录历史
        await _storage.addLoginHistory(LoginHistoryItem(
          loginTime: DateTime.now(),
          loginMethod: 'wechat',
          deviceInfo: 'Web Browser',
          location: '未知位置',
          success: true,
        ));

        debugPrint('微信登录成功: ${_currentUser!.username}');
        return AuthResult(
          success: true,
          message: '微信登录成功',
          userData: _currentUser,
        );
      } else {
        return AuthResult(
          success: false,
          message: '该微信账号尚未绑定用户账户，请先注册或在设置中绑定',
          wechatAuthResult: authResult,
          wechatUserInfo: userInfo,
        );
      }
    } catch (e) {
      debugPrint('微信登录异常: $e');
      return AuthResult(success: false, message: '微信登录过程中发生错误');
    }
  }

  /// 微信注册（创建新账户并绑定微信）
  Future<AuthResult> wechatRegister() async {
    try {
      // 获取微信授权
      WeChatAuthResult? authResult;
      WeChatUserInfo? userInfo;

      bool isInstalled = await WeChatService.isWeChatInstalled();
      if (isInstalled) {
        authResult = await WeChatService.login();
        if (authResult != null && authResult.accessToken != null) {
          userInfo = await WeChatService.getUserInfo(
            authResult.accessToken!,
            authResult.openId,
          );
        }
      } else {
        authResult = await WeChatService.simulateLogin();
        userInfo = await WeChatService.simulateGetUserInfo();
      }

      if (authResult == null || userInfo == null) {
        return AuthResult(success: false, message: '微信授权失败');
      }

      // 检查该微信是否已注册
      final existingUser = await _findUserByWeChatOpenId(authResult.openId);
      if (existingUser != null) {
        return AuthResult(success: false, message: '该微信账号已注册，请直接登录');
      }

      // 生成唯一的用户名和邮箱
      final username = await _generateUniqueUsername(userInfo.nickname);
      final email = '${authResult.openId}@wechat.jivemoney.com';

      // 创建新用户
      final newUser = UserData(
        id: _generateUserId(),
        username: username,
        email: email,
        avatar: userInfo.headImgUrl.isNotEmpty ? userInfo.headImgUrl : null,
        registerTime: DateTime.now(),
        lastLoginTime: DateTime.now(),
        role: 'Owner',
      );

      // 保存用户数据
      await _storage.saveUserData(newUser);

      // 保存微信绑定数据
      final wechatBinding = WeChatBindingData(
        openId: authResult.openId,
        unionId: authResult.unionId,
        nickname: userInfo.nickname,
        headImgUrl: userInfo.headImgUrl,
        sex: userInfo.sex,
        province: userInfo.province,
        city: userInfo.city,
        country: userInfo.country,
        bindTime: DateTime.now(),
      );
      await _storage.saveWeChatData(wechatBinding);

      debugPrint('微信注册成功: $username');
      return AuthResult(
        success: true,
        message: '微信注册成功！',
        userData: newUser,
      );
    } catch (e) {
      debugPrint('微信注册异常: $e');
      return AuthResult(success: false, message: '微信注册过程中发生错误');
    }
  }

  /// 绑定微信账户
  Future<AuthResult> bindWechat() async {
    if (_currentUser == null) {
      return AuthResult(success: false, message: '请先登录');
    }

    try {
      WeChatAuthResult? authResult;
      WeChatUserInfo? userInfo;

      bool isInstalled = await WeChatService.isWeChatInstalled();
      if (isInstalled) {
        authResult = await WeChatService.login();
        if (authResult != null && authResult.accessToken != null) {
          userInfo = await WeChatService.getUserInfo(
            authResult.accessToken!,
            authResult.openId,
          );
        }
      } else {
        authResult = await WeChatService.simulateLogin();
        userInfo = await WeChatService.simulateGetUserInfo();
      }

      if (authResult == null || userInfo == null) {
        return AuthResult(success: false, message: '微信授权失败');
      }

      // 检查该微信是否已被其他账户绑定
      final existingUser = await _findUserByWeChatOpenId(authResult.openId);
      if (existingUser != null && existingUser.id != _currentUser!.id) {
        return AuthResult(success: false, message: '该微信账号已被其他账户绑定');
      }

      // 保存微信绑定数据
      final wechatBinding = WeChatBindingData(
        openId: authResult.openId,
        unionId: authResult.unionId,
        nickname: userInfo.nickname,
        headImgUrl: userInfo.headImgUrl,
        sex: userInfo.sex,
        province: userInfo.province,
        city: userInfo.city,
        country: userInfo.country,
        bindTime: DateTime.now(),
      );
      await _storage.saveWeChatData(wechatBinding);

      debugPrint('微信绑定成功: ${userInfo.nickname}');
      return AuthResult(
        success: true,
        message: '微信账户绑定成功',
        wechatUserInfo: userInfo,
      );
    } catch (e) {
      debugPrint('微信绑定异常: $e');
      return AuthResult(success: false, message: '微信绑定过程中发生错误');
    }
  }

  /// 解绑微信账户
  Future<AuthResult> unbindWechat() async {
    if (_currentUser == null) {
      return AuthResult(success: false, message: '请先登录');
    }

    try {
      await _storage.removeWeChatData();
      debugPrint('微信解绑成功');
      return AuthResult(success: true, message: '微信账户解绑成功');
    } catch (e) {
      debugPrint('微信解绑异常: $e');
      return AuthResult(success: false, message: '微信解绑过程中发生错误');
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      await _storage.clearAllData();
      _currentUser = null;
      debugPrint('用户已登出');
    } catch (e) {
      debugPrint('登出异常: $e');
    }
  }

  /// 获取微信绑定信息
  Future<WeChatBindingData?> getWeChatBinding() async {
    return await _storage.getWeChatData();
  }

  /// 获取登录历史
  Future<List<LoginHistoryItem>> getLoginHistory() async {
    return await _storage.getLoginHistory();
  }

  /// 更新用户信息
  Future<AuthResult> updateUserInfo({
    String? realName,
    String? email,
    String? avatar,
  }) async {
    if (_currentUser == null) {
      return AuthResult(success: false, message: '请先登录');
    }

    try {
      // 如果更新邮箱，检查邮箱是否已被使用
      if (email != null && email != _currentUser!.email) {
        final emailExists = await _checkEmailExists(email);
        if (!emailExists.success) {
          return emailExists;
        }

        // 验证邮箱格式
        if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
            .hasMatch(email)) {
          return AuthResult(success: false, message: '邮箱格式不正确');
        }
      }

      // 验证姓名格式
      if (realName != null && realName.isNotEmpty) {
        if (realName.length > 20) {
          return AuthResult(success: false, message: '姓名不能超过20个字符');
        }
      }

      // 更新用户信息
      final updatedUser = _currentUser!.copyWith(
        realName: realName,
        email: email,
        avatar: avatar,
      );

      await _storage.saveUserData(updatedUser);
      _currentUser = updatedUser;

      debugPrint('用户信息更新成功: ${updatedUser.username}');
      return AuthResult(
        success: true,
        message: '用户信息更新成功',
        userData: updatedUser,
      );
    } catch (e) {
      debugPrint('更新用户信息异常: $e');
      return AuthResult(success: false, message: '更新过程中发生错误');
    }
  }

  // 私有方法

  /// 模拟登录验证
  Future<AuthResult> _simulateLogin(
      String usernameOrEmail, String password) async {
    // 模拟一些预设的测试账户
    final testAccounts = {
      'demo': {
        'password': '123456',
        'email': 'demo@jivemoney.com',
        'username': 'demo'
      },
      'demo@jivemoney.com': {
        'password': '123456',
        'email': 'demo@jivemoney.com',
        'username': 'demo'
      },
      'test': {
        'password': 'Test123!',
        'email': 'test@example.com',
        'username': 'test'
      },
      'test@example.com': {
        'password': 'Test123!',
        'email': 'test@example.com',
        'username': 'test'
      },
      // 添加超级管理员账户（测试阶段）
      'superadmin': {
        'password': 'admin123',
        'email': 'superadmin@jivemoney.com',
        'username': 'superadmin'
      },
      'superadmin@jivemoney.com': {
        'password': 'admin123',
        'email': 'superadmin@jivemoney.com',
        'username': 'superadmin'
      },
    };

    if (testAccounts.containsKey(usernameOrEmail)) {
      final account = testAccounts[usernameOrEmail]!;
      if (account['password'] == password) {
        final userData = UserData(
          id: _generateUserId(),
          username: account['username']!,
          email: account['email']!,
          registerTime: DateTime.now().subtract(const Duration(days: 30)),
          lastLoginTime: DateTime.now(),
          role: account['username'] == 'superadmin' ? 'Owner' : 'Member',
        );
        return AuthResult(success: true, userData: userData);
      }
    }

    return AuthResult(success: false, message: '用户名或密码错误');
  }

  /// 检查用户是否存在
  Future<AuthResult> _checkUserExists(String username, String email) async {
    // 模拟检查用户名和邮箱唯一性
    final testUsernames = ['admin', 'root', 'demo', 'test'];
    final testEmails = ['demo@jivemoney.com', 'test@example.com'];

    if (testUsernames.contains(username.toLowerCase())) {
      return AuthResult(success: false, message: '该用户名已被使用');
    }

    if (testEmails.contains(email.toLowerCase())) {
      return AuthResult(success: false, message: '该邮箱已被注册');
    }

    return AuthResult(success: true);
  }

  /// 检查邮箱是否存在（用于更新邮箱时验证）
  Future<AuthResult> _checkEmailExists(String email) async {
    // 模拟检查邮箱唯一性
    final testEmails = ['demo@jivemoney.com', 'test@example.com'];

    if (testEmails.contains(email.toLowerCase())) {
      return AuthResult(success: false, message: '该邮箱已被其他用户使用');
    }

    return AuthResult(success: true);
  }

  /// 根据微信OpenID查找用户
  Future<UserData?> _findUserByWeChatOpenId(String openId) async {
    // 模拟查询逻辑，实际应该查询数据库
    // 这里为了演示，我们假设某些openId已绑定用户
    final bindingData = await _storage.getWeChatData();
    if (bindingData?.openId == openId) {
      return await _storage.getUserData();
    }
    return null;
  }

  /// 生成唯一用户名
  Future<String> _generateUniqueUsername(String nickname) async {
    String baseUsername =
        nickname.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5]'), '');
    if (baseUsername.isEmpty) {
      baseUsername = 'user';
    }

    // 添加随机数字确保唯一性
    final random = Random();
    return '${baseUsername}_${random.nextInt(9999).toString().padLeft(4, '0')}';
  }

  /// 生成用户ID
  String _generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
  }

  /// 生成认证令牌
  String _generateToken() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'jwt_token_${now}_$random';
  }
}

/// 认证结果
class AuthResult {
  final bool success;
  final String? message;
  final UserData? userData;
  final WeChatAuthResult? wechatAuthResult;
  final WeChatUserInfo? wechatUserInfo;

  AuthResult({
    required this.success,
    this.message,
    this.userData,
    this.wechatAuthResult,
    this.wechatUserInfo,
  });
}
