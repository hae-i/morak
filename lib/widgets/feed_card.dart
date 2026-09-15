import 'package:flutter/material.dart';

class FeedCard extends StatelessWidget {
  final Map<String, dynamic> feed;
  final VoidCallback onLike;

  const FeedCard({super.key, required this.feed, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final author = feed['author'] ?? '익명';
    final content = feed['content'] ?? '';
    final imageUrl = feed['image_url'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(author[0])),
                const SizedBox(width: 12),
                Text(author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(imageUrl, width: double.infinity, height: 200, fit: BoxFit.cover),
              ),
              const SizedBox(height: 12),
            ],
            Text(content, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.favorite_border_rounded, color: Colors.redAccent),
                  onPressed: onLike,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}