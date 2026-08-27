import 'package:flutter/material.dart';

/// A deterministic fallback surface when an error happens before routing.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'RemoteOS',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 16),
                    Text('RemoteOS could not start',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const Text(
                      'Please restart the application. Details were written to the RemoteOS log when possible.',
                    ),
                    const SizedBox(height: 12),
                    SelectableText(message),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
