import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_options.dart';
import 'auth_gate.dart';
import 'dart:async';
import 'services/websocket_service.dart';
import 'models/recipe_api_model.dart';
import 'widgets/create_recipe_dialog.dart';
import 'widgets/network_aware_widget.dart';
import 'services/firestore_service.dart';
import 'viewmodels/recipe_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

//ash@123.com
//123456

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseAuth.instance.authStateChanges().listen((User? user) {
    if (user != null) {
      WebSocketService.instance.connect();
    } else {
      WebSocketService.instance.disconnect();
    }
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: NetworkAwareWidget(
        child: const AuthGate(),
        onReconnected: () {
          // Handle reconnection logic here
          print('Reconnected to internet');
        },
      ),
    );
  }
}

// ---------- MyHomePage ----------
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late RecipeViewModel _viewModel;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _viewModel = RecipeViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> importRecipesFromGist() async {
    const gistUrl =
        'https://gist.githubusercontent.com/xinydd/bd6026532626e36a0f52e7b76f8ae106/raw/recipes.json';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📥 Importing recipes from Gist...')),
    );

    try {
      final response = await http.get(Uri.parse(gistUrl));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        final List<dynamic> recipesJson = jsonData['recipes'];

        final userId = FirebaseAuth.instance.currentUser!.uid;
        final firestore = FirebaseFirestore.instance;
        final recipesCollection = firestore
            .collection('users')
            .doc(userId)
            .collection('recipes');

        int count = 0;
        for (var recipeJson in recipesJson) {
          final recipe = recipeJson as Map<String, dynamic>;
          recipe['userId'] = userId;

          // Ensure quantities are strings
          if (recipe['ingredients'] != null) {
            for (var ingredient in recipe['ingredients']) {
              if (ingredient['quantity'] is num) {
                ingredient['quantity'] = ingredient['quantity'].toString();
              }
            }
          }

          await recipesCollection.doc(recipe['id'].toString()).set(recipe);
          count++;
          print('✅ Imported: ${recipe['name']}');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Imported $count recipes successfully!')),
        );

        // Refresh the view
        _viewModel.refreshRecipes();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      print('❌ Import error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;

        if (isWide) {
          // Desktop: persistent side panel + detail
          return Scaffold(
            appBar: _buildAppBar(showMenuIcon: false),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Persistent sidebar
                SizedBox(
                  width: 280,
                  child: Material(
                    elevation: 2,
                    child: RecipeSidebarContent(
                      viewModel: _viewModel,
                      onRecipeSelected: (_) {}, // no close needed on desktop
                    ),
                  ),
                ),
                // Recipe detail
                Expanded(child: _buildRecipeDetail()),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateRecipeDialog(
                    viewModel: _viewModel,
                    onRecipeCreated: () {
                      // Refresh the recipe list
                      _viewModel.refreshRecipes();
                    },
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
          );
        } else {
          // Mobile: drawer + detail
          return Scaffold(
            key: _scaffoldKey,
            appBar: _buildAppBar(showMenuIcon: true),
            drawer: Drawer(
              child: RecipeSidebarContent(
                viewModel: _viewModel,
                onRecipeSelected: (_) {
                  _scaffoldKey.currentState?.closeDrawer();
                },
              ),
            ),
            body: _buildRecipeDetail(),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateRecipeDialog(
                    viewModel: _viewModel,
                    onRecipeCreated: () {
                      _viewModel.refreshRecipes();
                    },
                  ),
                );
              },
              child: const Icon(Icons.add),
            ),
          );
        }
      },
    );
  }

  AppBar _buildAppBar({required bool showMenuIcon}) {
    return AppBar(
      title: Text(widget.title),
      leading: showMenuIcon
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            )
          : null,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.cloud_download),
          tooltip: 'Import Recipes from Gist',
          onPressed: importRecipesFromGist,
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign Out',
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
          },
        ),
      ],
    );
  }

  Widget _buildRecipeDetail() {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image(
                  image: AssetImage(_viewModel.recipe.imagePath),
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 250,
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _viewModel.recipe.imagePath,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                RecipeTabSection(viewModel: _viewModel),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------- Sidebar Content ----------
// Contains ONLY the vegetarian toggle and the recipe list.
class RecipeSidebarContent extends StatelessWidget {
  final RecipeViewModel viewModel;
  final void Function(RecipeModel) onRecipeSelected;

  const RecipeSidebarContent({
    super.key,
    required this.viewModel,
    required this.onRecipeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          color: Colors.green[700],
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: const Text(
            'Recipes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Vegetarian toggle — ONLY filter here
        AnimatedBuilder(
          animation: viewModel,
          builder: (context, _) {
            return SwitchListTile(
              title: const Text(
                'Vegetarian Only',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              secondary: Icon(
                Icons.eco,
                color: viewModel.showVegetarianOnly
                    ? Colors.green
                    : Colors.grey,
              ),
              value: viewModel.showVegetarianOnly,
              activeColor: Colors.green,
              onChanged: (_) => viewModel.toggleVegetarianFilter(),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
            );
          },
        ),
        const Divider(height: 1),
        // Recipe list
        Expanded(
          child: AnimatedBuilder(
            animation: viewModel,
            builder: (context, _) {
              final recipes = viewModel.displayedRecipes;
              if (recipes.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No vegetarian recipes found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }
              return ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final r = recipes[index];
                  final isSelected = r == viewModel.recipe;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.green[50],
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image(
                        image: AssetImage(r.imagePath),
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: Colors.grey[200],
                          child: Icon(
                            r.isVegetarian ? Icons.eco : Icons.restaurant,
                            color: r.isVegetarian
                                ? Colors.green
                                : Colors.orange,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      r.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${r.rating} ★ · ${r.prepTime} prep',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.green[700],
                          )
                        : null,
                    onTap: () {
                      viewModel.selectRecipe(r);
                      onRecipeSelected(r);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------- Tab Section ----------
class RecipeTabSection extends StatefulWidget {
  final RecipeViewModel viewModel;

  const RecipeTabSection({super.key, required this.viewModel});

  @override
  State<RecipeTabSection> createState() => _RecipeTabSectionState();
}

class _RecipeTabSectionState extends State<RecipeTabSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RecipeHeader(viewModel: widget.viewModel),
            TabBar(
              controller: _tabController,
              labelColor: Colors.green[700],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.green[500],
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Ingredients'),
                Tab(text: 'Steps'),
              ],
            ),
            SizedBox(
              height: 350,
              child: TabBarView(
                controller: _tabController,
                children: [
                  OverviewTab(viewModel: widget.viewModel),
                  IngredientsTab(viewModel: widget.viewModel),
                  StepsTab(viewModel: widget.viewModel),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------- Recipe Header ----------
class RecipeHeader extends StatelessWidget {
  final RecipeViewModel viewModel;

  const RecipeHeader({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      viewModel.recipe.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  if (viewModel.recipe.id.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => CreateRecipeDialog(
                                viewModel: viewModel,
                                recipe: viewModel.recipe,
                                onRecipeCreated: () {
                                  viewModel.refreshRecipes();
                                },
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            viewModel.recipe.isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: viewModel.recipe.isFavorite ? Colors.red : null,
                            size: 28,
                          ),
                          onPressed: () => viewModel.toggleFavorite(),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                viewModel.recipe.description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  fontFamily: 'Roboto',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        if (index < viewModel.recipe.rating.floor()) {
                          return Icon(
                            Icons.star,
                            color: Colors.green[500],
                            size: 18,
                          );
                        } else if (index < viewModel.recipe.rating) {
                          return Icon(
                            Icons.star_half,
                            color: Colors.green[500],
                            size: 18,
                          );
                        }
                        return Icon(
                          Icons.star,
                          color: Colors.black38,
                          size: 18,
                        );
                      }),
                    ),
                    Text(
                      '${viewModel.recipe.reviewCount} Reviews',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Roboto',
                        letterSpacing: 0.5,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Overview Tab ----------
class OverviewTab extends StatelessWidget {
  final RecipeViewModel viewModel;

  const OverviewTab({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              DefaultTextStyle.merge(
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Roboto',
                  letterSpacing: 0.5,
                  fontSize: 14,
                  height: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Icon(Icons.kitchen, color: Colors.green[500], size: 20),
                        const Text('PREP:'),
                        Text(viewModel.recipe.prepTime),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(Icons.timer, color: Colors.green[500], size: 20),
                        const Text('COOK:'),
                        Text(viewModel.recipe.cookTime),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(
                          Icons.restaurant,
                          color: Colors.green[500],
                          size: 20,
                        ),
                        const Text('FEEDS:'),
                        Text(viewModel.recipe.serves),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, color: Colors.green[600], size: 20),
                    const SizedBox(width: 16),
                    Text(
                      'Servings: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: () => viewModel.decrementServings(),
                      color: Colors.green[600],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${viewModel.servingSize}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => viewModel.incrementServings(),
                      color: Colors.green[600],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Ingredients Tab ----------
class IngredientsTab extends StatelessWidget {
  final RecipeViewModel viewModel;

  const IngredientsTab({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final ingredients = viewModel.recipe.ingredients;

    if (ingredients.isEmpty) {
      return const Center(child: Text('No ingredients available'));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: ingredients.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ingredient = ingredients[index];
        final baseQuantity = ingredient['baseQuantity'] ?? ingredient['quantity'] ?? '';
        final unit = ingredient['unit'] ?? '';
        final name = ingredient['name'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                Icons.fiber_manual_record,
                size: 6,
                color: Colors.green[500],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$baseQuantity $unit $name'.trim(),
                  style: const TextStyle(fontSize: 13, fontFamily: 'Roboto'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Steps Tab ----------
class StepsTab extends StatelessWidget {
  final RecipeViewModel viewModel;

  const StepsTab({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final steps = viewModel.recipe.steps;

    if (steps.isEmpty) {
      return const Center(child: Text('No steps available'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: steps.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.green[500],
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                steps[index],
                style: const TextStyle(fontSize: 13, fontFamily: 'Roboto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
