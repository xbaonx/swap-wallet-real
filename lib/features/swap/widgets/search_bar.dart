import 'package:flutter/material.dart';
import '../swap_screen.dart';

class CryptoSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;
  final SortType sortType;
  final ValueChanged<SortType> onSortChanged;
  final VoidCallback onRefresh;

  const CryptoSearchBar({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.sortType,
    required this.onSortChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search coins...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<SortType>(
            initialValue: sortType,
            onSelected: onSortChanged,
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortType.volume,
                child: Text('Volume 24h'),
              ),
              const PopupMenuItem(
                value: SortType.percent24h,
                child: Text('% Change 24h'),
              ),
              const PopupMenuItem(
                value: SortType.alphabetical,
                child: Text('A → Z'),
              ),
            ],
          ),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }
}
