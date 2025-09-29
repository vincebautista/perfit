import 'package:flutter/material.dart';

class BasketProvider extends ChangeNotifier {
  final List<String> _selectedFoods = [];

  List<String> get selectedFoods => List.unmodifiable(_selectedFoods);

  void add(String food) {
    if (!_selectedFoods.contains(food)) {
      _selectedFoods.add(food);
      notifyListeners();
    }
  }

  void remove(String food) {
    _selectedFoods.remove(food);
    notifyListeners();
  }

  void clear() {
    _selectedFoods.clear();
    notifyListeners();
  }
}
