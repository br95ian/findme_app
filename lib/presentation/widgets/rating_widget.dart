import 'package:flutter/material.dart';

class RatingWidget extends StatelessWidget {
  final int rating;
  final int maxRating;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Function(int)? onRatingChanged;

  const RatingWidget({
    Key? key,
    required this.rating,
    this.maxRating = 5,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
    this.onRatingChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final actualActiveColor = activeColor ?? Colors.amber;
    final actualInactiveColor = inactiveColor ?? Colors.grey.shade300;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final isActive = index < rating;
        
        return GestureDetector(
          onTap: onRatingChanged != null ? () => onRatingChanged!(index + 1) : null,
          child: Icon(
            isActive ? Icons.star : Icons.star_border,
            size: size,
            color: isActive ? actualActiveColor : actualInactiveColor,
          ),
        );
      }),
    );
  }
}