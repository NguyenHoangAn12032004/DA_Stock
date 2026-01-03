import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/alert_entity.dart';
import '../presentation/providers/alert_provider.dart';
import '../theme/app_colors.dart';
import 'add_alert_bottom_sheet.dart';
import '../core/utils/stock_utils.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111418) : const Color(0xFFF6F7F8),
      appBar: AppBar(
        title: const Text('Price Alerts'),
        backgroundColor: isDark ? const Color(0xFF111418) : Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAlertDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("No active alerts", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(alertControllerProvider.future),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return _buildAlertItem(context, ref, alert, isDark);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAlertItem(BuildContext context, WidgetRef ref, AlertEntity alert, bool isDark) {
    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(alertControllerProvider.notifier).deleteAlert(alert.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted alert for ${alert.symbol}'))
        );
      },
      child: Card(
         color: isDark ? const Color(0xFF1A2028) : Colors.white,
         margin: const EdgeInsets.only(bottom: 12),
         elevation: 1,
         child: ListTile(
           leading: CircleAvatar(
             backgroundColor: AppColors.primary.withOpacity(0.1),
             child: const Icon(Icons.notifications_active, color: AppColors.primary),
           ),
           title: Text(
             "${alert.symbol}", 
             style: const TextStyle(fontWeight: FontWeight.bold)
           ),
           subtitle: Text(
             "${alert.condition} ${StockUtils.formatPrice(alert.symbol, alert.value)}",
             style: const TextStyle(fontWeight: FontWeight.w500)
           ),
           trailing: Switch(
             value: alert.isActive,
              onChanged: (val) {
                ref.read(alertControllerProvider.notifier).toggleAlert(alert.id, val);
              },
             activeColor: AppColors.primary,
           ),
         ),
      ),
    );
  }

  void _showAddAlertDialog(BuildContext context) {
    final symbolController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter Stock Symbol"),
        content: TextField(
          controller: symbolController,
          decoration: const InputDecoration(
            labelText: "Symbol (e.g. HPG, VCB)",
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final symbol = symbolController.text.trim().toUpperCase();
              if (symbol.isNotEmpty) {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => AddAlertBottomSheet(symbol: symbol),
                );
              }
            },
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }
}
