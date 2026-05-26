import 'package:flutter/material.dart';

/// Root [ScaffoldMessenger] so auth screens can show errors (they sit above local Scaffolds).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
