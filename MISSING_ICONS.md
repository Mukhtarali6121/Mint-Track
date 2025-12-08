# Missing Icons Analysis

Based on your `TransactionCategory` enum and current icon assets, here are the icons you should add:

## Currently Available Icons (24 icons)
✅ food, drinks, transportation, housing, shopping, health, fitness, entertainment, games, education, loans, savings/investments, travel, gifts, donations, beauty, taxes, others, salary, business, interest income, rental income, car, restaurant, wine_glass

## Missing Icons Needed

### High Priority (Based on TransactionCategory enum)

1. **Bills & Utilities** (`billsUtilities`)
   - Icon name: `ic_vector_bills.svg` or `ic_vector_utilities.svg`
   - Used for: Electricity, water, gas, internet, phone bills
   - Alternative: Could use receipt/document icon

2. **Insurance** (`insurance`)
   - Icon name: `ic_vector_insurance.svg`
   - Used for: Health insurance, car insurance, life insurance
   - Alternative: Could use shield/security icon

3. **Medical** (`medical`) - Separate from Health
   - Icon name: `ic_vector_medical.svg` or `ic_vector_hospital.svg`
   - Note: Currently using health icon, but you have both categories
   - Alternative: Could reuse health icon

4. **Personal Care** (`personalCare`) - Separate from Beauty
   - Icon name: `ic_vector_personal_care.svg` or `ic_vector_spa.svg`
   - Note: Currently using beauty icon, but you have both categories
   - Alternative: Could reuse beauty icon

5. **Sold Items** (`soldItems`) - Income category
   - Icon name: `ic_vector_sold_items.svg` or `ic_vector_sell.svg`
   - Currently using business icon as fallback
   - Alternative: Could reuse business icon

6. **Coupons** (`coupons`) - Income category
   - Icon name: `ic_vector_coupons.svg` or `ic_vector_discount.svg`
   - Currently using other icon as fallback
   - Alternative: Could use tag/offer icon

7. **Petty Cash** (`pettyCash`) - Income category
   - Icon name: `ic_vector_petty_cash.svg` or `ic_vector_wallet.svg`
   - Currently using other icon as fallback
   - Alternative: Could use wallet icon

8. **Bonus** (`bonus`) - Income category
   - Icon name: `ic_vector_bonus.svg` or `ic_vector_trophy.svg`
   - Currently using salary icon as fallback
   - Alternative: Could use trophy/award icon

### Medium Priority (Common Expense Categories)

9. **Fuel/Gas**
   - Icon name: `ic_vector_fuel.svg` or `ic_vector_gas.svg`
   - Currently using transportation icon
   - Useful for: Gas station expenses

10. **Subscriptions**
    - Icon name: `ic_vector_subscription.svg` or `ic_vector_recurring.svg`
    - Useful for: Netflix, Spotify, gym memberships

11. **Pet Expenses**
    - Icon name: `ic_vector_pet.svg` or `ic_vector_dog.svg`
    - Useful for: Pet food, vet bills

12. **Childcare**
    - Icon name: `ic_vector_childcare.svg` or `ic_vector_baby.svg`
    - Useful for: Babysitting, daycare

13. **Phone/Mobile**
    - Icon name: `ic_vector_phone.svg` or `ic_vector_mobile.svg`
    - Useful for: Phone bills, mobile data

14. **Internet/WiFi**
    - Icon name: `ic_vector_internet.svg` or `ic_vector_wifi.svg`
    - Useful for: Internet bills

15. **Parking**
    - Icon name: `ic_vector_parking.svg`
    - Currently using transportation icon
    - Useful for: Parking fees

### Low Priority (Nice to Have)

16. **Coffee Shop**
    - Icon name: `ic_vector_coffee.svg`
    - Currently using drinks icon
    - Useful for: Coffee shop expenses

17. **Fast Food**
    - Icon name: `ic_vector_fast_food.svg`
    - Currently using food icon
    - Useful for: Fast food restaurants

18. **Groceries**
    - Icon name: `ic_vector_groceries.svg`
    - Currently using food icon
    - Useful for: Supermarket shopping

19. **Clothing**
    - Icon name: `ic_vector_clothing.svg` or `ic_vector_shirt.svg`
    - Currently using shopping icon
    - Useful for: Clothes shopping

20. **Books**
    - Icon name: `ic_vector_book.svg`
    - Currently using education icon
    - Useful for: Book purchases

## Icon Sources Recommendations

1. **Flaticon** (https://www.flaticon.com) - Free SVG icons with attribution
2. **Icons8** (https://icons8.com) - Free icons with various styles
3. **Material Icons** - Convert to SVG if needed
4. **Font Awesome** - Convert to SVG
5. **Custom Design** - Hire a designer for consistent style

## Implementation Notes

- All new icons should follow the naming convention: `ic_vector_[name].svg`
- Icons should be in SVG format for scalability
- Icons should be monochrome/outline style to match existing icons
- Icons should be sized consistently (24x24 or 48x48 viewBox)
- After adding icons, update `CategoryIconService._iconMap` with mappings

## Quick Wins (Use Existing Icons)

You can immediately improve coverage by:
1. Using `ic_vector_car.svg` for "car", "vehicle", "automobile" categories
2. Using `ic_vector_restaurant.svg` for "restaurant", "dining" categories  
3. Using `ic_vector_wine_glass.svg` for "wine", "alcohol", "bar" categories

These are already mapped in the `CategoryIconService`!

