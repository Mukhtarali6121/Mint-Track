/// Centralized service for managing category icons
/// Provides flexible icon matching based on category names
class CategoryIconService {
  // Centralized icon mapping with multiple aliases for each icon
  static const Map<String, String> _iconMap = {
    // Food & Dining
    'food': 'assets/images/ic_vector_food.svg',
    'restaurant': 'assets/images/ic_vector_restaurant.svg',
    'dining': 'assets/images/ic_vector_restaurant.svg',
    'food & dining': 'assets/images/ic_vector_restaurant.svg',
    'meal': 'assets/images/ic_vector_food.svg',
    'eat': 'assets/images/ic_vector_food.svg',
    'groceries': 'assets/images/ic_vector_food.svg',
    
    // Drinks
    'drinks': 'assets/images/ic_vector_drink.svg',
    'drink': 'assets/images/ic_vector_drink.svg',
    'wine': 'assets/images/ic_vector_wine_glass.svg',
    'alcohol': 'assets/images/ic_vector_wine_glass.svg',
    'beer': 'assets/images/ic_vector_wine_glass.svg',
    'coffee': 'assets/images/ic_vector_drink.svg',
    'beverage': 'assets/images/ic_vector_drink.svg',
    
    // Transportation
    'transportation': 'assets/images/ic_vector_transportation.svg',
    'transport': 'assets/images/ic_vector_transportation.svg',
    'car': 'assets/images/ic_vector_car.svg',
    'vehicle': 'assets/images/ic_vector_car.svg',
    'automobile': 'assets/images/ic_vector_car.svg',
    'uber': 'assets/images/ic_vector_transportation.svg',
    'taxi': 'assets/images/ic_vector_transportation.svg',
    'gas': 'assets/images/ic_vector_transportation.svg',
    'fuel': 'assets/images/ic_vector_transportation.svg',
    'parking': 'assets/images/ic_vector_transportation.svg',
    
    // Housing
    'housing': 'assets/images/ic_vector_home.svg',
    'home': 'assets/images/ic_vector_home.svg',
    'rent': 'assets/images/ic_vector_home.svg',
    'house': 'assets/images/ic_vector_home.svg',
    'apartment': 'assets/images/ic_vector_home.svg',
    'accommodation': 'assets/images/ic_vector_home.svg',
    
    // Shopping
    'shopping': 'assets/images/ic_vector_shopping_bag.svg',
    'shop': 'assets/images/ic_vector_shopping_bag.svg',
    'buy': 'assets/images/ic_vector_shopping_bag.svg',
    'purchase': 'assets/images/ic_vector_shopping_bag.svg',
    'store': 'assets/images/ic_vector_shopping_bag.svg',
    'retail': 'assets/images/ic_vector_shopping_bag.svg',
    
    // Health & Medical
    'health': 'assets/images/ic_vector_health.svg',
    'medical': 'assets/images/ic_vector_health.svg',
    'doctor': 'assets/images/ic_vector_health.svg',
    'hospital': 'assets/images/ic_vector_health.svg',
    'medicine': 'assets/images/ic_vector_health.svg',
    'pharmacy': 'assets/images/ic_vector_health.svg',
    'clinic': 'assets/images/ic_vector_health.svg',
    
    // Fitness
    'fitness': 'assets/images/ic_vector_fitness.svg',
    'gym': 'assets/images/ic_vector_fitness.svg',
    'workout': 'assets/images/ic_vector_fitness.svg',
    'exercise': 'assets/images/ic_vector_fitness.svg',
    'sports': 'assets/images/ic_vector_fitness.svg',
    'training': 'assets/images/ic_vector_fitness.svg',
    
    // Entertainment
    'entertainment': 'assets/images/ic_vector_entertainment.svg',
    'movie': 'assets/images/ic_vector_entertainment.svg',
    'cinema': 'assets/images/ic_vector_entertainment.svg',
    'music': 'assets/images/ic_vector_entertainment.svg',
    'concert': 'assets/images/ic_vector_entertainment.svg',
    'show': 'assets/images/ic_vector_entertainment.svg',
    
    // Games
    'games': 'assets/images/ic_vector_game.svg',
    'gaming': 'assets/images/ic_vector_game.svg',
    'game': 'assets/images/ic_vector_game.svg',
    'video games': 'assets/images/ic_vector_game.svg',
    
    // Education
    'education': 'assets/images/ic_vector_education.svg',
    'school': 'assets/images/ic_vector_education.svg',
    'learn': 'assets/images/ic_vector_education.svg',
    'study': 'assets/images/ic_vector_education.svg',
    'book': 'assets/images/ic_vector_education.svg',
    'tuition': 'assets/images/ic_vector_education.svg',
    'course': 'assets/images/ic_vector_education.svg',
    
    // Loans
    'loans': 'assets/images/ic_vector_loan.svg',
    'loan': 'assets/images/ic_vector_loan.svg',
    'debt': 'assets/images/ic_vector_loan.svg',
    'borrow': 'assets/images/ic_vector_loan.svg',
    
    // Savings & Investments
    'savings': 'assets/images/ic_vector_investment.svg',
    'save': 'assets/images/ic_vector_investment.svg',
    'investments': 'assets/images/ic_vector_investment.svg',
    'investment': 'assets/images/ic_vector_investment.svg',
    'invest': 'assets/images/ic_vector_investment.svg',
    'stock': 'assets/images/ic_vector_investment.svg',
    'stocks': 'assets/images/ic_vector_investment.svg',
    'trading': 'assets/images/ic_vector_investment.svg',
    
    // Travel
    'travel': 'assets/images/ic_vector_travel.svg',
    'travelling': 'assets/images/ic_vector_travel.svg',
    'trip': 'assets/images/ic_vector_travel.svg',
    'vacation': 'assets/images/ic_vector_travel.svg',
    'holiday': 'assets/images/ic_vector_travel.svg',
    'flight': 'assets/images/ic_vector_travel.svg',
    
    // Gifts
    'gifts': 'assets/images/ic_vector_gifts.svg',
    'gift': 'assets/images/ic_vector_gifts.svg',
    'present': 'assets/images/ic_vector_gifts.svg',
    
    // Donations
    'donations': 'assets/images/ic_vector_donate.svg',
    'donation': 'assets/images/ic_vector_donate.svg',
    'charity': 'assets/images/ic_vector_donate.svg',
    'gifts & donation': 'assets/images/ic_vector_donate.svg',
    
    // Beauty & Personal Care
    'beauty': 'assets/images/ic_vector_beauty.svg',
    'personal care': 'assets/images/ic_vector_beauty.svg',
    'cosmetic': 'assets/images/ic_vector_beauty.svg',
    'salon': 'assets/images/ic_vector_beauty.svg',
    'spa': 'assets/images/ic_vector_beauty.svg',
    'haircut': 'assets/images/ic_vector_beauty.svg',
    
    // Taxes
    'taxes': 'assets/images/ic_vector_tax.svg',
    'tax': 'assets/images/ic_vector_tax.svg',
    
    // Others
    'others': 'assets/images/ic_vector_other.svg',
    'other': 'assets/images/ic_vector_other.svg',
    'misc': 'assets/images/ic_vector_other.svg',
    'miscellaneous': 'assets/images/ic_vector_other.svg',
    
    // Income categories
    'salary': 'assets/images/ic_vector_salary.svg',
    'wage': 'assets/images/ic_vector_salary.svg',
    'income': 'assets/images/ic_vector_salary.svg',
    'work': 'assets/images/ic_vector_salary.svg',
    'job': 'assets/images/ic_vector_salary.svg',
    'employment': 'assets/images/ic_vector_salary.svg',
    
    'business': 'assets/images/ic_vector_business.svg',
    'sell': 'assets/images/ic_vector_business.svg',
    'profit': 'assets/images/ic_vector_business.svg',
    'sold items': 'assets/images/ic_vector_business.svg',
    'sales': 'assets/images/ic_vector_business.svg',
    
    'interest income': 'assets/images/ic_vector_interest_income.svg',
    'interest': 'assets/images/ic_vector_interest_income.svg',
    
    'rental income': 'assets/images/ic_vector_rental_income.svg',
    'rental': 'assets/images/ic_vector_rental_income.svg',
    'rent income': 'assets/images/ic_vector_rental_income.svg',
    
    'bonus': 'assets/images/ic_vector_salary.svg', // Using salary icon as fallback
    'coupons': 'assets/images/ic_vector_other.svg', // Using other icon as fallback
    'petty cash': 'assets/images/ic_vector_other.svg', // Using other icon as fallback
  };

  /// Get icon path for a category name with flexible matching
  /// Supports exact match, keyword matching, and partial matching
  static String getIconPath(String categoryName) {
    if (categoryName.isEmpty) {
      return 'assets/images/ic_vector_other.svg';
    }

    final normalized = categoryName.toLowerCase().trim();
    
    // 1. Try exact match first (case-insensitive)
    if (_iconMap.containsKey(normalized)) {
      return _iconMap[normalized]!;
    }

    // 2. Try removing common separators and matching
    final cleaned = normalized
        .replaceAll(RegExp(r'[&,\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    if (_iconMap.containsKey(cleaned)) {
      return _iconMap[cleaned]!;
    }

    // 3. Try partial matching (e.g., "Food & Dining" -> "food")
    final words = cleaned.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length > 2 && _iconMap.containsKey(word)) {
        return _iconMap[word]!;
      }
    }

    // 4. Try keyword matching (check if any key is contained in the category name)
    for (final entry in _iconMap.entries) {
      if (normalized.contains(entry.key) || entry.key.contains(normalized)) {
        return entry.value;
      }
    }

    // 5. Default fallback
    return 'assets/images/ic_vector_other.svg';
  }

  /// Get icon path by icon name (for icon picker)
  /// Returns null if icon name doesn't exist
  static String? getIconPathByName(String iconName) {
    return _iconMap[iconName.toLowerCase()];
  }

  /// Get all available unique icon paths (for icon picker)
  static List<String> getAvailableIconPaths() {
    return _iconMap.values.toSet().toList()..sort();
  }

  /// Get all available icon names (for icon picker)
  static List<String> getAvailableIconNames() {
    // Return unique icon names (first occurrence of each icon path)
    final seenPaths = <String>{};
    final iconNames = <String>[];
    
    for (final entry in _iconMap.entries) {
      if (!seenPaths.contains(entry.value)) {
        seenPaths.add(entry.value);
        iconNames.add(entry.key);
      }
    }
    
    return iconNames..sort();
  }

  /// Get icon name from icon path (reverse lookup)
  static String? getIconNameFromPath(String iconPath) {
    for (final entry in _iconMap.entries) {
      if (entry.value == iconPath) {
        return entry.key;
      }
    }
    return null;
  }

  /// Check if an icon exists for a given category name
  static bool hasIcon(String categoryName) {
    final path = getIconPath(categoryName);
    return path != 'assets/images/ic_vector_other.svg' || 
           categoryName.toLowerCase() == 'others' ||
           categoryName.toLowerCase() == 'other';
  }
}

