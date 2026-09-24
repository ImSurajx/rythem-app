import 'dart:async';

enum DatabaseEventType {
  beatToggled,
  beatCreated,
  beatUpdated,
  beatDeleted,
  chapterCreated,
  chapterUpdated,
  chapterDeleted,
  roadmapCreated,
  roadmapUpdated,
  roadmapDeleted,
  databaseReset,
}

class DatabaseEvent {
  final DatabaseEventType type;
  final String? entityId;
  final String? roadmapId;
  final dynamic metadata;

  const DatabaseEvent({
    required this.type,
    this.entityId,
    this.roadmapId,
    this.metadata,
  });

  @override
  String toString() =>
      'DatabaseEvent(type: $type, entityId: $entityId, roadmapId: $roadmapId)';
}

/// A reactive broadcast stream that powers instantaneous cross-screen updates
/// without polling, reloading, or network calls.
class DatabaseEventBus {
  DatabaseEventBus._();

  static final DatabaseEventBus instance = DatabaseEventBus._();

  final StreamController<DatabaseEvent> _controller =
      StreamController<DatabaseEvent>.broadcast();

  Stream<DatabaseEvent> get stream => _controller.stream;

  void emit(DatabaseEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    _controller.close();
  }
}
