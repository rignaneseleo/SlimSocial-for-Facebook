import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:slimsocial_for_facebook/consts.dart';
import 'package:slimsocial_for_facebook/style/color_schemes.g.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';

final sliderValueSubscriptionProvider =
    StateProvider.autoDispose<double>((ref) => 10.0);

class SubscriptionBottomSheet extends ConsumerWidget {
  SubscriptionBottomSheet({super.key});
  StreamSubscription<List<PurchaseDetails>>? _paymentSubscription;

  Future buildPaymentWidget(String idItem) async {
    //get the product
    final response = await InAppPurchase.instance.queryProductDetails({idItem});
    if (response.notFoundIDs.isNotEmpty) {
      print("Product not found");
      showToast("error_trylater".tr());
      return;
    }

    //set the listener
    final purchaseUpdated = InAppPurchase.instance.purchaseStream;

    _paymentSubscription ??= purchaseUpdated.listen(
      (List<PurchaseDetails> purchaseDetailsList) {
        // handle  purchaseDetailsList
        purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
          if (purchaseDetails.status == PurchaseStatus.pending) {
          } else {
            if (purchaseDetails.status == PurchaseStatus.error) {
              showToast("error_trylater".tr());
            } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                purchaseDetails.status == PurchaseStatus.restored) {
              showToast("${"thankyou".tr()} ❤️");
            }
            if (purchaseDetails.pendingCompletePurchase) {
              await InAppPurchase.instance.completePurchase(purchaseDetails);
            }
          }
        });
      },
      onDone: () {
        showToast("${"thankyou".tr()} ❤️");
        print("Close subscription");
      },
      onError: (error) {
        print("Payment error: $error");
        showToast("error_trylater".tr());
      },
    );

    //show the dialog
    final products = response.productDetails;
    final product = products.first;
    final purchaseParam = PurchaseParam(productDetails: product);
    await InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);

    return;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = ref.watch(sliderValueSubscriptionProvider);

    // List of avialable prices
    final availablePrices = [10.0, 15.0, 20.0, 25.0];

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pay what you want',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('No commitment', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          ClipOval(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                //shape: BoxShape.circle,
                //borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: const AssetImage('assets/logo_rounded.png'),
                  opacity: amount / 25.0,
                ),
              ), // Importante per il clipping corretto
            ),
          ),
          const SizedBox(height: 20),
          Text('€${amount.toStringAsFixed(2)}/year'),
          Slider(
            value: amount,
            min: 10,
            max: 25,
            activeColor: FacebookColors.blue,
            divisions: 3,
            onChanged: (value) {
              // Arrotonda al valore più vicino tra quelli disponibili
              final nearestValue = availablePrices.reduce((a, b) {
                return (value - a).abs() < (value - b).abs() ? a : b;
              });
              ref.read(sliderValueSubscriptionProvider.notifier).state =
                  nearestValue;
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: FacebookColors.blue,
            ),
            child: const Text(
              'BECOME A MEMBER',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              Navigator.pop(context);
              // Chiude il bottom sheet
              final productId = priceToProductId[amount];
              if (productId == null) {
                showToast("error_trylater".tr());
                return;
              }
              await buildPaymentWidget(productId);
              print("Product ID: $productId");
              print("Amount: $amount");
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
