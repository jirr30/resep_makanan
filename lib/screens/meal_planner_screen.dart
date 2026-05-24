import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recipe.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import 'detail_screen.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  final _db    = DatabaseService();
  final _notif = NotificationService();
  DateTime _weekStart = _getMonday(DateTime.now());
  Map<String, List<Map<String, dynamic>>> _plans = {};
  List<Recipe> _allRecipes = [];
  bool _loading = true;

  static DateTime _getMonday(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  List<String> get _weekDateStrings =>
      _weekDays.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final planRows = await _db.getMealPlansForWeek(_weekDateStrings);
    final recipes  = await _db.getAllRecipes();
    final grouped  = <String, List<Map<String, dynamic>>>{};
    for (final row in planRows) {
      final date = row['date'] as String;
      grouped.putIfAbsent(date, () => []).add(row);
    }
    if (mounted) setState(() { _plans = grouped; _allRecipes = recipes; _loading = false; });
    await _scheduleNotifications(planRows);
  }

  Future<void> _scheduleNotifications(List<Map<String, dynamic>> planRows) async {
    // Only schedule for today and future dates
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final futurePlans = planRows
        .where((r) => (r['date'] as String).compareTo(today) >= 0)
        .map((r) => {
              'date':     r['date'] as String,
              'mealType': r['mealType'] as String,
              'title':    r['title'] as String,
            })
        .toList();
    await _notif.scheduleMealReminders(futurePlans);
  }

  void _previousWeek() { _weekStart = _weekStart.subtract(const Duration(days: 7)); _load(); }
  void _nextWeek()     { _weekStart = _weekStart.add(const Duration(days: 7)); _load(); }

  Future<void> _addMeal(String date, String mealType) async {
    if (_allRecipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belum ada resep tersimpan')));
      return;
    }
    Recipe? selected;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Pilih Resep untuk $mealType'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: double.maxFinite,
            maxHeight: MediaQuery.of(context).size.height * 0.45,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allRecipes.length,
            itemBuilder: (_, i) {
              final r = _allRecipes[i];
              return ListTile(
                title: Text(r.title, style: const TextStyle(fontSize: 14)),
                subtitle: Text(r.category, style: const TextStyle(fontSize: 12)),
                leading: const Icon(Icons.restaurant, color: AppTheme.primary),
                onTap: () { selected = r; Navigator.pop(context); },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal'))],
      ),
    );
    if (selected != null) {
      await _db.addMealPlan(date, mealType, selected!.id!);
      _load();
    }
  }

  Future<void> _removeMeal(int id) async {
    await _db.deleteMealPlan(id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final now   = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final fmt   = DateFormat('d MMM', 'id_ID');
    final weekRange =
        '${fmt.format(_weekStart)} – ${fmt.format(_weekStart.add(const Duration(days: 6)))}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Planner'),
        actions: [
          IconButton(icon: const Icon(Icons.today), tooltip: 'Minggu ini',
            onPressed: () { _weekStart = _getMonday(DateTime.now()); _load(); }),
        ],
      ),
      body: Column(
        children: [
          // Week navigator
          Container(
            color: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: _previousWeek),
              Expanded(child: Text(weekRange, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: _nextWeek),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: 7,
                    itemBuilder: (_, i) {
                      final day     = _weekDays[i];
                      final dateStr = _weekDateStrings[i];
                      final isToday = dateStr == today;
                      final dayPlans = _plans[dateStr] ?? [];
                      return _DayCard(
                        date: day,
                        isToday: isToday,
                        plans: dayPlans,
                        onAdd: (mealType) => _addMeal(dateStr, mealType),
                        onRemove: _removeMeal,
                        onTapRecipe: (recipeId) async {
                          final recipe = _allRecipes.where((r) => r.id == recipeId).firstOrNull;
                          if (recipe != null && mounted) {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(recipe: recipe)));
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final List<Map<String, dynamic>> plans;
  final void Function(String mealType) onAdd;
  final void Function(int id) onRemove;
  final void Function(int recipeId) onTapRecipe;

  const _DayCard({
    required this.date, required this.isToday,
    required this.plans, required this.onAdd,
    required this.onRemove, required this.onTapRecipe,
  });

  static const _mealTypes = ['Sarapan', 'Makan Siang', 'Makan Malam'];

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE', 'id_ID').format(date);
    final dayDate = DateFormat('d MMM', 'id_ID').format(date);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isToday ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Text(dayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isToday ? Colors.white : AppTheme.textOn(context))),
              const Spacer(),
              Text(dayDate, style: TextStyle(color: isToday ? Colors.white70 : AppTheme.textSubOn(context), fontSize: 13)),
              if (isToday) ...[const SizedBox(width: 8), Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Text('Hari Ini', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              )],
            ]),
          ),
          // Meal slots
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: _mealTypes.map((mealType) {
                final meal = plans.where((p) => p['mealType'] == mealType).firstOrNull;
                return _MealSlot(
                  mealType: mealType,
                  meal: meal,
                  onAdd: () => onAdd(mealType),
                  onRemove: meal != null ? () => onRemove(meal['id'] as int) : null,
                  onTap: meal != null ? () => onTapRecipe(meal['recipeId'] as int) : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSlot extends StatelessWidget {
  final String mealType;
  final Map<String, dynamic>? meal;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _MealSlot({required this.mealType, this.meal, required this.onAdd, this.onRemove, this.onTap});

  IconData get _icon => mealType == 'Sarapan' ? Icons.wb_sunny : mealType == 'Makan Siang' ? Icons.lunch_dining : Icons.nights_stay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(_icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: Text(mealType, style: TextStyle(fontSize: 13, color: AppTheme.textSubOn(context)))),
        Expanded(
          child: meal == null
              ? GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.add, size: 16, color: AppTheme.primary),
                      SizedBox(width: 4),
                      Text('Tambah resep', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                    ]),
                  ),
                )
              : GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.restaurant, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(meal!['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      if (onRemove != null) GestureDetector(
                        onTap: onRemove,
                        child: Icon(Icons.close, size: 16, color: AppTheme.textSubOn(context)),
                      ),
                    ]),
                  ),
                ),
        ),
      ]),
    );
  }
}
