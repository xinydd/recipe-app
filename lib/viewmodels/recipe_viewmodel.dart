import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/recipe_api_model.dart';

// ---------- Recipe Model ----------
class RecipeModel {
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
  final List<Map<String, String>> ingredients;
  final List<String> steps;

  RecipeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.rating,
    required this.reviewCount,
    required this.prepTime,
    required this.cookTime,
    required this.serves,
    required this.imagePath,
    this.isVegetarian = false,
    this.isFavorite = false,
    this.ingredients = const [],
    this.steps = const [],
  });
}

// ---------- Ingredient Model ----------
class IngredientModel {
  final String name;
  final double baseQuantity;
  final String unit;

  IngredientModel({
    required this.name,
    required this.baseQuantity,
    required this.unit,
  });

  String getFormattedQuantity(int servings) {
    double scaledQuantity = baseQuantity * servings;
    if (scaledQuantity == scaledQuantity.roundToDouble()) {
      return '${scaledQuantity.round()} $unit';
    }
    return '${scaledQuantity.toStringAsFixed(1)} $unit';
  }
}

// ---------- Recipe ViewModel ----------
class RecipeViewModel extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  List<RecipeModel> _allRecipes = [];
  bool _showVegetarianOnly = false;
  int _selectedRecipeIndex = 0;
  int _servingSize = 4;
  final List<List<IngredientModel>> _allIngredients = [];
  StreamSubscription? _firestoreSubscription;

  RecipeViewModel() {
    print('📱 RecipeViewModel initialized');

    // Listen to real-time Firestore updates
    _firestoreSubscription = _firestore.getRecipesStream().listen((apiRecipes) {
      print('🔥 Firestore returned ${apiRecipes.length} recipes');

      if (apiRecipes.isNotEmpty) {
        _allRecipes = apiRecipes
            .map(
              (apiRecipe) => RecipeModel(
                id: apiRecipe.id,
                name: apiRecipe.name,
                description: apiRecipe.description,
                rating: apiRecipe.rating,
                reviewCount: apiRecipe.reviewCount,
                prepTime: apiRecipe.prepTime,
                cookTime: apiRecipe.cookTime,
                serves: apiRecipe.serves,
                isVegetarian: apiRecipe.isVegetarian,
                imagePath: apiRecipe.imagePath,
                isFavorite: apiRecipe.isFavorite,
                ingredients: apiRecipe.ingredients,
                steps: apiRecipe.steps,
              ),
            )
            .toList();
        notifyListeners();
      } else {
        print('⚠️ No recipes found in Firestore');
      }
    });

    // Initialize ingredients (keep your existing ingredients data)
    _allIngredients.addAll([
      // Filipino Spaghetti
      [
        IngredientModel(name: 'spaghetti', baseQuantity: 125, unit: 'g'),
        IngredientModel(
          name: 'ground pork or beef',
          baseQuantity: 75,
          unit: 'g',
        ),
        IngredientModel(name: 'banana ketchup', baseQuantity: 60, unit: 'ml'),
        IngredientModel(name: 'tomato sauce', baseQuantity: 60, unit: 'ml'),
        IngredientModel(name: 'hotdogs', baseQuantity: 0.75, unit: 'pcs'),
        IngredientModel(name: 'onion, minced', baseQuantity: 0.25, unit: 'pc'),
        IngredientModel(
          name: 'garlic cloves, minced',
          baseQuantity: 1,
          unit: 'clove',
        ),
        IngredientModel(
          name: 'Salt, pepper & sugar',
          baseQuantity: 1,
          unit: 'to taste',
        ),
        IngredientModel(name: 'Grated cheese', baseQuantity: 15, unit: 'g'),
      ],
      // Vegetable Stir Fry
      [
        IngredientModel(name: 'mixed vegetables', baseQuantity: 200, unit: 'g'),
        IngredientModel(name: 'soy sauce', baseQuantity: 30, unit: 'ml'),
        IngredientModel(name: 'sesame oil', baseQuantity: 10, unit: 'ml'),
        IngredientModel(name: 'garlic cloves', baseQuantity: 2, unit: 'cloves'),
        IngredientModel(name: 'ginger, grated', baseQuantity: 5, unit: 'g'),
        IngredientModel(name: 'cornstarch', baseQuantity: 5, unit: 'g'),
      ],
      // Mushroom Risotto
      [
        IngredientModel(name: 'arborio rice', baseQuantity: 90, unit: 'g'),
        IngredientModel(
          name: 'mushrooms, sliced',
          baseQuantity: 100,
          unit: 'g',
        ),
        IngredientModel(name: 'vegetable broth', baseQuantity: 300, unit: 'ml'),
        IngredientModel(name: 'parmesan cheese', baseQuantity: 25, unit: 'g'),
        IngredientModel(name: 'butter', baseQuantity: 15, unit: 'g'),
        IngredientModel(name: 'onion, diced', baseQuantity: 0.5, unit: 'pc'),
        IngredientModel(name: 'dry white wine', baseQuantity: 60, unit: 'ml'),
      ],
      // Chicken Adobo
      [
        IngredientModel(name: 'chicken pieces', baseQuantity: 250, unit: 'g'),
        IngredientModel(name: 'soy sauce', baseQuantity: 60, unit: 'ml'),
        IngredientModel(name: 'white vinegar', baseQuantity: 60, unit: 'ml'),
        IngredientModel(
          name: 'garlic cloves, crushed',
          baseQuantity: 3,
          unit: 'cloves',
        ),
        IngredientModel(name: 'bay leaves', baseQuantity: 1, unit: 'leaf'),
        IngredientModel(
          name: 'black peppercorns',
          baseQuantity: 0.5,
          unit: 'tsp',
        ),
        IngredientModel(name: 'water', baseQuantity: 125, unit: 'ml'),
      ],
    ]);
  }

  Future<void> createRecipe({
    required String name,
    required String description,
    required String prepTime,
    required String cookTime,
    required String serves,
    required bool isVegetarian,
    required List<Map<String, String>> ingredients,
    required List<String> steps,
  }) async {
    print('📝 ===== CREATING RECIPE =====');
    print('📝 Name: $name');
    print('📝 Ingredients count: ${ingredients.length}');
    print('📝 Ingredients data: $ingredients');
    print('📝 Steps count: ${steps.length}');
    print('📝 Steps data: $steps');

    final newRecipe = RecipeApiModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      rating: 0,
      reviewCount: 0,
      prepTime: prepTime,
      cookTime: cookTime,
      serves: serves,
      isVegetarian: isVegetarian,
      imagePath: 'images/default.jpg',
      isFavorite: false,
      userId: FirebaseAuth.instance.currentUser!.uid,
      ingredients: ingredients,
      steps: steps,
    );

    print(
      '📝 RecipeApiModel created with ingredients: ${newRecipe.ingredients.length}',
    );
    print('📝 RecipeApiModel created with steps: ${newRecipe.steps.length}');

    await _firestore.addRecipe(newRecipe);
    print('📝 ===== RECIPE SAVED =====');
  }

  Future<void> updateRecipe({
    required String id,
    required String name,
    required String description,
    required String prepTime,
    required String cookTime,
    required String serves,
    required bool isVegetarian,
    required List<Map<String, String>> ingredients,
    required List<String> steps,
    required bool isFavorite,
  }) async {
    final existingIndex = _allRecipes.indexWhere((r) => r.id == id);
    final existingRecipe = existingIndex != -1 ? _allRecipes[existingIndex] : null;
    
    final updatedRecipe = RecipeApiModel(
      id: id,
      name: name,
      description: description,
      rating: existingRecipe?.rating ?? 0,
      reviewCount: existingRecipe?.reviewCount ?? 0,
      prepTime: prepTime,
      cookTime: cookTime,
      serves: serves,
      isVegetarian: isVegetarian,
      imagePath: existingRecipe?.imagePath ?? 'images/default.jpg',
      isFavorite: isFavorite,
      userId: FirebaseAuth.instance.currentUser!.uid,
      ingredients: ingredients,
      steps: steps,
    );

    await _firestore.updateRecipe(updatedRecipe);
  }

  RecipeModel get recipe => _allRecipes.isNotEmpty
      ? _allRecipes[_selectedRecipeIndex]
      : (_allRecipes.isEmpty
            ? RecipeModel(
                id: '',
                name: '',
                description: '',
                rating: 0,
                reviewCount: 0,
                prepTime: '',
                cookTime: '',
                serves: '',
                imagePath: '',
              )
            : _allRecipes.first);

  int get selectedRecipeIndex => _selectedRecipeIndex;
  int get servingSize => _servingSize;
  bool get showVegetarianOnly => _showVegetarianOnly;

  List<RecipeModel> get displayedRecipes {
    if (_showVegetarianOnly) {
      return _allRecipes.where((r) => r.isVegetarian).toList();
    }
    return _allRecipes;
  }

  List<Map<String, String>> get scaledIngredients {
    if (_allIngredients.isEmpty ||
        _selectedRecipeIndex >= _allIngredients.length) {
      return [];
    }
    final ingredients = _allIngredients[_selectedRecipeIndex];
    return ingredients.map((ingredient) {
      return {
        'name': ingredient.name,
        'baseQuantity': ingredient.getFormattedQuantity(_servingSize),
      };
    }).toList();
  }

  void selectRecipe(RecipeModel selected) {
    final index = _allRecipes.indexOf(selected);
    if (index != -1) {
      _selectedRecipeIndex = index;
      _servingSize = 4;
      notifyListeners();
    }
  }

  void toggleFavorite() {
    if (_allRecipes.isEmpty) return;
    final currentRecipe = recipe;
    final newFavoriteStatus = !currentRecipe.isFavorite;
    _firestore.toggleFavorite(currentRecipe.id, newFavoriteStatus);
  }

  void incrementServings() {
    if (_servingSize < 12) {
      _servingSize++;
      notifyListeners();
    }
  }

  void decrementServings() {
    if (_servingSize > 1) {
      _servingSize--;
      notifyListeners();
    }
  }

  void toggleVegetarianFilter() {
    _showVegetarianOnly = !_showVegetarianOnly;
    if (_showVegetarianOnly && _allRecipes.isNotEmpty && !recipe.isVegetarian) {
      final vegRecipes = _allRecipes.where((r) => r.isVegetarian).toList();
      if (vegRecipes.isNotEmpty) {
        selectRecipe(vegRecipes.first);
        return;
      }
    }
    notifyListeners();
  }

  void toggleRecipeFavorite(RecipeModel r) {
    r.isFavorite = !r.isFavorite;
    _firestore.toggleFavorite(r.id, r.isFavorite);
  }

  void refreshRecipes() {
    notifyListeners();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    super.dispose();
  }
}
