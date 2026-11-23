import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled Fraunces font (SIL Open Font License) must ship with its
  // licence; this lists it on Flutter's licences page.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/Fraunces-OFL.txt');
    yield LicenseEntryWithLineBreaks(['Fraunces'], text);
  });
  runApp(const ProviderScope(child: BarbershopApp()));
}
