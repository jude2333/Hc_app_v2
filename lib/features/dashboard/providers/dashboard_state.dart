import 'package:flutter/foundation.dart';
import '../models/dashboard_report.dart';

@immutable
sealed class DashboardState {
  const DashboardState();
}

final class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

final class DashboardLoading extends DashboardState {
  final bool isFirstLoad;

  const DashboardLoading({this.isFirstLoad = true});
}

final class DashboardLoaded extends DashboardState {
  final DashboardReport report;

  const DashboardLoaded(this.report);
}

final class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);
}

extension DashboardStateExtension on DashboardState {
  T when<T>({
    required T Function() initial,
    required T Function(bool isFirstLoad) loading,
    required T Function(DashboardReport report) loaded,
    required T Function(String message) error,
  }) {
    return switch (this) {
      DashboardInitial() => initial(),
      DashboardLoading(:final isFirstLoad) => loading(isFirstLoad),
      DashboardLoaded(:final report) => loaded(report),
      DashboardError(:final message) => error(message),
    };
  }

  bool get hasData => switch (this) {
        DashboardLoaded() => true,
        _ => false,
      };

  DashboardReport? get dataOrNull => switch (this) {
        DashboardLoaded(:final report) => report,
        _ => null,
      };

  bool get isLoading => this is DashboardLoading;

  bool get isFirstLoad => switch (this) {
        DashboardLoading(:final isFirstLoad) => isFirstLoad,
        _ => false,
      };
}
