import 'package:project_time/domain/services/id_generator.dart';

/// Deterministic incrementing ID generator for tests.
class CounterIdGenerator implements IdGenerator {
  int _counter = 0;
  @override
  String newId() => 'id-${_counter++}';
}
