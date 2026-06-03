import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

const _kThemeKey = 'app_theme_mode';

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadSaved();
    return ThemeMode.light;
  }

  void _loadSaved() {
    final storage = ref.read(storageServiceProvider);
    final saved = storage.getFromLocalStorage(_kThemeKey);
    if (saved == 'dark') {
      state = ThemeMode.dark;
    }
  }

  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    _persist(next);
  }

  Future<void> _persist(ThemeMode mode) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setLocalStorage(
      _kThemeKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
