import 'package:flutter/material.dart';

/// Utility class for handling image loading with fallbacks
class ImageUtils {
  /// Load network image with error handling
  static Widget loadNetworkImage({
    required String? url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // Check if URL is valid
    if (url == null || url.isEmpty) {
      return errorWidget ?? _defaultErrorWidget(width, height);
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _defaultPlaceholder(width, height);
      },
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image from $url: $error');
        return errorWidget ?? _defaultErrorWidget(width, height);
      },
    );
  }

  /// Load avatar with fallback
  static Widget loadAvatar({
    String? imageUrl,
    String? name,
    double radius = 20,
  }) {
    // Generate initials from name
    String initials = _getInitials(name ?? 'U');
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey[300],
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (exception, stackTrace) {
          print('Error loading avatar: $exception');
        },
        child: Text(
          initials,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    // Fallback to initials
    return CircleAvatar(
      radius: radius,
      backgroundColor: _getColorFromName(name),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Default placeholder widget
  static Widget _defaultPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  /// Default error widget
  static Widget _defaultErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.broken_image,
        color: Colors.grey[400],
        size: (width ?? 40) * 0.5,
      ),
    );
  }

  /// Get initials from name
  static String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  /// Get color from name for avatar background
  static Color _getColorFromName(String? name) {
    if (name == null || name.isEmpty) {
      return Colors.grey;
    }
    
    // Generate color based on name hash
    final hash = name.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];
    
    return colors[hash.abs() % colors.length];
  }

  /// Validate image URL
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return false;
      }
      
      // Check for common image extensions
      final path = uri.path.toLowerCase();
      final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'];
      
      // Allow URLs without extensions (many CDNs don't use them)
      // but validate the URL structure
      return uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}