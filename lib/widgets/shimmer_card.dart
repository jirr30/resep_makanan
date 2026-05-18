import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base    = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300;
    final highlight = isDark ? const Color(0xFF3A3A3A) : Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 180,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, width: double.infinity, decoration: _box),
                  const SizedBox(height: 8),
                  Container(height: 14, width: 200, decoration: _box),
                  const SizedBox(height: 12),
                  Row(children: [
                    Container(height: 28, width: 80, decoration: _roundBox),
                    const SizedBox(width: 8),
                    Container(height: 28, width: 80, decoration: _roundBox),
                    const SizedBox(width: 8),
                    Container(height: 28, width: 80, decoration: _roundBox),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration get _box => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6));
  BoxDecoration get _roundBox => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20));
}

class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => const ShimmerCard(),
    );
  }
}
