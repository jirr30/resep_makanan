import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class NutritionResult {
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  const NutritionResult({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

class NutritionService {
  static const _apiKey = 'AIzaSyBaE4T7wXrNpKqFBp9MwLkP45H2tOGJISU';

  Future<NutritionResult> estimateFromIngredients({
    required List<String> ingredients,
    required int servings,
  }) async {
    if (ingredients.isEmpty) throw Exception('Bahan tidak boleh kosong');
    if (_apiKey == 'GEMINI_API_KEY_PLACEHOLDER') {
      throw Exception('API key belum dikonfigurasi');
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.1,
      ),
    );

    final ingredientList = ingredients
        .where((i) => i.trim().isNotEmpty)
        .map((i) => '- $i')
        .join('\n');

    final prompt = '''
Kamu adalah ahli gizi profesional. Estimasikan total kandungan nutrisi resep berikut untuk $servings porsi, lalu bagi per porsi.

Bahan-bahan resep:
$ingredientList

Berikan estimasi nutrisi PER PORSI dalam format JSON berikut. Hanya balas dengan JSON murni tanpa penjelasan apapun:
{
  "calories": <integer>,
  "protein": <float satu desimal>,
  "carbs": <float satu desimal>,
  "fat": <float satu desimal>
}

Aturan:
- calories dalam kkal (integer)
- protein, carbs, fat dalam gram (float)
- Gunakan estimasi standar gizi yang wajar
- Jika bahan tidak jelas kuantitasnya, gunakan estimasi porsi normal
''';

    final response = await model.generateContent([Content.text(prompt)]);
    final text = response.text;
    if (text == null || text.isEmpty) throw Exception('Respons AI kosong');

    final cleaned = text.trim().replaceAll('```json', '').replaceAll('```', '').trim();
    final Map<String, dynamic> data = jsonDecode(cleaned);

    return NutritionResult(
      calories: (data['calories'] as num).round(),
      protein: (data['protein'] as num).toDouble(),
      carbs: (data['carbs'] as num).toDouble(),
      fat: (data['fat'] as num).toDouble(),
    );
  }
}
