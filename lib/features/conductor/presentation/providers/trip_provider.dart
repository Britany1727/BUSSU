import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/ir_passenger_counter_datasource.dart';
import '../../data/datasources/obd_telemetry_datasource.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/repositories/stops_repository.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/usecases/end_trip_usecase.dart';
import '../../domain/usecases/publish_telemetry_usecase.dart';
import '../../domain/usecases/request_new_stop_usecase.dart';
import '../../domain/usecases/start_trip_usecase.dart';

final tripActiveProvider = StateProvider<bool>((ref) => false);
final driverLocationProvider = StateProvider<LatLng?>((ref) => null);

final driverIdProvider = Provider<String>((ref) {
  return ref.watch(currentUserProvider)?.id ?? 'unknown-driver';
});

final tripRepositoryProvider = Provider<TripRepository>((_) {
  throw UnimplementedError('Registra en injection_container');
});

final stopsRepositoryProvider = Provider<StopsRepository>((_) {
  throw UnimplementedError('Registra en injection_container');
});

final obdTelemetryDataSourceProvider = Provider<ObdTelemetryDataSource>((_) {
  throw UnimplementedError('Registra en injection_container');
});

final startTripUseCaseProvider = Provider<StartTripUseCase>((ref) {
  return StartTripUseCase(ref.watch(tripRepositoryProvider));
});

final endTripUseCaseProvider = Provider<EndTripUseCase>((ref) {
  return EndTripUseCase(ref.watch(tripRepositoryProvider));
});

final publishTelemetryUseCaseProvider = Provider<PublishTelemetryUseCase>((ref) {
  return PublishTelemetryUseCase(ref.watch(tripRepositoryProvider));
});

final requestNewStopUseCaseProvider = Provider<RequestNewStopUseCase>((ref) {
  return RequestNewStopUseCase(ref.watch(stopsRepositoryProvider));
});

final activeTripProvider = StreamProvider<TripEntity?>((ref) {
  final repo = ref.watch(tripRepositoryProvider);
  final id = ref.watch(driverIdProvider);
  return repo.watchActiveTrip(id).map(
    (either) => either.fold((_) => null, (trip) => trip),
  );
});

final tripHistoryProvider = FutureProvider<List<TripEntity>>((ref) async {
  final repo = ref.watch(tripRepositoryProvider);
  final id = ref.watch(driverIdProvider);
  final result = await repo.getTripHistory(id);
  return result.fold((_) => [], (trips) => trips);
});

final busHardwareStatusProvider = StreamProvider.family<BusHardwareStatus, String>((ref, busId) {
  if (busId.isEmpty) return const Stream.empty();
  final ds = ref.watch(obdTelemetryDataSourceProvider);
  return ds.watchHardwareStatus(busId);
});

final irPassengerCounterProvider = Provider<IrPassengerCounterDataSource>((_) {
  throw UnimplementedError('Registra en injection_container');
});

final passengerCountProvider = StreamProvider.family<int, String>((ref, busId) {
  if (busId.isEmpty) return Stream.value(0);
  final ds = ref.watch(irPassengerCounterProvider);
  return ds.watchPassengerCount(busId);
});

final hasActiveTripProvider = Provider<bool>((ref) {
  return ref.watch(activeTripProvider).valueOrNull != null;
});
