// Local types replacing dart_smb2 dependency

enum Smb2ErrorType {
  connection,
  timeout,
  auth,
  accessDenied,
  notFound,
  notADirectory,
  invalidParam,
  isADirectory,
  alreadyExists,
  notEmpty,
  inUse,
  diskFull,
  notSupported,
  cancelled,
  unknown;

  static Smb2ErrorType fromMessage(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('timeout')) return Smb2ErrorType.timeout;
    if (msg.contains('connection') || msg.contains('unreachable')) {
      return Smb2ErrorType.connection;
    }
    if (msg.contains('auth') || msg.contains('logon')) return Smb2ErrorType.auth;
    if (msg.contains('denied') || msg.contains('permission')) {
      return Smb2ErrorType.accessDenied;
    }
    if (msg.contains('not found')) return Smb2ErrorType.notFound;
    return Smb2ErrorType.unknown;
  }
}

class Smb2Exception implements Exception {
  final String message;
  final Smb2ErrorType type;
  final String? path;

  Smb2Exception(this.message, {this.type = Smb2ErrorType.unknown, this.path});

  bool get isNotFound => type == Smb2ErrorType.notFound;

  @override
  String toString() => message;
}

class Smb2Stat {
  final int size;
  final bool isDirectory;
  final DateTime modified;

  Smb2Stat({
    this.size = 0,
    this.isDirectory = false,
    DateTime? modified,
  }) : modified = modified ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isFile => !isDirectory;
}

class Smb2DirEntry {
  final String name;
  final Smb2Stat stat;

  Smb2DirEntry({
    required this.name,
    required this.stat,
  });
}

class Smb2ShareInfo {
  final String name;
  final String comment;

  Smb2ShareInfo({required this.name, this.comment = ''});

  bool get isDisk => true;
}

class Smb2Pool {
  static Future<List<Smb2ShareInfo>> shares({
    required String host,
    required String user,
    required String password,
    required String domain,
    required Duration timeout,
  }) async => const [];

  static Future<List<Smb2ShareInfo>> listSharesOn({
    required String host,
    required String user,
    required String password,
    required String domain,
    required Duration timeout,
  }) async => const [];
}
