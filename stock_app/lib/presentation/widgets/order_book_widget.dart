import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/order_book_entity.dart';
import '../../presentation/providers/market_provider.dart';
import '../../core/utils/currency_helper.dart';
import '../../presentation/providers/settings_provider.dart'; // Add Settings Provider

// --- Provider ---
// We need a provider that fetches OrderBook for a specific Symbol
// and maybe refreshes it periodically (polling for MVP).

import '../../services/socket_service.dart';

final orderBookProvider = StreamProvider.family<OrderBookEntity, String>((ref, symbol) {
  final socketService = SocketService();
  final controller = StreamController<OrderBookEntity>();

  // Initial Fetch (HTTP) to show data immediately
  ref.read(marketRepositoryProvider).getOrderBook(symbol).then((result) {
    if (!controller.isClosed) {
      result.fold(
        (l) => controller.add(OrderBookEntity.empty),
        (r) => controller.add(r),
      );
    }
  });

  // Connect Socket
  socketService.connect();

  final sub = socketService.stream?.listen((message) {
    if (controller.isClosed) return;
    
    final data = socketService.parseData(message);
    if (data != null && data['type'] == 'ORDER_BOOK' && data['symbol'] == symbol) {
      // Map JSON to OrderBookEntity
      try {
        final rawData = data['data'];
        final bids = (rawData['bids'] as List)
            .map((e) => OrderBookEntry(price: (e['price'] as num).toDouble(), quantity: (e['quantity'] as num).toInt()))
            .toList();
        final asks = (rawData['asks'] as List)
            .map((e) => OrderBookEntry(price: (e['price'] as num).toDouble(), quantity: (e['quantity'] as num).toInt()))
            .toList();
            
        controller.add(OrderBookEntity(symbol: symbol, bids: bids, asks: asks));
      } catch (e) {
        print("Error parsing OrderBook socket msg: $e");
      }
    }
  });

  ref.onDispose(() {
    sub?.cancel();
    socketService.disconnect();
    controller.close();
  });

  return controller.stream;
});

class OrderBookWidget extends ConsumerWidget {
  final String symbol;

  const OrderBookWidget({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(orderBookProvider(symbol));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sổ Lệnh (Order Book)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            bookAsync.when(
              data: (book) => _buildBook(context, book, ref), // Pass ref
              error: (err, stack) => Center(child: Text('Lỗi tải sổ lệnh: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBook(BuildContext context, OrderBookEntity book, WidgetRef ref) {
    if (book.bids.isEmpty && book.asks.isEmpty) {
      return const Center(child: Text("Sổ lệnh trống", style: TextStyle(color: Colors.grey)));
    }

    // Determine max vol for visual depth bars
    int maxVol = 1;
    for (var b in book.bids) if (b.quantity > maxVol) maxVol = b.quantity;
    for (var a in book.asks) if (a.quantity > maxVol) maxVol = a.quantity;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BIDS (Buy) - Green
        Expanded(
          child: Column(
            children: [
              const Text("MUA", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const Divider(),
              ...book.bids.take(5).map((e) => _buildRow(context, e, maxVol, true, symbol, ref)),
              if (book.bids.isEmpty) const Text("-"),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // ASKS (Sell) - Red
        Expanded(
          child: Column(
            children: [
              const Text("BÁN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const Divider(),
              ...book.asks.take(5).map((e) => _buildRow(context, e, maxVol, false, symbol, ref)),
              if (book.asks.isEmpty) const Text("-"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, OrderBookEntry entry, int maxVol, bool isBid, String symbol, WidgetRef ref) {
    final locale = ref.watch(languageControllerProvider).valueOrNull ?? const Locale('en');
    final percent = (entry.quantity / maxVol);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      height: 24,
      child: Stack(
        children: [
          // Background Bar
          Align(
            alignment: isBid ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                color: isBid ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: isBid ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isBid) ...[
                   Text(CurrencyHelper.format(entry.price, symbol: symbol, locale: locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                   const Spacer(),
                   Text("${entry.quantity}", style: const TextStyle(fontSize: 12)),
                ],
                if (isBid) ...[
                   Text("${entry.quantity}", style: const TextStyle(fontSize: 12)),
                   const Spacer(),
                   Text(CurrencyHelper.format(entry.price, symbol: symbol, locale: locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                ]
              ],
            ),
          )
        ],
      ),
    );
  }
}
