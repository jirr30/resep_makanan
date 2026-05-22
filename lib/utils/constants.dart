class AppConstants {
  // Format angka besar: 1200 → "1.2rb", 1500000 → "1.5jt"
  static String formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}jt';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1)}rb';
    return '$n';
  }

  static const List<String> categories = [
    'Semua',
    'Makanan Utama',
    'Sup',
    'Salad',
    'Dessert',
    'Sarapan',
    'Camilan',
    'Minuman',
  ];

  static const List<String> difficulties = ['Mudah', 'Sedang', 'Sulit'];
}
