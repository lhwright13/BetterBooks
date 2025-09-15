import 'package:flutter/material.dart';

class LibrarySortMenu extends StatelessWidget {
  final String currentSortBy;
  final bool sortAscending;
  final List<SortOption> sortOptions;
  final Function(String) onSortChanged;
  final VoidCallback onOrderToggle;

  const LibrarySortMenu({
    super.key,
    required this.currentSortBy,
    required this.sortAscending,
    required this.sortOptions,
    required this.onSortChanged,
    required this.onOrderToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.sort,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Sort Library',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onOrderToggle,
                icon: Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: sortAscending ? 'Sort Descending' : 'Sort Ascending',
              ),
            ],
          ),
        ),
        
        const Divider(height: 1),
        
        // Sort options
        ListView.builder(
          shrinkWrap: true,
          itemCount: sortOptions.length,
          itemBuilder: (context, index) {
            final option = sortOptions[index];
            final isSelected = currentSortBy == option.value;
            
            return ListTile(
              leading: Icon(
                option.icon,
                color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              ),
              title: Text(
                option.label,
                style: TextStyle(
                  color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
              ),
              trailing: isSelected 
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
              onTap: () {
                onSortChanged(option.value);
                Navigator.of(context).pop();
              },
            );
          },
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }
}

class SortOption {
  final String label;
  final String value;
  final IconData icon;

  const SortOption({
    required this.label,
    required this.value,
    required this.icon,
  });
}

// Predefined sort options for library
class LibrarySortOptions {
  static const List<SortOption> defaultOptions = [
    SortOption(
      label: 'Title',
      value: 'title',
      icon: Icons.title,
    ),
    SortOption(
      label: 'Author',
      value: 'author',
      icon: Icons.person,
    ),
    SortOption(
      label: 'Date Added',
      value: 'dateAdded',
      icon: Icons.date_range,
    ),
    SortOption(
      label: 'Progress',
      value: 'progress',
      icon: Icons.trending_up,
    ),
    SortOption(
      label: 'Last Played',
      value: 'lastPlayed',
      icon: Icons.play_circle,
    ),
  ];
}