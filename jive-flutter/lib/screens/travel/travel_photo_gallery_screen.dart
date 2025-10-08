import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:jive_money/models/travel_event.dart';
import 'package:intl/intl.dart';

/// Photo attachment model
class TravelPhoto {
  final String id;
  final String eventId;
  final String filePath;
  final String? caption;
  final DateTime uploadedAt;
  final String? location;
  final Map<String, dynamic>? metadata;

  TravelPhoto({
    required this.id,
    required this.eventId,
    required this.filePath,
    this.caption,
    required this.uploadedAt,
    this.location,
    this.metadata,
  });
}

/// Photo gallery screen for travel events
class TravelPhotoGalleryScreen extends ConsumerStatefulWidget {
  final TravelEvent travelEvent;

  const TravelPhotoGalleryScreen({
    super.key,
    required this.travelEvent,
  });

  @override
  ConsumerState<TravelPhotoGalleryScreen> createState() => _TravelPhotoGalleryScreenState();
}

class _TravelPhotoGalleryScreenState extends ConsumerState<TravelPhotoGalleryScreen> {
  final ImagePicker _picker = ImagePicker();
  List<TravelPhoto> _photos = [];
  bool _isLoading = false;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load photos from local storage
      final photos = await _getPhotosFromStorage();

      if (mounted) {
        setState(() {
          _photos = photos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载照片失败: $e')),
        );
      }
    }
  }

  Future<List<TravelPhoto>> _getPhotosFromStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final travelPhotosPath = path.join(directory.path, 'travel_photos', widget.travelEvent.id);
      final travelPhotosDir = Directory(travelPhotosPath);

      if (!await travelPhotosDir.exists()) {
        return [];
      }

      final photos = <TravelPhoto>[];
      final files = travelPhotosDir.listSync();

      for (var file in files) {
        if (file is File && _isImageFile(file.path)) {
          final fileName = path.basename(file.path);
          final parts = fileName.split('_');

          photos.add(TravelPhoto(
            id: parts.isNotEmpty ? parts[0] : fileName,
            eventId: widget.travelEvent.id!,
            filePath: file.path,
            uploadedAt: file.statSync().modified,
          ));
        }
      }

      // Sort by upload date (newest first)
      photos.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      return photos;
    } catch (e) {
      return [];
    }
  }

  bool _isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        await _saveImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e')),
        );
      }
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      for (var image in images) {
        await _saveImage(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e')),
        );
      }
    }
  }

  Future<void> _saveImage(XFile image) async {
    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final travelPhotosPath = path.join(directory.path, 'travel_photos', widget.travelEvent.id);
      final travelPhotosDir = Directory(travelPhotosPath);

      // Create directory if it doesn't exist
      if (!await travelPhotosDir.exists()) {
        await travelPhotosDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${path.basename(image.path)}';
      final savedPath = path.join(travelPhotosPath, fileName);

      // Copy image to app directory
      await File(image.path).copy(savedPath);

      // Create photo object
      final photo = TravelPhoto(
        id: timestamp.toString(),
        eventId: widget.travelEvent.id!,
        filePath: savedPath,
        uploadedAt: DateTime.now(),
      );

      // Update UI
      if (mounted) {
        setState(() {
          _photos.insert(0, photo);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片已添加')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存照片失败: $e')),
        );
      }
    }
  }

  Future<void> _deletePhoto(TravelPhoto photo) async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除照片'),
          content: const Text('确定要删除这张照片吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Delete file
      final file = File(photo.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Update UI
      if (mounted) {
        setState(() {
          _photos.removeWhere((p) => p.id == photo.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('照片已删除')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除照片失败: $e')),
        );
      }
    }
  }

  void _viewPhoto(TravelPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewScreen(
          photo: photo,
          photos: _photos,
        ),
      ),
    );
  }

  void _showAddPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择单张'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择多张'),
              onTap: () {
                Navigator.pop(context);
                _pickMultipleImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.travelEvent.name} - 照片'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? _buildEmptyState()
              : _isGridView
                  ? _buildGridView()
                  : _buildListView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPhotoOptions,
        label: const Text('添加照片'),
        icon: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '还没有照片',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加旅行照片',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return _buildPhotoGridItem(photo);
      },
    );
  }

  Widget _buildPhotoGridItem(TravelPhoto photo) {
    return GestureDetector(
      onTap: () => _viewPhoto(photo),
      onLongPress: () => _showPhotoOptions(photo),
      child: Hero(
        tag: 'photo_${photo.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: FileImage(File(photo.filePath)),
              fit: BoxFit.cover,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return _buildPhotoListItem(photo);
      },
    );
  }

  Widget _buildPhotoListItem(TravelPhoto photo) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _viewPhoto(photo),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(
                File(photo.filePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, size: 50),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(photo.uploadedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deletePhoto(photo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoOptions(TravelPhoto photo) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('查看'),
              onTap: () {
                Navigator.pop(context);
                _viewPhoto(photo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deletePhoto(photo);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo view screen for full screen viewing
class PhotoViewScreen extends StatefulWidget {
  final TravelPhoto photo;
  final List<TravelPhoto> photos;

  const PhotoViewScreen({
    super.key,
    required this.photo,
    required this.photos,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.photos.indexOf(widget.photo);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          return Center(
            child: Hero(
              tag: 'photo_${photo.id}',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  File(photo.filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Text(
            dateFormat.format(widget.photos[_currentIndex].uploadedAt),
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}