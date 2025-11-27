import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonListLoader extends StatelessWidget {
  const SkeletonListLoader({super.key});

  @override
  Widget build(BuildContext context) {
    // Bestemmer base-farver baseret på om vi er i dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: 6, // Vis 6 "fake" elementer
      itemBuilder: (ctx, i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 80, // Samme højde som vores rigtige kort ca.
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Fake farve-stribe
                  Container(
                    width: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Fake tekst indhold
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16.0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(right: 100), // Gør titlen kortere
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 12.0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(right: 40), // Gør undertitlen lidt længere
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}