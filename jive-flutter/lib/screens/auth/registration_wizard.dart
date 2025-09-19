import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/currency_provider.dart';
import '../../core/storage/token_storage.dart';

class RegistrationWizard extends ConsumerStatefulWidget {
  const RegistrationWizard({super.key});

  @override
  ConsumerState<RegistrationWizard> createState() => _RegistrationWizardState();
}

class _RegistrationWizardState extends ConsumerState<RegistrationWizard> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  int _currentPage = 0;
  bool _isLoading = false;

  // Step 1: Account Info
  final _formKey1 = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;

  // Password strength
  bool _hasMinLength = false;
  bool _hasUpperLower = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  // Step 2: Profile Setup
  final _formKey2 = GlobalKey<FormState>();
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Step 3: Preferences
  final _formKey3 = GlobalKey<FormState>();
  String _selectedCountry = 'CN';
  String _selectedCurrency = 'CNY';
  String _selectedLanguage = 'zh-CN';
  String _selectedTimezone = 'Asia/Shanghai';
  String _selectedDateFormat = 'YYYY-MM-DD';

  // Locale data
  Map<String, dynamic>? _localeData;

  @override
  void initState() {
    super.initState();
    _loadLocaleData();
  }

  Future<void> _loadLocaleData() async {
    try {
      final response = await _apiService.get('/locales');
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _localeData = response['data'];
        });
      }
    } catch (e) {
      debugPrint('Failed to load locale data: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUpperLower = password.contains(RegExp(r'[A-Z]')) &&
          password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'\d'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Call enhanced registration API
      final response = await _apiService.post('/auth/register-enhanced', {
        'name': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'country': _selectedCountry,
        'currency': _selectedCurrency,
        'language': _selectedLanguage,
        'timezone': _selectedTimezone,
        'date_format': _selectedDateFormat,
      });

      if (response['success'] == true) {
        // Save token and user info
        final token = response['data']['token'];
        final userId = response['data']['user_id'];

        await _authService.saveToken(token);
        await _authService.saveUserId(userId);
        // Also persist token to global TokenStorage for API Authorization headers
        try {
          await TokenStorage.saveAccessToken(token);
          final jwtExp = TokenStorage.decodeJwtExpiry(token);
          if (jwtExp != null) {
            await TokenStorage.saveTokenExpiry(jwtExp);
          }
          // Persist user id for completeness
          await TokenStorage.saveUserId(userId.toString());
        } catch (e) {
          debugPrint('Failed to persist token to TokenStorage: $e');
        }

        // Sync selected currency to global base currency preferences
        // This keeps Settings > 多币种设置 > 基础货币 in sync with registration selection
        try {
          await ref
              .read(currencyProvider.notifier)
              .setBaseCurrency(_selectedCurrency);
        } catch (e) {
          // Non-fatal: continue navigation even if currency save fails
          debugPrint('Failed to set base currency: $e');
        }

        // Upload profile image if selected
        if (_profileImage != null) {
          // TODO: Implement profile image upload
        }

        if (mounted) {
          // Navigate to main app
          Navigator.of(context).pushReplacementNamed('/main');
        }
      } else {
        throw Exception(response['error'] ?? 'Registration failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('注册失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _nextPage() {
    if (_currentPage == 0 && !_formKey1.currentState!.validate()) return;
    if (_currentPage == 0 && !_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先同意用户协议和隐私政策'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _register();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i <= _currentPage
                              ? Colors.blue
                              : Colors.grey[700],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),

            // Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildAccountInfoStep(),
                  _buildProfileSetupStep(),
                  _buildPreferencesStep(),
                ],
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: Text(
                          '上一步',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _currentPage < 2 ? '下一步' : '完成注册',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '创建您的账户',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '让我们开始设置您的 Jive Money 账户',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),

            // Username
            TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '用户名',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.person, color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名';
                }
                if (value.length < 3) {
                  return '用户名至少3个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: '邮箱地址',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.email, color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入邮箱地址';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return '请输入有效的邮箱地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordController,
              style: const TextStyle(color: Colors.white),
              obscureText: !_isPasswordVisible,
              onChanged: _checkPasswordStrength,
              decoration: InputDecoration(
                labelText: '密码',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.lock, color: Colors.grey[400]),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey[400],
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                if (!_hasMinLength ||
                    !_hasUpperLower ||
                    !_hasNumber ||
                    !_hasSpecialChar) {
                  return '密码不符合安全要求';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Password strength indicator
            _buildPasswordStrengthIndicator(),
            const SizedBox(height: 16),

            // Confirm Password
            TextFormField(
              controller: _confirmPasswordController,
              style: const TextStyle(color: Colors.white),
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: '确认密码',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey[400],
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请确认密码';
                }
                if (value != _passwordController.text) {
                  return '两次输入的密码不一致';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Terms checkbox
            Row(
              children: [
                Checkbox(
                  value: _agreeToTerms,
                  onChanged: (value) {
                    setState(() {
                      _agreeToTerms = value ?? false;
                    });
                  },
                  fillColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) {
                      return Colors.blue;
                    }
                    return Colors.grey[700];
                  }),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _agreeToTerms = !_agreeToTerms;
                      });
                    },
                    child: Text(
                      '我已阅读并同意用户协议和隐私政策',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSetupStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "Let's set up your account",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "First things first, let's get your profile set up.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 48),

            // Profile Image
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[900],
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _profileImage != null
                    ? ClipOval(
                        child: Image.file(
                          _profileImage!,
                          fit: BoxFit.cover,
                          width: 150,
                          height: 150,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 40,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Upload button
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.camera_alt, color: Colors.white),
              label: Text(
                'Upload photo (optional)',
                style: TextStyle(color: Colors.grey[300]),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(color: Colors.grey[700]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'JPG or PNG. 5MB max.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),

            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[400], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '您可以随时在设置中更新您的个人资料照片',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure your preferences',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Let's configure your preferences.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),

            // Preview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Example account',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getCurrencySymbol(_selectedCurrency) + '2,325.25',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '+${_getCurrencySymbol(_selectedCurrency)}78.90',
                        style: TextStyle(
                          color: Colors.green[400],
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        ' (+${_getCurrencySymbol(_selectedCurrency)}6.39)',
                        style: TextStyle(
                          color: Colors.green[400],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ' as of ${_formatDate(_selectedDateFormat)}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Preview how data displays based on preferences.',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 32),

            // Country Selection
            DropdownButtonFormField<String>(
              value: _selectedCountry,
              decoration: InputDecoration(
                labelText: '国家/地区',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.public, color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              items: _getCountryItems(),
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value!;
                  // Auto-adjust currency based on country
                  _autoAdjustCurrency(value);
                });
              },
            ),
            const SizedBox(height: 16),

            // Currency Selection
            DropdownButtonFormField<String>(
              value: _selectedCurrency,
              decoration: InputDecoration(
                labelText: '货币',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.attach_money, color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              items: _getCurrencyItems(),
              onChanged: (value) {
                setState(() {
                  _selectedCurrency = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Language Selection
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: InputDecoration(
                labelText: '语言',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.language, color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              items: _getLanguageItems(),
              onChanged: (value) {
                setState(() {
                  _selectedLanguage = value!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Timezone Selection
            DropdownButtonFormField<String>(
              value: _selectedTimezone,
              decoration: InputDecoration(
                labelText: '时区',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.access_time, color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              items: _getTimezoneItems(),
              onChanged: (value) {
                setState(() {
                  _selectedTimezone = value!;
                });
              },
              isExpanded: true,
            ),
            const SizedBox(height: 16),

            // Date Format Selection
            DropdownButtonFormField<String>(
              value: _selectedDateFormat,
              decoration: InputDecoration(
                labelText: '日期格式',
                labelStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.calendar_today, color: Colors.grey[400]),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[600]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              dropdownColor: Colors.grey[900],
              style: const TextStyle(color: Colors.white),
              items: _getDateFormatItems(),
              onChanged: (value) {
                setState(() {
                  _selectedDateFormat = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _hasMinLength ? Colors.green : Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _hasUpperLower ? Colors.green : Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _hasNumber ? Colors.green : Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _hasSpecialChar ? Colors.green : Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildRequirement('8+ 字符', _hasMinLength),
            const SizedBox(width: 16),
            _buildRequirement('大小写', _hasUpperLower),
            const SizedBox(width: 16),
            _buildRequirement('数字', _hasNumber),
            const SizedBox(width: 16),
            _buildRequirement('特殊字符', _hasSpecialChar),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 12,
          color: met ? Colors.green : Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: met ? Colors.green : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _getCountryItems() {
    if (_localeData == null) {
      return [
        const DropdownMenuItem(value: 'CN', child: Text('中国')),
        const DropdownMenuItem(value: 'US', child: Text('美国')),
      ];
    }

    final countries = _localeData!['countries'] as List<dynamic>? ?? [];
    return countries.map((country) {
      return DropdownMenuItem<String>(
        value: country['code'],
        child: Text(country['name']),
      );
    }).toList();
  }

  List<DropdownMenuItem<String>> _getCurrencyItems() {
    if (_localeData == null) {
      return [
        const DropdownMenuItem(value: 'CNY', child: Text('人民币 (¥)')),
        const DropdownMenuItem(value: 'USD', child: Text('美元 (\$)')),
      ];
    }

    final currencies = _localeData!['currencies'] as List<dynamic>? ?? [];
    return currencies.map((currency) {
      return DropdownMenuItem<String>(
        value: currency['code'],
        child: Text('${currency['name']} (${currency['symbol']})'),
      );
    }).toList();
  }

  List<DropdownMenuItem<String>> _getLanguageItems() {
    if (_localeData == null) {
      return [
        const DropdownMenuItem(value: 'zh-CN', child: Text('简体中文')),
        const DropdownMenuItem(value: 'en-US', child: Text('English')),
      ];
    }

    final languages = _localeData!['languages'] as List<dynamic>? ?? [];
    return languages.map((language) {
      return DropdownMenuItem<String>(
        value: language['code'],
        child: Text(language['name']),
      );
    }).toList();
  }

  List<DropdownMenuItem<String>> _getTimezoneItems() {
    // 常用时区列表，按地区分组
    final timezones = [
      // 东亚
      {'value': 'Asia/Shanghai', 'display': '中国标准时间 (UTC+8)'},
      {'value': 'Asia/Hong_Kong', 'display': '香港时间 (UTC+8)'},
      {'value': 'Asia/Taipei', 'display': '台北时间 (UTC+8)'},
      {'value': 'Asia/Tokyo', 'display': '日本标准时间 (UTC+9)'},
      {'value': 'Asia/Seoul', 'display': '韩国标准时间 (UTC+9)'},

      // 东南亚
      {'value': 'Asia/Singapore', 'display': '新加坡时间 (UTC+8)'},
      {'value': 'Asia/Kuala_Lumpur', 'display': '马来西亚时间 (UTC+8)'},
      {'value': 'Asia/Jakarta', 'display': '西印尼时间 (UTC+7)'},
      {'value': 'Asia/Bangkok', 'display': '曼谷时间 (UTC+7)'},
      {'value': 'Asia/Ho_Chi_Minh', 'display': '越南时间 (UTC+7)'},
      {'value': 'Asia/Manila', 'display': '菲律宾时间 (UTC+8)'},

      // 南亚
      {'value': 'Asia/Kolkata', 'display': '印度标准时间 (UTC+5:30)'},
      {'value': 'Asia/Dhaka', 'display': '孟加拉时间 (UTC+6)'},
      {'value': 'Asia/Karachi', 'display': '巴基斯坦时间 (UTC+5)'},

      // 中东
      {'value': 'Asia/Dubai', 'display': '迪拜时间 (UTC+4)'},
      {'value': 'Asia/Riyadh', 'display': '沙特时间 (UTC+3)'},
      {'value': 'Asia/Jerusalem', 'display': '以色列时间 (UTC+2/+3)'},
      {'value': 'Europe/Istanbul', 'display': '土耳其时间 (UTC+3)'},

      // 欧洲
      {'value': 'Europe/London', 'display': '伦敦时间 (UTC+0/+1)'},
      {'value': 'Europe/Paris', 'display': '巴黎时间 (UTC+1/+2)'},
      {'value': 'Europe/Berlin', 'display': '柏林时间 (UTC+1/+2)'},
      {'value': 'Europe/Madrid', 'display': '马德里时间 (UTC+1/+2)'},
      {'value': 'Europe/Rome', 'display': '罗马时间 (UTC+1/+2)'},
      {'value': 'Europe/Amsterdam', 'display': '阿姆斯特丹时间 (UTC+1/+2)'},
      {'value': 'Europe/Zurich', 'display': '苏黎世时间 (UTC+1/+2)'},
      {'value': 'Europe/Stockholm', 'display': '斯德哥尔摩时间 (UTC+1/+2)'},
      {'value': 'Europe/Moscow', 'display': '莫斯科时间 (UTC+3)'},

      // 大洋洲
      {'value': 'Australia/Sydney', 'display': '悉尼时间 (UTC+10/+11)'},
      {'value': 'Australia/Melbourne', 'display': '墨尔本时间 (UTC+10/+11)'},
      {'value': 'Australia/Perth', 'display': '珀斯时间 (UTC+8)'},
      {'value': 'Pacific/Auckland', 'display': '奥克兰时间 (UTC+12/+13)'},

      // 北美
      {'value': 'America/New_York', 'display': '纽约时间 (UTC-5/-4)'},
      {'value': 'America/Chicago', 'display': '芝加哥时间 (UTC-6/-5)'},
      {'value': 'America/Denver', 'display': '丹佛时间 (UTC-7/-6)'},
      {'value': 'America/Los_Angeles', 'display': '洛杉矶时间 (UTC-8/-7)'},
      {'value': 'America/Toronto', 'display': '多伦多时间 (UTC-5/-4)'},
      {'value': 'America/Vancouver', 'display': '温哥华时间 (UTC-8/-7)'},
      {'value': 'America/Mexico_City', 'display': '墨西哥城时间 (UTC-6/-5)'},

      // 南美
      {'value': 'America/Sao_Paulo', 'display': '圣保罗时间 (UTC-3)'},
      {'value': 'America/Buenos_Aires', 'display': '布宜诺斯艾利斯时间 (UTC-3)'},
      {'value': 'America/Santiago', 'display': '圣地亚哥时间 (UTC-4/-3)'},
      {'value': 'America/Lima', 'display': '利马时间 (UTC-5)'},

      // 非洲
      {'value': 'Africa/Cairo', 'display': '开罗时间 (UTC+2)'},
      {'value': 'Africa/Johannesburg', 'display': '约翰内斯堡时间 (UTC+2)'},
      {'value': 'Africa/Lagos', 'display': '拉各斯时间 (UTC+1)'},
      {'value': 'Africa/Nairobi', 'display': '内罗毕时间 (UTC+3)'},
    ];

    return timezones.map((tz) {
      return DropdownMenuItem<String>(
        value: tz['value'] as String,
        child: Text(
          tz['display'] as String,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList();
  }

  List<DropdownMenuItem<String>> _getDateFormatItems() {
    if (_localeData == null) {
      return [
        const DropdownMenuItem(value: 'YYYY-MM-DD', child: Text('2024-12-31')),
        const DropdownMenuItem(value: 'MM/DD/YYYY', child: Text('12/31/2024')),
        const DropdownMenuItem(value: 'DD/MM/YYYY', child: Text('31/12/2024')),
      ];
    }

    final formats = _localeData!['date_formats'] as List<dynamic>? ?? [];
    return formats.map((format) {
      return DropdownMenuItem<String>(
        value: format['format'],
        child: Text(format['example']),
      );
    }).toList();
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'CNY':
        return '¥';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      default:
        return '\$';
    }
  }

  String _formatDate(String format) {
    final now = DateTime.now();
    switch (format) {
      case 'YYYY-MM-DD':
        return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      case 'MM/DD/YYYY':
        return '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}';
      case 'DD/MM/YYYY':
        return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      case 'DD.MM.YYYY':
        return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
      default:
        return '${now.month}-${now.day}-${now.year}';
    }
  }

  void _autoAdjustCurrency(String country) {
    switch (country) {
      // 东亚地区
      case 'CN':
        _selectedCurrency = 'CNY';
        _selectedLanguage = 'zh-CN';
        _selectedTimezone = 'Asia/Shanghai';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'TW':
        _selectedCurrency = 'TWD';
        _selectedLanguage = 'zh-TW';
        _selectedTimezone = 'Asia/Taipei';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'HK':
        _selectedCurrency = 'HKD';
        _selectedLanguage = 'zh-HK';
        _selectedTimezone = 'Asia/Hong_Kong';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'MO':
        _selectedCurrency = 'MOP';
        _selectedLanguage = 'zh-MO';
        _selectedTimezone = 'Asia/Macau';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'JP':
        _selectedCurrency = 'JPY';
        _selectedLanguage = 'ja-JP';
        _selectedTimezone = 'Asia/Tokyo';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'KR':
        _selectedCurrency = 'KRW';
        _selectedLanguage = 'ko-KR';
        _selectedTimezone = 'Asia/Seoul';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;

      // 东南亚地区
      case 'SG':
        _selectedCurrency = 'SGD';
        _selectedLanguage = 'en-SG';
        _selectedTimezone = 'Asia/Singapore';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'MY':
        _selectedCurrency = 'MYR';
        _selectedLanguage = 'ms-MY';
        _selectedTimezone = 'Asia/Kuala_Lumpur';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'ID':
        _selectedCurrency = 'IDR';
        _selectedLanguage = 'id-ID';
        _selectedTimezone = 'Asia/Jakarta';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'TH':
        _selectedCurrency = 'THB';
        _selectedLanguage = 'th-TH';
        _selectedTimezone = 'Asia/Bangkok';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'VN':
        _selectedCurrency = 'VND';
        _selectedLanguage = 'vi-VN';
        _selectedTimezone = 'Asia/Ho_Chi_Minh';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'PH':
        _selectedCurrency = 'PHP';
        _selectedLanguage = 'en-PH';
        _selectedTimezone = 'Asia/Manila';
        _selectedDateFormat = 'MM/DD/YYYY';
        break;

      // 南亚地区
      case 'IN':
        _selectedCurrency = 'INR';
        _selectedLanguage = 'en-IN';
        _selectedTimezone = 'Asia/Kolkata';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'PK':
        _selectedCurrency = 'PKR';
        _selectedLanguage = 'ur-PK';
        _selectedTimezone = 'Asia/Karachi';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'BD':
        _selectedCurrency = 'BDT';
        _selectedLanguage = 'bn-BD';
        _selectedTimezone = 'Asia/Dhaka';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'LK':
        _selectedCurrency = 'LKR';
        _selectedLanguage = 'si-LK';
        _selectedTimezone = 'Asia/Colombo';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;

      // 大洋洲
      case 'AU':
        _selectedCurrency = 'AUD';
        _selectedLanguage = 'en-AU';
        _selectedTimezone = 'Australia/Sydney';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'NZ':
        _selectedCurrency = 'NZD';
        _selectedLanguage = 'en-NZ';
        _selectedTimezone = 'Pacific/Auckland';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;

      // 北美洲
      case 'US':
        _selectedCurrency = 'USD';
        _selectedLanguage = 'en-US';
        _selectedTimezone = 'America/New_York';
        _selectedDateFormat = 'MM/DD/YYYY';
        break;
      case 'CA':
        _selectedCurrency = 'CAD';
        _selectedLanguage = 'en-CA';
        _selectedTimezone = 'America/Toronto';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'MX':
        _selectedCurrency = 'MXN';
        _selectedLanguage = 'es-MX';
        _selectedTimezone = 'America/Mexico_City';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;

      // 南美洲
      case 'BR':
        _selectedCurrency = 'BRL';
        _selectedLanguage = 'pt-BR';
        _selectedTimezone = 'America/Sao_Paulo';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'AR':
        _selectedCurrency = 'ARS';
        _selectedLanguage = 'es-AR';
        _selectedTimezone = 'America/Buenos_Aires';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'CL':
        _selectedCurrency = 'CLP';
        _selectedLanguage = 'es-CL';
        _selectedTimezone = 'America/Santiago';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'CO':
        _selectedCurrency = 'COP';
        _selectedLanguage = 'es-CO';
        _selectedTimezone = 'America/Bogota';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'PE':
        _selectedCurrency = 'PEN';
        _selectedLanguage = 'es-PE';
        _selectedTimezone = 'America/Lima';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;

      // 欧洲
      case 'GB':
        _selectedCurrency = 'GBP';
        _selectedLanguage = 'en-GB';
        _selectedTimezone = 'Europe/London';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'DE':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'de-DE';
        _selectedTimezone = 'Europe/Berlin';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'FR':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'fr-FR';
        _selectedTimezone = 'Europe/Paris';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'IT':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'it-IT';
        _selectedTimezone = 'Europe/Rome';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'ES':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'es-ES';
        _selectedTimezone = 'Europe/Madrid';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'NL':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'nl-NL';
        _selectedTimezone = 'Europe/Amsterdam';
        _selectedDateFormat = 'DD-MM-YYYY';
        break;
      case 'BE':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'nl-BE';
        _selectedTimezone = 'Europe/Brussels';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'CH':
        _selectedCurrency = 'CHF';
        _selectedLanguage = 'de-CH';
        _selectedTimezone = 'Europe/Zurich';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'AT':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'de-AT';
        _selectedTimezone = 'Europe/Vienna';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'PT':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'pt-PT';
        _selectedTimezone = 'Europe/Lisbon';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'GR':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'el-GR';
        _selectedTimezone = 'Europe/Athens';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'IE':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'en-IE';
        _selectedTimezone = 'Europe/Dublin';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;

      // 北欧
      case 'SE':
        _selectedCurrency = 'SEK';
        _selectedLanguage = 'sv-SE';
        _selectedTimezone = 'Europe/Stockholm';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'NO':
        _selectedCurrency = 'NOK';
        _selectedLanguage = 'no-NO';
        _selectedTimezone = 'Europe/Oslo';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'DK':
        _selectedCurrency = 'DKK';
        _selectedLanguage = 'da-DK';
        _selectedTimezone = 'Europe/Copenhagen';
        _selectedDateFormat = 'DD-MM-YYYY';
        break;
      case 'FI':
        _selectedCurrency = 'EUR';
        _selectedLanguage = 'fi-FI';
        _selectedTimezone = 'Europe/Helsinki';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'IS':
        _selectedCurrency = 'ISK';
        _selectedLanguage = 'is-IS';
        _selectedTimezone = 'Atlantic/Reykjavik';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;

      // 东欧
      case 'RU':
        _selectedCurrency = 'RUB';
        _selectedLanguage = 'ru-RU';
        _selectedTimezone = 'Europe/Moscow';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'PL':
        _selectedCurrency = 'PLN';
        _selectedLanguage = 'pl-PL';
        _selectedTimezone = 'Europe/Warsaw';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'CZ':
        _selectedCurrency = 'CZK';
        _selectedLanguage = 'cs-CZ';
        _selectedTimezone = 'Europe/Prague';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'HU':
        _selectedCurrency = 'HUF';
        _selectedLanguage = 'hu-HU';
        _selectedTimezone = 'Europe/Budapest';
        _selectedDateFormat = 'YYYY.MM.DD';
        break;
      case 'RO':
        _selectedCurrency = 'RON';
        _selectedLanguage = 'ro-RO';
        _selectedTimezone = 'Europe/Bucharest';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'UA':
        _selectedCurrency = 'UAH';
        _selectedLanguage = 'uk-UA';
        _selectedTimezone = 'Europe/Kiev';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;

      // 中东
      case 'AE':
        _selectedCurrency = 'AED';
        _selectedLanguage = 'ar-AE';
        _selectedTimezone = 'Asia/Dubai';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'SA':
        _selectedCurrency = 'SAR';
        _selectedLanguage = 'ar-SA';
        _selectedTimezone = 'Asia/Riyadh';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'IL':
        _selectedCurrency = 'ILS';
        _selectedLanguage = 'he-IL';
        _selectedTimezone = 'Asia/Jerusalem';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'TR':
        _selectedCurrency = 'TRY';
        _selectedLanguage = 'tr-TR';
        _selectedTimezone = 'Europe/Istanbul';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'QA':
        _selectedCurrency = 'QAR';
        _selectedLanguage = 'ar-QA';
        _selectedTimezone = 'Asia/Qatar';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'KW':
        _selectedCurrency = 'KWD';
        _selectedLanguage = 'ar-KW';
        _selectedTimezone = 'Asia/Kuwait';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'BH':
        _selectedCurrency = 'BHD';
        _selectedLanguage = 'ar-BH';
        _selectedTimezone = 'Asia/Bahrain';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'OM':
        _selectedCurrency = 'OMR';
        _selectedLanguage = 'ar-OM';
        _selectedTimezone = 'Asia/Muscat';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'JO':
        _selectedCurrency = 'JOD';
        _selectedLanguage = 'ar-JO';
        _selectedTimezone = 'Asia/Amman';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'LB':
        _selectedCurrency = 'LBP';
        _selectedLanguage = 'ar-LB';
        _selectedTimezone = 'Asia/Beirut';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;

      // 非洲
      case 'ZA':
        _selectedCurrency = 'ZAR';
        _selectedLanguage = 'en-ZA';
        _selectedTimezone = 'Africa/Johannesburg';
        _selectedDateFormat = 'YYYY/MM/DD';
        break;
      case 'EG':
        _selectedCurrency = 'EGP';
        _selectedLanguage = 'ar-EG';
        _selectedTimezone = 'Africa/Cairo';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'NG':
        _selectedCurrency = 'NGN';
        _selectedLanguage = 'en-NG';
        _selectedTimezone = 'Africa/Lagos';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'KE':
        _selectedCurrency = 'KES';
        _selectedLanguage = 'en-KE';
        _selectedTimezone = 'Africa/Nairobi';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'MA':
        _selectedCurrency = 'MAD';
        _selectedLanguage = 'ar-MA';
        _selectedTimezone = 'Africa/Casablanca';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'TN':
        _selectedCurrency = 'TND';
        _selectedLanguage = 'ar-TN';
        _selectedTimezone = 'Africa/Tunis';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'GH':
        _selectedCurrency = 'GHS';
        _selectedLanguage = 'en-GH';
        _selectedTimezone = 'Africa/Accra';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'ET':
        _selectedCurrency = 'ETB';
        _selectedLanguage = 'am-ET';
        _selectedTimezone = 'Africa/Addis_Ababa';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'TZ':
        _selectedCurrency = 'TZS';
        _selectedLanguage = 'sw-TZ';
        _selectedTimezone = 'Africa/Dar_es_Salaam';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'UG':
        _selectedCurrency = 'UGX';
        _selectedLanguage = 'en-UG';
        _selectedTimezone = 'Africa/Kampala';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
    }
  }
}
