import 'package:flutter/material.dart';

import '../core/file_utils.dart';
import '../models/category.dart';

/// A large dashboard stat card.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? scheme.primary).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon,
                      size: 20, color: iconColor ?? scheme.primary),
                ),
                const Spacer(),
                if (subtitle case final sub?)
                  Text(sub, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}

/// Header used above screen sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Friendly empty-state placeholder.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill showing a category icon + label, optionally with a count.
class CategoryChip extends StatelessWidget {
  const CategoryChip(this.category, {super.key, this.count});

  final FileCategory category;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Text(category.icon),
      label: Text(count == null
          ? category.label
          : '${category.label} · $count'),
      backgroundColor: scheme.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}

/// Formats a size inline (convenience for tables).
String humanSize(int bytes) => FileUtils.humanSize(bytes);
