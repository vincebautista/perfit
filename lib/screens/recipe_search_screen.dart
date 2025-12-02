import 'package:flutter/material.dart';
import 'package:perfit/core/services/recipe_service.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  final EdamamRecipeService _recipeService = EdamamRecipeService();
  final TextEditingController _controller = TextEditingController();

  List<dynamic> _recipes = [];
  bool _loading = false;

  void search() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final results = await _recipeService.searchRecipes(_controller.text);

      if (!mounted) return;
      setState(() => _recipes = results);
    } catch (e) {
      print(e);
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recipe Search")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Search for recipes...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: search, child: const Text("Search")),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        itemCount: _recipes.length,
                        itemBuilder: (context, index) {
                          final recipe = _recipes[index]["recipe"];

                          return ListTile(
                            leading: Image.network(
                              recipe["image"],
                              width: 50,
                              height: 50,
                            ),
                            title: Text(recipe["label"]),
                            subtitle: Text(
                              "${recipe["calories"].toStringAsFixed(0)} calories",
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
