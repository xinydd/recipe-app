import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe_api_model.dart';

class ApiService {
  static const String baseUrl = 'https://your-api-url.com'; // Replace with your actual API URL
  final http.Client _client = http.Client();

  Map<String, String> _getHeaders(String? token) {
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  // GET: Fetch all recipes
  Future<List<RecipeApiModel>> fetchRecipes() async {
    try {
      final token = await _getToken();
      final response = await _client.get(
        Uri.parse('$baseUrl/recipes'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => RecipeApiModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // GET: Fetch single recipe
  Future<RecipeApiModel> fetchRecipe(String id) async {
    try {
      final token = await _getToken();
      final response = await _client.get(
        Uri.parse('$baseUrl/recipes/$id'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        return RecipeApiModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // POST: Create new recipe
  Future<RecipeApiModel> createRecipe(RecipeApiModel recipe) async {
    try {
      final token = await _getToken();
      final response = await _client.post(
        Uri.parse('$baseUrl/recipes'),
        headers: _getHeaders(token),
        body: jsonEncode(recipe.toJson()),
      );

      if (response.statusCode == 201) {
        return RecipeApiModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // PUT: Update entire recipe
  Future<RecipeApiModel> updateRecipe(RecipeApiModel recipe) async {
    try {
      final token = await _getToken();
      final response = await _client.put(
        Uri.parse('$baseUrl/recipes/${recipe.id}'),
        headers: _getHeaders(token),
        body: jsonEncode(recipe.toJson()),
      );

      if (response.statusCode == 200) {
        return RecipeApiModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // PATCH: Update favorite status
  Future<RecipeApiModel> updateFavoriteStatus(String recipeId, bool isFavorite) async {
    try {
      final token = await _getToken();
      final response = await _client.patch(
        Uri.parse('$baseUrl/recipes/$recipeId/favorite'),
        headers: _getHeaders(token),
        body: jsonEncode({'isFavorite': isFavorite}),
      );

      if (response.statusCode == 200) {
        return RecipeApiModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update favorite: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // DELETE: Delete recipe
  Future<void> deleteRecipe(String id) async {
    try {
      final token = await _getToken();
      final response = await _client.delete(
        Uri.parse('$baseUrl/recipes/$id'),
        headers: _getHeaders(token),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // GET: Search recipes
  Future<List<RecipeApiModel>> searchRecipes(String query) async {
    try {
      final token = await _getToken();
      final response = await _client.get(
        Uri.parse('$baseUrl/recipes/search?q=${Uri.encodeComponent(query)}'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => RecipeApiModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}