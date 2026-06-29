import 'package:uuid/uuid.dart';

/// Abstraction over UUID generation so tests can inject deterministic IDs.
abstract class IdGenerator {
  String newId();
}

class UuidGenerator implements IdGenerator {
  UuidGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid();
  final Uuid _uuid;

  @override
  String newId() => _uuid.v4();
}
