import 'package:flutter/widgets.dart';
import 'package:openriver_api/openriver_api.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app/openriver_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    OpenRiverApp(
      core: RustOpenRiverCore(),
      databasePath: () async {
        final directory = await getApplicationSupportDirectory();
        await directory.create(recursive: true);
        return path.join(directory.path, 'openriver.sqlite3');
      },
    ),
  );
}
