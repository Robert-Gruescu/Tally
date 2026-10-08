import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tally/providers.dart';

/// The symbol printed after every amount in the app.
///
/// It shipped as "lei" and is now "RON". The change is small and the migration
/// is not: a phone that has been running the old build has "lei" sitting in
/// its preferences, and without moving it across, half the installs would keep
/// the old spelling forever while the code claimed otherwise.
void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(instance)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh install opens on RON', () async {
    final c = await containerWith({});
    expect(c.read(currencyProvider), 'RON');
  });

  test('a phone carrying the old default is moved across', () async {
    final c = await containerWith({'currency_symbol': 'lei'});
    expect(c.read(currencyProvider), 'RON');
  });

  test('the move is written down, not re-done on every launch', () async {
    SharedPreferences.setMockInitialValues({'currency_symbol': 'lei'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    container.read(currencyProvider);
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getString('currency_symbol'), 'RON');
  });

  test('a symbol the user chose is left alone', () async {
    // The whole reason this is a setting: somebody outside Romania has to be
    // able to run the same build.
    final c = await containerWith({'currency_symbol': '€'});
    expect(c.read(currencyProvider), '€');
  });

  test('setting it back to lei is allowed and sticks', () async {
    // The migration cannot tell a deliberate "lei" from the old default, so
    // the only honest answer is that changing it by hand always wins.
    final c = await containerWith({});
    await c.read(currencyProvider.notifier).set('lei');
    expect(c.read(currencyProvider), 'lei');
  });

  test('blank input is refused rather than clearing the symbol', () async {
    final c = await containerWith({});
    await c.read(currencyProvider.notifier).set('   ');
    expect(c.read(currencyProvider), 'RON');
  });
}
