import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../features/profile/data/profile_posts_api.dart';
import '../../app/design_tokens.dart';
import '../../core/formatting/relative_time.dart';

/// Real profile post card (caption and/or photo).
class CgProfilePostCard extends StatelessWidget {
  const CgProfilePostCard({
    super.key,
    required this.post,
    this.onDelete,
  });

  final ProfilePostItem post;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final hasBody = post.body != null && post.body!.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: CgColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CgColors.gray200),
        boxShadow: CgShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: CgColors.gray100),
                errorWidget: (_, __, ___) => Container(
                  color: CgColors.gray100,
                  child: const Icon(Icons.broken_image_outlined, color: CgColors.gray400),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasBody)
                        Text(
                          post.body!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: CgColors.gray700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (hasBody) const SizedBox(height: 6),
                      Text(
                        formatRelativeTime(post.createdAt),
                        style: const TextStyle(fontSize: 12, color: CgColors.gray500, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: CgColors.gray500),
                    tooltip: 'Delete post',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
