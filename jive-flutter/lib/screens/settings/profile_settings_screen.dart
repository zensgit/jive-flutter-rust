import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:jive_money/services/api_service.dart';
import 'package:jive_money/services/auth_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSaving = false;

  // User data
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _localeData;
  File? _newProfileImage;
  Map<String, dynamic>? _selectedSystemAvatar;

  // Network avatar URLs - 可从网络加载的头像
  final List<Map<String, dynamic>> _networkAvatars = [
    // DiceBear v7 API - Avataaars 风格 (卡通人物)
    {'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Felix', 'name': 'Felix'},
    {'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Aneka', 'name': 'Aneka'},
    {'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah', 'name': 'Sarah'},
    {'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=John', 'name': 'John'},
    {'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Emma', 'name': 'Emma'},
    {'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Oliver', 'name': 'Oliver'},
    {'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sophia', 'name': 'Sophia'},
    {'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Liam', 'name': 'Liam'},

    // DiceBear v7 - Bottts 风格 (机器人)
    {'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=Bot1', 'name': 'Bot 1'},
    {'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=Bot2', 'name': 'Bot 2'},
    {'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=Bot3', 'name': 'Bot 3'},
    {'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=Bot4', 'name': 'Bot 4'},
    {'url': 'https://api.dicebear.com/7.x/bottts/svg?seed=Bot5', 'name': 'Bot 5'},

    // DiceBear v7 - Micah 风格 (抽象人物)
    {'url': 'https://api.dicebear.com/7.x/micah/svg?seed=Person1', 'name': 'Person 1'},
    {'url': 'https://api.dicebear.com/7.x/micah/svg?seed=Person2', 'name': 'Person 2'},
    {'url': 'https://api.dicebear.com/7.x/micah/svg?seed=Person3', 'name': 'Person 3'},
    {'url': 'https://api.dicebear.com/7.x/micah/svg?seed=Person4', 'name': 'Person 4'},

    // DiceBear v7 - Adventurer 风格 (冒险者)
    {'url': 'https://api.dicebear.com/7.x/adventurer/svg?seed=Alex', 'name': 'Alex'},
    {'url': 'https://api.dicebear.com/7.x/adventurer/svg?seed=Sam', 'name': 'Sam'},
    {'url': 'https://api.dicebear.com/7.x/adventurer/svg?seed=Jordan', 'name': 'Jordan'},
    {'url': 'https://api.dicebear.com/7.x/adventurer/svg?seed=Taylor', 'name': 'Taylor'},
    {'url': 'https://api.dicebear.com/7.x/adventurer/svg?seed=Casey', 'name': 'Casey'},

    // DiceBear v7 - Lorelei 风格 (现代人物)
    {'url': 'https://api.dicebear.com/7.x/lorelei/svg?seed=Luna', 'name': 'Luna'},
    {'url': 'https://api.dicebear.com/7.x/lorelei/svg?seed=Nova', 'name': 'Nova'},
    {'url': 'https://api.dicebear.com/7.x/lorelei/svg?seed=Zara', 'name': 'Zara'},
    {'url': 'https://api.dicebear.com/7.x/lorelei/svg?seed=Maya', 'name': 'Maya'},

    // DiceBear v7 - Personas 风格 (简约人物)
    {'url': 'https://api.dicebear.com/7.x/personas/svg?seed=User1', 'name': 'Persona 1'},
    {'url': 'https://api.dicebear.com/7.x/personas/svg?seed=User2', 'name': 'Persona 2'},
    {'url': 'https://api.dicebear.com/7.x/personas/svg?seed=User3', 'name': 'Persona 3'},
    {'url': 'https://api.dicebear.com/7.x/personas/svg?seed=User4', 'name': 'Persona 4'},

    // DiceBear v7 - Pixel Art 风格 (像素风)
    {'url': 'https://api.dicebear.com/7.x/pixel-art/svg?seed=Pixel1', 'name': 'Pixel 1'},
    {'url': 'https://api.dicebear.com/7.x/pixel-art/svg?seed=Pixel2', 'name': 'Pixel 2'},
    {'url': 'https://api.dicebear.com/7.x/pixel-art/svg?seed=Pixel3', 'name': 'Pixel 3'},
    {'url': 'https://api.dicebear.com/7.x/pixel-art/svg?seed=Pixel4', 'name': 'Pixel 4'},

    // DiceBear v7 - Fun Emoji 风格 (趣味表情)
    {'url': 'https://api.dicebear.com/7.x/fun-emoji/svg?seed=Happy', 'name': 'Happy'},
    {'url': 'https://api.dicebear.com/7.x/fun-emoji/svg?seed=Cool', 'name': 'Cool'},
    {'url': 'https://api.dicebear.com/7.x/fun-emoji/svg?seed=Smile', 'name': 'Smile'},
    {'url': 'https://api.dicebear.com/7.x/fun-emoji/svg?seed=Wink', 'name': 'Wink'},

    // DiceBear v7 - Big Smile 风格 (大笑脸)
    {'url': 'https://api.dicebear.com/7.x/big-smile/svg?seed=Joy1', 'name': 'Joy 1'},
    {'url': 'https://api.dicebear.com/7.x/big-smile/svg?seed=Joy2', 'name': 'Joy 2'},
    {'url': 'https://api.dicebear.com/7.x/big-smile/svg?seed=Joy3', 'name': 'Joy 3'},

    // DiceBear v7 - Identicon 风格 (几何图案)
    {'url': 'https://api.dicebear.com/7.x/identicon/svg?seed=ID1', 'name': 'Geo 1'},
    {'url': 'https://api.dicebear.com/7.x/identicon/svg?seed=ID2', 'name': 'Geo 2'},
    {'url': 'https://api.dicebear.com/7.x/identicon/svg?seed=ID3', 'name': 'Geo 3'},

    // RoboHash - 机器人和动物
    {'url': 'https://robohash.org/user1?set=set1', 'name': 'Robo 1'},
    {'url': 'https://robohash.org/user2?set=set2', 'name': 'Robo 2'},
    {'url': 'https://robohash.org/user3?set=set3', 'name': 'Robo 3'},
    {'url': 'https://robohash.org/cat1?set=set4', 'name': 'Cat 1'},
    {'url': 'https://robohash.org/cat2?set=set4', 'name': 'Cat 2'},
    {'url': 'https://robohash.org/monster1?set=set2', 'name': 'Monster'},
  ];

  // System avatars - 扩展到24个选项
  final List<Map<String, dynamic>> _systemAvatars = [
    // 动物系列
    {
      'icon': '🦁',
      'background': Colors.orange.shade100,
      'color': Colors.orange.shade900
    },
    {'icon': '🐼', 'background': Colors.grey.shade200, 'color': Colors.black87},
    {
      'icon': '🦊',
      'background': Colors.deepOrange.shade100,
      'color': Colors.deepOrange.shade900
    },
    {
      'icon': '🐰',
      'background': Colors.pink.shade100,
      'color': Colors.pink.shade900
    },
    {
      'icon': '🐸',
      'background': Colors.green.shade100,
      'color': Colors.green.shade900
    },
    {
      'icon': '🦋',
      'background': Colors.indigo.shade100,
      'color': Colors.indigo.shade900
    },
    {
      'icon': '🐯',
      'background': Colors.amber.shade100,
      'color': Colors.amber.shade900
    },
    {
      'icon': '🐨',
      'background': Colors.blueGrey.shade100,
      'color': Colors.blueGrey.shade900
    },
    {
      'icon': '🦄',
      'background': Colors.purple.shade100,
      'color': Colors.purple.shade900
    },
    {
      'icon': '🐧',
      'background': Colors.cyan.shade100,
      'color': Colors.cyan.shade900
    },
    {
      'icon': '🦉',
      'background': Colors.brown.shade100,
      'color': Colors.brown.shade900
    },
    {
      'icon': '🐙',
      'background': Colors.deepPurple.shade100,
      'color': Colors.deepPurple.shade900
    },

    // 表情系列
    {
      'icon': '😀',
      'background': Colors.blue.shade100,
      'color': Colors.blue.shade900
    },
    {
      'icon': '😎',
      'background': Colors.teal.shade100,
      'color': Colors.teal.shade900
    },
    {
      'icon': '🤓',
      'background': Colors.lime.shade100,
      'color': Colors.lime.shade900
    },
    {
      'icon': '😇',
      'background': Colors.lightBlue.shade100,
      'color': Colors.lightBlue.shade900
    },
    {
      'icon': '🥳',
      'background': Colors.red.shade100,
      'color': Colors.red.shade900
    },
    {
      'icon': '🤠',
      'background': Colors.brown.shade200,
      'color': Colors.brown.shade800
    },

    // 符号系列
    {
      'icon': '🌟',
      'background': Colors.amber.shade100,
      'color': Colors.amber.shade900
    },
    {
      'icon': '🌈',
      'background': Colors.cyan.shade100,
      'color': Colors.cyan.shade900
    },
    {
      'icon': '🎨',
      'background': Colors.teal.shade100,
      'color': Colors.teal.shade900
    },
    {
      'icon': '🚀',
      'background': Colors.red.shade100,
      'color': Colors.red.shade900
    },
    {
      'icon': '💎',
      'background': Colors.blue.shade200,
      'color': Colors.blue.shade800
    },
    {
      'icon': '🎯',
      'background': Colors.green.shade200,
      'color': Colors.green.shade800
    },
  ];

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _verificationCodeFocusNode = FocusNode();

  // Preferences
  String _selectedCountry = 'CN';
  String _selectedCurrency = 'CNY';
  String _selectedLanguage = 'zh-CN';
  String _selectedTimezone = 'Asia/Shanghai';
  String _selectedDateFormat = 'YYYY-MM-DD';

  // Delete account
  final _verificationCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _verificationCodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load user profile
      final profileResponse = await _apiService.get('/auth/profile-enhanced');

      // Load locale data
      final localeResponse = await _apiService.get('/locales');

      if (mounted) {
        setState(() {
          if (profileResponse['success'] == true) {
            _userData = profileResponse['data'];
            _nameController.text = _userData!['name'] ?? '';
            _emailController.text = _userData!['email'] ?? '';
            _selectedCountry = _userData!['country'] ?? 'CN';
            _selectedCurrency = _userData!['preferred_currency'] ?? 'CNY';
            _selectedLanguage = _userData!['preferred_language'] ?? 'zh-CN';
            _selectedTimezone =
                _userData!['preferred_timezone'] ?? 'Asia/Shanghai';
            _selectedDateFormat =
                _userData!['preferred_date_format'] ?? 'YYYY-MM-DD';
          }

          if (localeResponse['success'] == true) {
            _localeData = localeResponse['data'];
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        _newProfileImage = File(image.path);
        _selectedSystemAvatar =
            null; // Clear system avatar when uploading custom
      });
    }
  }

  void _showSystemAvatarPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DefaultTabController(
          length: 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '选择头像',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const TabBar(
                  tabs: [
                    Tab(text: '系统头像', icon: Icon(Icons.emoji_emotions)),
                    Tab(text: '网络头像', icon: Icon(Icons.cloud_download)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: TabBarView(
                    children: [
                      // System avatars tab
                      GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _systemAvatars.length,
                        itemBuilder: (context, index) {
                          final avatar = _systemAvatars[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSystemAvatar = avatar;
                                _newProfileImage = null;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedSystemAvatar == avatar
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundColor: avatar['background'] as Color,
                                child: Center(
                                  child: Text(
                                    avatar['icon'] as String,
                                    style: const TextStyle(fontSize: 28),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // Network avatars tab
                      GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _networkAvatars.length,
                        itemBuilder: (context, index) {
                          final avatar = _networkAvatars[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSystemAvatar = {
                                  'type': 'network',
                                  'url': avatar['url'],
                                  'name': avatar['name'],
                                };
                                _newProfileImage = null;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedSystemAvatar?['url'] ==
                                          avatar['url']
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade300,
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                child: ClipOval(
                                  child: Image.network(
                                    avatar['url'],
                                    fit: BoxFit.cover,
                                    width: 60,
                                    height: 60,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey.shade300,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: 30,
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Update user info
      await _apiService.put('/auth/user', {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      });

      // Update preferences (移除货币设置，货币在专门的货币管理页面设置)
      await _apiService.put('/auth/preferences', {
        'country': _selectedCountry,
        'language': _selectedLanguage,
        'timezone': _selectedTimezone,
        'date_format': _selectedDateFormat,
      });

      // Upload profile image if changed
      if (_newProfileImage != null) {
        // TODO: Implement custom image upload to server
        // For now, just show success message
        debugPrint('Custom image selected: ${_newProfileImage!.path}');
      }

      // Update system avatar if selected
      if (_selectedSystemAvatar != null) {
        await _apiService.put('/auth/avatar', {
          'avatar_type': 'emoji',
          'avatar_data': _selectedSystemAvatar!['icon'],
          'avatar_color':
              '#${(_selectedSystemAvatar!['color'] as Color).toARGB32().toRadixString(16).padLeft(8, '0')}',
          'avatar_background':
              '#${(_selectedSystemAvatar!['background'] as Color).toARGB32().toRadixString(16).padLeft(8, '0')}',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('个人资料已更新'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _requestDeleteCode() async {
    try {
      await _apiService.post('/auth/request-delete-code', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('验证码已发送到您的邮箱'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送验证码失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetAccount() async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置账户'),
        content: const Text(
          '此操作将删除您所有的账户、分类、收款人、标签和其他交易数据。\n\n'
          '您的用户账户将保留，但所有财务数据将被清除。\n\n'
          '此操作不可逆！您确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '确认重置',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 再次确认
    final finalConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('最后确认'),
          ],
        ),
        content: const Text(
          '这是最后一次确认！\n\n'
          '所有财务数据将被永久删除。\n'
          '确定要重置账户吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (finalConfirmed != true) return;

    try {
      // Call reset API
      await _apiService.post('/auth/reset-account', {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('账户已成功重置'),
            backgroundColor: Colors.green,
          ),
        );

        // 返回主页
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重置账户失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final code = _verificationCodeController.text.trim();
    if (code.isEmpty || code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入4位验证码'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _apiService.delete('/auth/delete?code=$code');

      // Clear auth data
      await _authService.logout();

      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除账户失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('个人资料设置'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人资料设置'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              '保存',
              style: TextStyle(
                color: _isSaving ? Colors.grey : Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Image Section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _selectedSystemAvatar != null &&
                                    _selectedSystemAvatar!['type'] != 'network'
                                ? _selectedSystemAvatar!['background'] as Color
                                : Colors.grey[200],
                            image: _newProfileImage != null
                                ? DecorationImage(
                                    image: FileImage(_newProfileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : (_selectedSystemAvatar?['type'] == 'network')
                                    ? DecorationImage(
                                        image: NetworkImage(
                                            _selectedSystemAvatar!['url']),
                                        fit: BoxFit.cover,
                                      )
                                    : (_userData?['avatar_url'] != null &&
                                            _selectedSystemAvatar == null &&
                                            _newProfileImage == null)
                                        ? DecorationImage(
                                            image: NetworkImage(
                                                _userData!['avatar_url']),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                          ),
                          child: (_newProfileImage == null &&
                                  _selectedSystemAvatar == null &&
                                  _userData?['avatar_url'] == null)
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey[400],
                                )
                              : _selectedSystemAvatar != null
                                  ? (_selectedSystemAvatar!['type'] == 'network'
                                      ? null // Network image is handled by DecorationImage
                                      : Center(
                                          child: Text(
                                            _selectedSystemAvatar!['icon']
                                                as String,
                                            style: const TextStyle(
                                              fontSize: 40,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ))
                                  : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Bottom-left: System avatar button
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: GestureDetector(
                            onTap: _showSystemAvatarPicker,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.face,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '左下角: 系统头像 | 右下角: 上传图片',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '网络头像由 DiceBear 和 RoboHash 提供 · 查看"关于"了解许可',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Basic Info Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '基本信息',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 用户名输入框 - 使用 EditableText 避免 NaN 错误
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('用户名', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTap: () => _nameFocusNode.requestFocus(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: constraints.maxWidth - 80,
                                    child: EditableText(
                                      controller: _nameController,
                                      focusNode: _nameFocusNode,
                                      style: const TextStyle(fontSize: 16, color: Colors.black),
                                      cursorColor: Colors.blue,
                                      backgroundCursorColor: Colors.grey,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 邮箱输入框 - 使用 EditableText 避免 NaN 错误
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('邮箱', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onTap: () => _emailFocusNode.requestFocus(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.email, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: constraints.maxWidth - 80,
                                    child: EditableText(
                                      controller: _emailController,
                                      focusNode: _emailFocusNode,
                                      style: const TextStyle(fontSize: 16, color: Colors.black),
                                      cursorColor: Colors.blue,
                                      backgroundCursorColor: Colors.grey,
                                      keyboardType: TextInputType.emailAddress,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 12),
                        child: Text(
                          '修改邮箱可能需要重新验证',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(),

            // Preferences Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '偏好设置',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '示例账户',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_getCurrencySymbol(_selectedCurrency)}2,325.25',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '日期: ${_formatDate(_selectedDateFormat)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '货币设置请前往: 设置 → 货币管理',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Country
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCountry,
                    decoration: const InputDecoration(
                      labelText: '国家/地区',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.public),
                    ),
                    items: _getCountryItems(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCountry = value!;
                        _autoAdjustSettings(value);
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Language
                  DropdownButtonFormField<String>(
                    initialValue: _selectedLanguage,
                    decoration: const InputDecoration(
                      labelText: '语言',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language),
                    ),
                    items: _getLanguageItems(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLanguage = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Timezone
                  DropdownButtonFormField<String>(
                    initialValue: _selectedTimezone,
                    decoration: const InputDecoration(
                      labelText: '时区',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    items: _getTimezoneItems(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTimezone = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Format
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDateFormat,
                    decoration: const InputDecoration(
                      labelText: '日期格式',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
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

            const Divider(),

            // Danger Zone
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '危险操作',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reset Account Card
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '重置账户',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '重置账户将删除您所有的账户、分类、收款人、标签和其他数据，但保留您的用户账户。',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _resetAccount,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                              child: const Text('重置账户'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delete Account Card
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '删除账户',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '删除账户后，您的所有数据将被永久删除，无法恢复。',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // 验证码输入框 - 使用 EditableText 避免 NaN 错误
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('验证码（4位）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return GestureDetector(
                                          onTap: () => _verificationCodeFocusNode.requestFocus(),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.grey.shade400),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: SizedBox(
                                              width: constraints.maxWidth - 24,
                                              child: EditableText(
                                                controller: _verificationCodeController,
                                                focusNode: _verificationCodeFocusNode,
                                                style: const TextStyle(fontSize: 16, color: Colors.black),
                                                cursorColor: Colors.blue,
                                                backgroundCursorColor: Colors.grey,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.digitsOnly,
                                                  LengthLimitingTextInputFormatter(4), // 限制最大长度为4
                                                ],
                                                autocorrect: false,
                                                enableSuggestions: false,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _requestDeleteCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text('获取验证码'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('确认删除账户'),
                                    content: const Text(
                                      '您确定要删除账户吗？此操作不可逆！',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteAccount();
                                        },
                                        child: const Text(
                                          '确认删除',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('删除账户'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _getCountryItems() {
    // 默认的国家列表
    final defaultCountries = [
      const DropdownMenuItem(value: 'CN', child: Text('中国')),
      const DropdownMenuItem(value: 'US', child: Text('美国')),
      const DropdownMenuItem(value: 'JP', child: Text('日本')),
    ];

    if (_localeData == null) {
      return defaultCountries;
    }

    final countries = _localeData!['countries'] as List<dynamic>? ?? [];
    if (countries.isEmpty) {
      return defaultCountries;
    }

    final apiCountries = countries.map((country) {
      return DropdownMenuItem<String>(
        value: country['code']?.toString() ?? '',
        child: Text(country['name']?.toString() ?? ''),
      );
    }).toList();

    // 确保当前选中的值在列表中
    final hasSelectedValue =
        apiCountries.any((item) => item.value == _selectedCountry);
    if (!hasSelectedValue && _selectedCountry.isNotEmpty) {
      apiCountries.insert(
          0,
          DropdownMenuItem<String>(
            value: _selectedCountry,
            child: Text(_selectedCountry),
          ));
    }

    return apiCountries;
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
    // 默认的语言列表
    final defaultLanguages = [
      const DropdownMenuItem(value: 'zh-CN', child: Text('简体中文')),
      const DropdownMenuItem(value: 'en-US', child: Text('English')),
    ];

    if (_localeData == null) {
      return defaultLanguages;
    }

    final languages = _localeData!['languages'] as List<dynamic>? ?? [];
    if (languages.isEmpty) {
      return defaultLanguages;
    }

    final apiLanguages = languages.map((language) {
      return DropdownMenuItem<String>(
        value: language['code']?.toString() ?? '',
        child: Text(language['name']?.toString() ?? ''),
      );
    }).toList();

    // 确保当前选中的值在列表中
    final hasSelectedValue =
        apiLanguages.any((item) => item.value == _selectedLanguage);
    if (!hasSelectedValue && _selectedLanguage.isNotEmpty) {
      apiLanguages.insert(
          0,
          DropdownMenuItem<String>(
            value: _selectedLanguage,
            child: Text(_selectedLanguage),
          ));
    }

    return apiLanguages;
  }

  List<DropdownMenuItem<String>> _getTimezoneItems() {
    // 默认的时区列表
    final defaultTimezones = [
      const DropdownMenuItem(value: 'Asia/Shanghai', child: Text('北京时间')),
      const DropdownMenuItem(value: 'America/New_York', child: Text('纽约时间')),
      const DropdownMenuItem(value: 'Europe/London', child: Text('伦敦时间')),
      const DropdownMenuItem(value: 'Asia/Tokyo', child: Text('东京时间')),
    ];

    if (_localeData == null) {
      return defaultTimezones;
    }

    final timezones = _localeData!['timezones'] as List<dynamic>? ?? [];
    if (timezones.isEmpty) {
      return defaultTimezones;
    }

    // 从API数据构建时区列表
    final apiTimezones = timezones.map((timezone) {
      return DropdownMenuItem<String>(
        value: timezone['zone']?.toString() ?? '',
        child: Text(timezone['name']?.toString() ?? ''),
      );
    }).toList();

    // 确保当前选中的值在列表中
    final hasSelectedValue =
        apiTimezones.any((item) => item.value == _selectedTimezone);
    if (!hasSelectedValue && _selectedTimezone.isNotEmpty) {
      // 如果当前选中的值不在列表中，添加它
      apiTimezones.insert(
          0,
          DropdownMenuItem<String>(
            value: _selectedTimezone,
            child: Text(_selectedTimezone),
          ));
    }

    return apiTimezones;
  }

  List<DropdownMenuItem<String>> _getDateFormatItems() {
    // 默认的日期格式列表
    final defaultFormats = [
      const DropdownMenuItem(value: 'YYYY-MM-DD', child: Text('2024-12-31')),
      const DropdownMenuItem(value: 'MM/DD/YYYY', child: Text('12/31/2024')),
      const DropdownMenuItem(value: 'DD/MM/YYYY', child: Text('31/12/2024')),
    ];

    if (_localeData == null) {
      return defaultFormats;
    }

    final formats = _localeData!['date_formats'] as List<dynamic>? ?? [];
    if (formats.isEmpty) {
      return defaultFormats;
    }

    final apiFormats = formats.map((format) {
      return DropdownMenuItem<String>(
        value: format['format']?.toString() ?? '',
        child: Text(format['example']?.toString() ?? ''),
      );
    }).toList();

    // 确保当前选中的值在列表中
    final hasSelectedValue =
        apiFormats.any((item) => item.value == _selectedDateFormat);
    if (!hasSelectedValue && _selectedDateFormat.isNotEmpty) {
      apiFormats.insert(
          0,
          DropdownMenuItem<String>(
            value: _selectedDateFormat,
            child: Text(_selectedDateFormat),
          ));
    }

    return apiFormats;
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

  void _autoAdjustSettings(String country) {
    // 根据国家自动调整语言、时区和日期格式（货币在货币管理页面设置）
    switch (country) {
      case 'CN':
        _selectedLanguage = 'zh-CN';
        _selectedTimezone = 'Asia/Shanghai';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'TW':
        _selectedLanguage = 'zh-TW';
        _selectedTimezone = 'Asia/Taipei';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'HK':
        _selectedLanguage = 'zh-HK';
        _selectedTimezone = 'Asia/Hong_Kong';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'SG':
        _selectedLanguage = 'en-SG';
        _selectedTimezone = 'Asia/Singapore';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'MY':
        _selectedLanguage = 'ms-MY';
        _selectedTimezone = 'Asia/Kuala_Lumpur';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'IN':
        _selectedLanguage = 'en-IN';
        _selectedTimezone = 'Asia/Kolkata';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'ID':
        _selectedLanguage = 'id-ID';
        _selectedTimezone = 'Asia/Jakarta';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'TH':
        _selectedLanguage = 'th-TH';
        _selectedTimezone = 'Asia/Bangkok';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'US':
        _selectedLanguage = 'en-US';
        _selectedTimezone = 'America/New_York';
        _selectedDateFormat = 'MM/DD/YYYY';
        break;
      case 'GB':
        _selectedLanguage = 'en-GB';
        _selectedTimezone = 'Europe/London';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'JP':
        _selectedLanguage = 'ja-JP';
        _selectedTimezone = 'Asia/Tokyo';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'KR':
        _selectedLanguage = 'ko-KR';
        _selectedTimezone = 'Asia/Seoul';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'AU':
        _selectedLanguage = 'en-AU';
        _selectedTimezone = 'Australia/Sydney';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'CA':
        _selectedLanguage = 'en-CA';
        _selectedTimezone = 'America/Toronto';
        _selectedDateFormat = 'YYYY-MM-DD';
        break;
      case 'DE':
        _selectedLanguage = 'de-DE';
        _selectedTimezone = 'Europe/Berlin';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'FR':
        _selectedLanguage = 'fr-FR';
        _selectedTimezone = 'Europe/Paris';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'IT':
        _selectedLanguage = 'it-IT';
        _selectedTimezone = 'Europe/Rome';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'ES':
        _selectedLanguage = 'es-ES';
        _selectedTimezone = 'Europe/Madrid';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'RU':
        _selectedLanguage = 'ru-RU';
        _selectedTimezone = 'Europe/Moscow';
        _selectedDateFormat = 'DD.MM.YYYY';
        break;
      case 'BR':
        _selectedLanguage = 'pt-BR';
        _selectedTimezone = 'America/Sao_Paulo';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'MX':
        _selectedLanguage = 'es-MX';
        _selectedTimezone = 'America/Mexico_City';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'AE':
        _selectedLanguage = 'ar-AE';
        _selectedTimezone = 'Asia/Dubai';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'SA':
        _selectedLanguage = 'ar-SA';
        _selectedTimezone = 'Asia/Riyadh';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'ZA':
        _selectedLanguage = 'en-ZA';
        _selectedTimezone = 'Africa/Johannesburg';
        _selectedDateFormat = 'YYYY/MM/DD';
        break;
      case 'EG':
        _selectedLanguage = 'ar-EG';
        _selectedTimezone = 'Africa/Cairo';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
      case 'NG':
        _selectedLanguage = 'en-NG';
        _selectedTimezone = 'Africa/Lagos';
        _selectedDateFormat = 'DD/MM/YYYY';
        break;
    }
  }
}
