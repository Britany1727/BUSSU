import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/di/injection_container.dart';
import 'core/network/supabase_client.dart';
import 'core/security/certificate_pinner.dart';
import 'core/services/auth_session_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) debugPrint('FLUTTER ERROR: ${details.exception}');
  };

  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (!Env.enableMockAuth) {
      CertificatePinner.configure();
    }

    if (!Env.enableMockAuth) {
      final supabaseResult = await SupabaseClientFactory.initialize();

      supabaseResult.fold(
        (failure) {
          debugPrint('Error inicializando Supabase: $failure');
          debugPrint('Usa --dart-define=ENABLE_MOCK_AUTH=true para modo prueba');
        },
        (client) {
          GetIt.instance.registerLazySingleton<SupabaseClient>(() => client);
        },
      );
    }

    await configureDependencies();

    if (!Env.enableMockAuth) {
      GetIt.instance<AuthSessionManager>().initialize();
    }

    if (Env.enableMockAuth) {
      if (kDebugMode) {
        debugPrint('========================================');
        debugPrint('  BUSSU — MODO PRUEBAS');
        debugPrint('  No se requiere backend Supabase');
        debugPrint('========================================');
        debugPrint('  Credenciales de prueba:');
        debugPrint('    Usuario:   test@test.com / 12345678');
        debugPrint('    Conductor: driver@test.com / 12345678');
        debugPrint('    Coop:      coop@test.com / 12345678');
        debugPrint('    Admin:     admin@test.com / 12345678');
        debugPrint('    Premium:   premium@test.com / 12345678');
        debugPrint('========================================');
      }
    }

  runApp(
    ProviderScope(
      overrides: [
        connectivityOverride,
        mqttOverride,
        wsOverride,
        pushOverride,
        paymentOverride,
        deviceBindingOverride,
        authRepositoryOverride,
        if (!Env.enableMockAuth) authSessionManagerOverride,
        busTrackingOverride,
        etaOverride,
        tripOverride,
        stopsOverride,
        fleetOverride,
        networkMonitorOverride,
      ],
      child: const App(),
    ),
  );
  } catch (e, stack) {
    debugPrint('STARTUP ERROR: $e');
    debugPrint('$stack');
    rethrow;
  }
}
