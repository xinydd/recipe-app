import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe_api_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  
  CollectionReference get _recipesCollection => 
      _firestore.collection('users').doc(_userId).collection('recipes');
  
  // ============ METHODS NEEDED BY YOUR VIEWMODEL ============
  
  // Get recipes stream (real-time updates) - THIS IS WHAT YOU NEED
  Stream<List<RecipeApiModel>> getRecipesStream() {
    return _recipesCollection.snapshots().map((snapshot) {
      print('📖 Firestore stream received ${snapshot.docs.length} documents');
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return RecipeApiModel.fromJson(data);
      }).toList();
    });
  }
  
  // Add new recipe
  Future<void> addRecipe(RecipeApiModel recipe) async {
    final jsonData = recipe.toJson();
    print('💾 Saving to Firestore: ${jsonData['name']}');
    print('💾 Ingredients: ${jsonData['ingredients']}');
    print('💾 Steps: ${jsonData['steps']}');
    await _recipesCollection.doc(recipe.id).set(jsonData);
    print('💾 Save complete!');
  }
  
  // Toggle favorite
  Future<void> toggleFavorite(String recipeId, bool isFavorite) async {
    await _recipesCollection.doc(recipeId).update({
      'isFavorite': isFavorite,
    });
  }
  
  // ============ ADDITIONAL USEFUL METHODS ============
  
  // Get recipes once (no real-time)
  Future<List<RecipeApiModel>> fetchRecipes() async {
    final snapshot = await _recipesCollection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return RecipeApiModel.fromJson(data);
    }).toList();
  }
  
  // Watch recipes (alias for getRecipesStream)
  Stream<List<RecipeApiModel>> watchRecipes() {
    return getRecipesStream();
  }
  
  // Create recipe (alias for addRecipe)
  Future<RecipeApiModel> createRecipe(RecipeApiModel recipe) async {
    await addRecipe(recipe);
    return recipe;
  }
  
  // Update favorite status
  Future<void> updateFavoriteStatus(String recipeId, bool isFavorite) async {
    await toggleFavorite(recipeId, isFavorite);
  }
  
  // Update entire recipe
  Future<void> updateRecipe(RecipeApiModel recipe) async {
    await _recipesCollection.doc(recipe.id).update(recipe.toJson());
  }
  
  // Delete recipe
  Future<void> deleteRecipe(String recipeId) async {
    await _recipesCollection.doc(recipeId).delete();
  }
  
  // Get a single recipe
  Future<RecipeApiModel?> getRecipe(String recipeId) async {
    final doc = await _recipesCollection.doc(recipeId).get();
    if (doc.exists) {
      return RecipeApiModel.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}