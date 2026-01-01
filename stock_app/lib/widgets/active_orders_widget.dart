import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../presentation/providers/order_provider.dart';
import '../presentation/providers/auth_provider.dart';
import '../domain/entities/order_entity.dart';
import '../theme/app_colors.dart';

class ActiveOrdersWidget extends ConsumerWidget {
  final String symbol;

  const ActiveOrdersWidget({super.key, required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return const SizedBox();

    final ordersAsync = ref.watch(userOrdersProvider(user.id));

    return ordersAsync.when(
      data: (orders) {
        // Filter for active (pending) orders of this symbol
        final activeOrders = orders.where((o) => 
          o.symbol.toUpperCase() == symbol.toUpperCase() && 
          o.status == OrderStatus.pending
        ).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Lệnh đang chờ",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                    onPressed: () {
                      ref.invalidate(userOrdersProvider(user.id));
                    },
                  )
                ],
              ),
            ),
            if (activeOrders.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: const Center(
                  child: Text(
                    "Không có lệnh đang chờ",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeOrders.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final order = activeOrders[index];
                if (order.id == null) return const SizedBox();
                final isBuy = order.side == OrderSide.buy;
                
                return Dismissible(
                  key: Key(order.id!),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Hủy lệnh?"),
                        content: Text("Bạn có chắc muốn hủy lệnh ${isBuy ? 'MUA' : 'BÁN'} ${order.quantity} $symbol?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Không")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true), 
                            child: const Text("Hủy lệnh", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      )
                    );
                  },
                  onDismissed: (direction) {
                     ref.read(orderControllerProvider.notifier).cancelOrder(user.id, order.id!);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isBuy ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isBuy ? AppColors.success.withOpacity(0.3) : AppColors.danger.withOpacity(0.3)
                      )
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${isBuy ? "MUA" : "BÁN"} ${order.quantity}", 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                color: isBuy ? AppColors.success : AppColors.danger
                              )
                            ),
                            Text(
                              "@ ${NumberFormat('#,###').format(order.price)}",
                              style: const TextStyle(fontSize: 12)
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                             ref.read(orderControllerProvider.notifier).cancelOrder(user.id, order.id!);
                          },
                          child: const Text("Hủy", style: TextStyle(color: Colors.red)),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
      error: (_, __) => const SizedBox(),
      loading: () => const Center(child: LinearProgressIndicator()),
    );
  }
}
