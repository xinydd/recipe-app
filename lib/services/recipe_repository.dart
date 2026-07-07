import 'dart:async';
import '../models/recipe_api_model.dart';
import 'firestore_service.dart';

class RecipeRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, RecipeApiModel> _cache = {};
  StreamSubscription? _realtimeSubscription;
  
  // Listen to real-time updates
  void listenToRealtimeUpdates(Function(List<RecipeApiModel>) onUpdate) {
    _realtimeSubscription = _firestoreService.watchRecipes().listen((recipes) {
      _updateCache(recipes);
      onUpdate(recipes);
    });
  }

  Future<List<RecipeApiModel>> getRecipes({bool forceRefresh = false}) async {
    final recipes = await _firestoreService.fetchRecipes();
    _updateCache(recipes);
    return recipes;
  }

  Future<RecipeApiModel> createRecipe(RecipeApiModel recipe) async {
    return await _firestoreService.createRecipe(recipe);
  }

  Future<void> toggleFavorite(String recipeId, bool currentFavoriteStatus) async {
    await _firestoreService.updateFavoriteStatus(recipeId, !currentFavoriteStatus);
  }

  Future<void> deleteRecipe(String id) async {
    await _firestoreService.deleteRecipe(id);
  }

  void _updateCache(List<RecipeApiModel> recipes) {
    _cache.clear();
    for (final recipe in recipes) {
      _cache[recipe.id] = recipe;
    }
  }

  void dispose() {
    _realtimeSubscription?.cancel();
  }
}