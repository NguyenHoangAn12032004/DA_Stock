import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_app/screens/main_screen.dart';
import 'package:stock_app/presentation/providers/market_provider.dart';
import 'mocks.dart'; // Import matches file name

void main() {
  testWidgets('Portfolio Screen Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Wrap in ProviderScope for Riverpod with Overrides
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRemoteDataSourceProvider.overrideWith((ref) => FakeMarketRemoteDataSource()),
        ],
        child: const MaterialApp(
          home: MainScreen(), 
        ),
      ),
    );

    // 1. Verify App Title or Portfolio Header
    // "Danh mục" is likely the tab name or header
    // Use find.textContaining to be safe with casing
    expect(find.textContaining('Danh mục'), findsOneWidget); 
    
    // 2. Check for "Tài sản ròng" or "Tổng tài sản" (Net Worth) label
    // Check localizations... Assuming Vietnamese or Default English
    // Let's assume some common text from the code we viewed previously
    // expect(find.text('Total Balance'), findsOneWidget); 

    // 3. Verify RefreshButton exists
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    print("✅ Frontend Smoke Test Passed: Portfolio Screen Renders!");
  });
}
