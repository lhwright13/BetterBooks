import 'package:flutter/material.dart';

class LibraryFilterChips extends StatelessWidget {
  final List<FilterChipData> filters;
  final Function(String) onFilterTap;

  const LibraryFilterChips({
    super.key,
    required this.filters,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) => 
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      filter.icon,
                      size: 16,
                      color: filter.isSelected 
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(filter.label),
                  ],
                ),
                selected: filter.isSelected,
                onSelected: (selected) => onFilterTap(filter.value),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                checkmarkColor: Theme.of(context).colorScheme.onSecondaryContainer,
                side: BorderSide(
                  color: filter.isSelected 
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ).toList(),
        ),
      ),
    );
  }
}

class FilterChipData {
  final String label;
  final String value;
  final IconData icon;
  final bool isSelected;

  const FilterChipData({
    required this.label,
    required this.value,
    required this.icon,
    required this.isSelected,
  });
}