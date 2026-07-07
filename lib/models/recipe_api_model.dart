class RecipeApiModel {
  final String id;
  final String name;
  final String description;
  final double rating;
  final int reviewCount;
  final String prepTime;
  final String cookTime;
  final String serves;
  final bool isVegetarian;
  final String imagePath;
  bool isFavorite;
  final String userId;
  final List<Map<String, String>> ingredients;
  final List<String> steps;

  RecipeApiModel({
    required this.id,
    required this.name,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.prepTime,
    required this.cookTime,
    required this.serves,
    required this.isVegetarian,
    required this.imagePath,
    required this.isFavorite,
    required this.userId,
    this.ingredients = const [],
    this.steps = const [],
  });

  factory RecipeApiModel.fromJson(Map<String, dynamic> json) {
    // Fix: Convert dynamic maps to String maps
    List<Map<String, String>> parsedIngredients = [];
    if (json['ingredients'] != null) {
      final ingredientsList = json['ingredients'] as List;
      parsedIngredients = ingredientsList.map((item) {
        // Convert each item to Map<String, String>
        return Map<String, String>.from(item);
      }).toList();
    }
    
    // Fix: Convert steps to List<String>
    List<String> parsedSteps = [];
    if (json['steps'] != null) {
      final stepsList = json['steps'] as List;
      parsedSteps = stepsList.map((item) => item.toString()).toList();
    }
    
    return RecipeApiModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] ?? 0,
      prepTime: json['prepTime'] ?? '',
      cookTime: json['cookTime'] ?? '',
      serves: json['serves'] ?? '',
      isVegetarian: json['isVegetarian'] ?? false,
      imagePath: json['imagePath'] ?? '',
      isFavorite: json['isFavorite'] ?? false,
      userId: json['userId'] ?? '',
      ingredients: parsedIngredients,
      steps: parsedSteps,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'rating': rating,
    'reviewCount': reviewCount,
    'prepTime': prepTime,
    'cookTime': cookTime,
    'serves': serves,
    'isVegetarian': isVegetarian,
    'imagePath': imagePath,
    'isFavorite': isFavorite,
    'userId': userId,
    'ingredients': ingredients,
    'steps': steps,
  };
}