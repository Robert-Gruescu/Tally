import 'package:flutter/material.dart';

/// Icons are looked up by key, never reconstructed from a stored code point.
/// `IconData(someInt)` defeats Flutter's icon tree-shaking and forces
/// `--no-tree-shake-icons` on every release build.
const Map<String, IconData> categoryIcons = {
  // expense
  'food': Icons.restaurant_rounded,
  'transport': Icons.directions_bus_rounded,
  'home': Icons.home_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'fun': Icons.movie_rounded,
  'health': Icons.favorite_rounded,
  'subscriptions': Icons.replay_circle_filled_rounded,
  // income
  'salary': Icons.account_balance_wallet_rounded,
  'freelance': Icons.laptop_mac_rounded,
  'gift': Icons.card_giftcard_rounded,
  // shared fallback
  'other': Icons.more_horiz_rounded,
};

IconData iconFor(String key) =>
    categoryIcons[key] ?? categoryIcons['other']!;
