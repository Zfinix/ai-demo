import 'dart:io';

import 'package:args/args.dart';
import 'package:equatable/equatable.dart';

final parser = ArgParser()
  ..addOption('file', abbr: 'f', help: 'Path to the image or PDF file')
  ..addOption('image',
      abbr: 'i', help: 'Path to the image file (legacy, use --file)')
  ..addOption('prompt',
      abbr: 'p', help: 'Prompt for analyzing the file or starting the chat')
  ..addOption('api-key', abbr: 'k', help: 'OpenRouter API key')
  ..addOption('model',
      abbr: 'm',
      help: 'Model to use',
      defaultsTo: 'google/gemini-2.0-flash-001')
  ..addFlag('help',
      abbr: 'h', help: 'Show this help message', negatable: false);

/// Configuration for the CLI tool
class AppConfig with EquatableMixin {
  final File? file;
  final String prompt;
  final String apiKey;
  final String model;
  final bool isTextOnly;
  final bool isPdf;

  const AppConfig({
    required this.file,
    required this.prompt,
    required this.apiKey,
    required this.model,
    required this.isTextOnly,
    required this.isPdf,
  });

  factory AppConfig.fromArgs(ArgResults args) {
    // Prefer --file, fallback to --image for legacy
    final filePath = args['file'] as String? ?? args['image'] as String?;
    final isTextOnly = filePath == null;
    // Determine if the file is a PDF based on extension
    final isPdf = (filePath != null && filePath.toLowerCase().endsWith('.pdf'));

    return AppConfig(
      file: filePath != null ? File(filePath) : null,
      prompt: args['prompt'] ?? '',
      apiKey: args['api-key'] ?? '',
      model: args['model'] ?? 'google/gemini-2.0-flash-001',
      isTextOnly: isTextOnly,
      isPdf: isPdf,
    );
  }

  AppConfig copyWith({
    File? file,
    String? prompt,
    String? apiKey,
    String? model,
    bool? isTextOnly,
    bool? isPdf,
  }) {
    return AppConfig(
      file: file ?? this.file,
      prompt: prompt ?? this.prompt,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      isTextOnly: isTextOnly ?? this.isTextOnly,
      isPdf: isPdf ?? this.isPdf,
    );
  }

  @override
  bool? get stringify => true;

  @override
  List<Object> get props {
    return [
      file ?? {},
      prompt,
      apiKey,
      model,
      isTextOnly,
      isPdf,
    ];
  }
}
