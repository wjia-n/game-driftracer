import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driftracer/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS), {'driftracerstar'});
    expect(StoreService.starId, 'driftracerstar');
  });
  test('Android maps to coffee + chocolate', () {
    expect(StoreService.productIdsFor(TargetPlatform.android),
        {'driftracercoffee', 'driftracerchocolate'});
  });
  test('iOS and Android product sets do not overlap', () {
    expect(StoreService.productIdsFor(TargetPlatform.iOS)
        .intersection(StoreService.productIdsFor(TargetPlatform.android)), isEmpty);
  });
}
