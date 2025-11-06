# Interactive Charts Implementation

This implementation adds comprehensive chart functionality to the Flutter expense tracker app using the `fl_chart` library.

## Features Implemented

### 🥧 Pie Chart - Expense/Income Breakdown
- **Purpose**: Shows how total expenses or income are divided among categories
- **Features**:
  - Color-coded slices for each category
  - Center text showing total amount
  - Tap on slice to show detailed tooltip with category name, percentage, and exact amount
  - Toggle switch to switch between expense and income views
  - Smooth entry animation
  - Empty state handling

### 📊 Bar Chart - Monthly Income vs Expense
- **Purpose**: Compares income and expense totals across months in a year
- **Features**:
  - Side-by-side bars for income (green) and expense (red)
  - X-axis shows month abbreviations (Jan, Feb, Mar...)
  - Y-axis auto-adjusts to amount scale
  - Tooltip on tap showing income, expense, and balance
  - Rounded bar corners for modern UI
  - Animated bars from bottom-up
  - Empty state handling

### 📈 Line Chart - Trend Analysis
- **Purpose**: Shows income or expense variation over time
- **Features**:
  - Smooth curved line chart with dots for data points
  - Toggle between daily, weekly, and monthly views
  - Toggle between income and expense trends
  - Gradient fill under the line
  - Tooltip on hover/tap showing date and amount
  - Animated line drawing effect
  - Empty state handling

## File Structure

```
lib/
├── services/
│   └── chart_data_service.dart          # Data aggregation service
├── widgets/
│   ├── pie_chart_widget.dart            # Pie chart implementation
│   ├── bar_chart_widget.dart            # Bar chart implementation
│   └── line_chart_widget.dart           # Line chart implementation
└── presentation/screens/
    └── charts_screen.dart               # Main charts screen with tabs
```

## Key Components

### ChartDataService
- Aggregates transaction data for different chart types
- Provides methods for:
  - Expense/income breakdown by category
  - Monthly income vs expense data
  - Trend data for line charts
  - Total amount calculations
  - Balance calculations

### Chart Widgets
Each chart widget includes:
- Responsive design with proper sizing
- Smooth animations and transitions
- Interactive tooltips and touch handling
- Empty state handling
- Consistent color palette
- Modern UI with shadows and rounded corners

### ChartsScreen
- Tab-based navigation between chart types
- Month/year selection controls
- Integration with TransactionProvider
- Responsive layout

## Navigation Integration

The charts are integrated into the main app navigation:
- Added as a third tab in the bottom navigation (Analytics)
- Accessible via route `/charts`
- Seamlessly integrated with existing transaction data

## Color Palette

Consistent color scheme across all charts:
- **Income**: Green shades (`Colors.green[400]`)
- **Expense**: Red shades (`Colors.red[400]`)
- **Categories**: 12 predefined colors for pie chart slices
- **Background**: White with subtle shadows
- **Text**: Black87 for primary text, Grey600 for secondary

## Usage

1. **Navigate to Analytics tab** in the bottom navigation
2. **Select chart type** using the tab bar (Breakdown, Monthly, Trend)
3. **Adjust time period** using the month/year selectors
4. **Interact with charts** by tapping on elements for detailed information
5. **Toggle views** where applicable (expense/income, daily/weekly/monthly)

## Dependencies

- `fl_chart: ^0.69.0` - Chart library (already included in pubspec.yaml)
- `provider` - State management (already included)
- `flutter/material.dart` - UI components

## Future Enhancements

- Export charts as images
- More chart types (donut, area, scatter)
- Custom date range selection
- Chart data export to CSV
- Advanced filtering options
- Chart customization settings
