import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

class NetworkAwareImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const NetworkAwareImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);
    final isOnline = connectivityProvider.isOnline;
    
    // Default placeholder
    final defaultPlaceholder = Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.image,
          color: Colors.grey[500],
          size: 32.0,
        ),
      ),
    );
    
    // Default error widget
    final defaultErrorWidget = Container(
      color: Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.red[300],
          size: 32.0,
        ),
      ),
    );
    
    // If offline, show placeholder
    if (!isOnline) {
      return Container(
        width: width,
        height: height,
        child: Stack(
          children: [
            placeholder ?? defaultPlaceholder,
            Positioned(
              top: 8.0,
              right: 8.0,
              child: Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: const Icon(
                  Icons.wifi_off,
                  color: Colors.white,
                  size: 16.0,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // If online, use CachedNetworkImage
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      errorWidget: (context, url, error) => errorWidget ?? defaultErrorWidget,
    );
  }
}