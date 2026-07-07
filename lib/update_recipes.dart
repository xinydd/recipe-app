import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print('📱 Recipe Importer Started');
  print('Waiting for authentication...');
  
  // Listen to auth changes
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      print('✅ User signed in: ${user.email}');
      print('🆔 User ID: ${user.uid}');
      await importRecipesFromGist(user);
      print('🎉 Import complete!');
    } else {
      print('❌ Please sign in to your app first');
      print('Run your main app, sign in, then run this script again');
    }
  });
}

Future<void> importRecipesFromGist(User user) async {
  // Your GitHub Gist raw URL
  const gistUrl = 'https://gist.githubusercontent.com/xinydd/bd6026532626e36a0f52e7b76f8ae106/raw/recipes.json';
  
  print('📡 Fetching recipes from GitHub Gist...');
  print('🔗 URL: $gistUrl');
  
  try {
    // Fetch JSON from Gist
    final response = await http.get(Uri.parse(gistUrl));
    
    if (response.statusCode != 200) {
      print('❌ Failed to fetch Gist: HTTP ${response.statusCode}');
      return;
    }
    
    print('✅ Gist fetched successfully!');
    
    // Decode JSON
    final Map<String, dynamic> jsonData = jsonDecode(response.body);
    final List<dynamic> recipesJson = jsonData['recipes'];
    
    print('📊 Found ${recipesJson.length} recipes in Gist');
    
    final firestore = FirebaseFirestore.instance;
    final recipesCollection = firestore.collection('users').doc(user.uid).collection('recipes');
    
    int successCount = 0;
    int failCount = 0;
    
    for (var recipeJson in recipesJson) {
      try {
        final recipe = recipeJson as Map<String, dynamic>;
        final recipeId = recipe['id'].toString();
        final recipeName = recipe['name'];
        
        // Update userId to current user
        recipe['userId'] = user.uid;
        
        // Ensure ingredients and steps are properly formatted
        if (recipe['ingredients'] != null) {
          final ingredients = recipe['ingredients'] as List;
          // Convert any numbers to strings in ingredients
          for (var ingredient in ingredients) {
            if (ingredient is Map) {
              if (ingredient['quantity'] is num) {
                ingredient['quantity'] = ingredient['quantity'].toString();
              }
              if (ingredient['unit'] is num) {
                ingredient['unit'] = ingredient['unit'].toString();
              }
            }
          }
        }
        
        // Save to Firestore
        await recipesCollection.doc(recipeId).set(recipe);
        
        print('✅ Imported: $recipeName');
        print('   📝 ID: $recipeId');
        print('   🥕 Ingredients: ${recipe['ingredients']?.length ?? 0}');
        print('   📋 Steps: ${recipe['steps']?.length ?? 0}');
        
        successCount++;
      } catch (e) {
        print('❌ Failed to import recipe: $e');
        failCount++;
      }
    }
    
    print('\n📊 ===== IMPORT SUMMARY =====');
    print('✅ Successful: $successCount');
    print('❌ Failed: $failCount');
    print('📁 Collection: users/${user.uid}/recipes');
    
    // Verify import by counting documents
    final snapshot = await recipesCollection.get();
    print('📚 Total recipes in Firestore: ${snapshot.docs.length}');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}