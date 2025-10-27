import 'package:flutter/material.dart';

class SimplePageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;

  const SimplePageIndicator({
    super.key,
    required this.currentPage,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        bool isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 4,
          width: isActive ? 10 : 4,
          decoration: BoxDecoration(
            color: isActive ? Colors.deepPurple : Colors.grey.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }
}
