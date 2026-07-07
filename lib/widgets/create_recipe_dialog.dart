import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../viewmodels/recipe_viewmodel.dart';

class CreateRecipeDialog extends StatefulWidget {
  final RecipeViewModel viewModel;
  final VoidCallback onRecipeCreated;
  final RecipeModel? recipe;

  const CreateRecipeDialog({
    super.key,
    required this.viewModel,
    required this.onRecipeCreated,
    this.recipe,
  });

  @override
  State<CreateRecipeDialog> createState() => _CreateRecipeDialogState();
}

class _CreateRecipeDialogState extends State<CreateRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servesController = TextEditingController();
  
  // Ingredients list
  final List<Map<String, String>> _ingredients = [];
  final List<Map<String, TextEditingController>> _ingredientControllers = [];
  
  // Steps list
  final List<String> _steps = [];
  final List<TextEditingController> _stepControllers = [];
  
  bool _isVegetarian = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.recipe != null) {
      final r = widget.recipe!;
      _nameController.text = r.name;
      _descriptionController.text = r.description;
      _prepTimeController.text = r.prepTime;
      _cookTimeController.text = r.cookTime;
      _servesController.text = r.serves;
      _isVegetarian = r.isVegetarian;
      
      if (r.ingredients.isNotEmpty) {
        for (var ingredient in r.ingredients) {
          _addIngredient(Map<String, String>.from(ingredient));
        }
      } else {
        _addIngredient();
      }
      if (r.steps.isNotEmpty) {
        for (var step in r.steps) {
          _addStep(step);
        }
      } else {
        _addStep();
      }
    } else {
      _addIngredient();
      _addStep();
    }
  }

  void _addIngredient([Map<String, String>? initialData]) {
    setState(() {
      final ingredient = {
        'name': initialData?['name'] ?? '',
        'baseQuantity': initialData?['baseQuantity'] ?? initialData?['quantity'] ?? '',
        'unit': initialData?['unit'] ?? '',
      };
      _ingredients.add(ingredient);
      _ingredientControllers.add({
        'name': TextEditingController(text: ingredient['name']),
        'baseQuantity': TextEditingController(text: ingredient['baseQuantity']),
        'unit': TextEditingController(text: ingredient['unit']),
      });
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
      final controllers = _ingredientControllers.removeAt(index);
      controllers['name']?.dispose();
      controllers['baseQuantity']?.dispose();
      controllers['unit']?.dispose();
    });
  }

  void _updateIngredient(int index, String field, String value) {
    _ingredients[index][field] = value;
  }

  void _addStep([String? initialData]) {
    setState(() {
      _steps.add(initialData ?? '');
      _stepControllers.add(TextEditingController(text: initialData ?? ''));
    });
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
      _stepControllers.removeAt(index).dispose();
    });
  }

  void _updateStep(int index, String value) {
    _steps[index] = value;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 700,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(widget.recipe != null ? Icons.edit : Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    widget.recipe != null ? 'Edit Recipe' : 'Create New Recipe',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Basic Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Recipe Name *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.restaurant),
                              ),
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.description),
                              ),
                              maxLines: 3,
                              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _prepTimeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Prep Time *',
                                      hintText: 'e.g., 15 min',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.timer),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cookTimeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Cook Time *',
                                      hintText: 'e.g., 30 min',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.kitchen),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _servesController,
                                    decoration: const InputDecoration(
                                      labelText: 'Serves *',
                                      hintText: 'e.g., 4',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.people),
                                    ),
                                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SwitchListTile(
                                    title: const Text('Vegetarian'),
                                    value: _isVegetarian,
                                    onChanged: (value) {
                                      setState(() {
                                        _isVegetarian = value;
                                      });
                                    },
                                    secondary: Icon(
                                      _isVegetarian ? Icons.eco : Icons.restaurant,
                                      color: _isVegetarian ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Ingredients Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.food_bank, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text(
                                  'Ingredients',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _addIngredient,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Ingredient'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Ingredients List
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _ingredients.length,
                              itemBuilder: (context, index) {
                                final ingredient = _ingredients[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.blue[100],
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: TextField(
                                            controller: _ingredientControllers[index]['name'],
                                            decoration: const InputDecoration(
                                              labelText: 'Ingredient',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            onChanged: (value) => _updateIngredient(index, 'name', value),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 1,
                                          child: TextField(
                                            controller: _ingredientControllers[index]['baseQuantity'],
                                            decoration: const InputDecoration(
                                              labelText: 'Qty',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            onChanged: (value) => _updateIngredient(index, 'baseQuantity', value),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 1,
                                          child: TextField(
                                            controller: _ingredientControllers[index]['unit'],
                                            decoration: const InputDecoration(
                                              labelText: 'Unit',
                                              border: OutlineInputBorder(),
                                              isDense: true,
                                            ),
                                            onChanged: (value) => _updateIngredient(index, 'unit', value),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () => _removeIngredient(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Steps Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.format_list_numbered, color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text(
                                  'Steps',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _addStep,
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Step'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Steps List
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _steps.length,
                              itemBuilder: (context, index) {
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: Colors.orange[100],
                                            borderRadius: BorderRadius.circular(15),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: _stepControllers[index],
                                            decoration: const InputDecoration(
                                              hintText: 'Enter step description',
                                              border: InputBorder.none,
                                            ),
                                            maxLines: 3,
                                            onChanged: (value) => _updateStep(index, value),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () => _removeStep(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _createRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.recipe != null ? 'Update Recipe' : 'Create Recipe'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Validate ingredients
    final validIngredients = _ingredients.where((i) => i['name']?.isNotEmpty == true).toList();
    if (validIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one ingredient')),
      );
      return;
    }
    
    // Validate steps
    final validSteps = _steps.where((s) => s.isNotEmpty).toList();
    if (validSteps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one step')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      if (widget.recipe != null) {
        await widget.viewModel.updateRecipe(
          id: widget.recipe!.id,
          name: _nameController.text,
          description: _descriptionController.text,
          prepTime: _prepTimeController.text,
          cookTime: _cookTimeController.text,
          serves: _servesController.text,
          isVegetarian: _isVegetarian,
          ingredients: validIngredients,
          steps: validSteps,
          isFavorite: widget.recipe!.isFavorite,
        );
      } else {
        await widget.viewModel.createRecipe(
          name: _nameController.text,
          description: _descriptionController.text,
          prepTime: _prepTimeController.text,
          cookTime: _cookTimeController.text,
          serves: _servesController.text,
          isVegetarian: _isVegetarian,
          ingredients: validIngredients,
          steps: validSteps,
        );
      }
      
      if (mounted) {
        Navigator.pop(context);
        widget.onRecipeCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.recipe != null ? 'Recipe updated successfully!' : 'Recipe created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servesController.dispose();
    for (var controllers in _ingredientControllers) {
      controllers['name']?.dispose();
      controllers['baseQuantity']?.dispose();
      controllers['unit']?.dispose();
    }
    for (var controller in _stepControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}