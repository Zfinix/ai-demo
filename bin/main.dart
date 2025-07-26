#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';

/// Configuration for the CLI tool
class AppConfig {
  final String? filePath;
  final String prompt;
  final String apiKey;
  final String model;
  final bool isTextOnly;
  final bool isPdf;

  const AppConfig({
    this.filePath,
    required this.prompt,
    required this.apiKey,
    required this.model,
    required this.isTextOnly,
    required this.isPdf,
  });
}

/// Supported image file extensions
const List<String> _supportedImageFormats = ['png', 'jpg', 'jpeg', 'webp'];
const List<String> _supportedPdfFormats = ['pdf'];

/// Main entry point - keeps it simple and delegates to focused functions
void main(List<String> arguments) async {
  try {
    // Parse arguments and load configuration
    final config = await _parseConfiguration(arguments);

    // Initialize conversation with appropriate content
    final conversation = await _initializeConversation(config);

    // Get and display initial AI response
    await _handleInitialResponse(conversation, config);

    // Start interactive chat loop
    await _startInteractiveChat(conversation, config);
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

/// Parse command line arguments and create configuration
Future<AppConfig> _parseConfiguration(List<String> arguments) async {
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
    ..addFlag('text',
        abbr: 't',
        help: 'Start with text only (no file required)',
        negatable: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show this help message', negatable: false);

  final results = parser.parse(arguments);
  final env = DotEnv()..load();

  // Show help if requested
  if (results['help'] as bool) {
    _showHelp(parser);
    exit(0);
  }

  // Prefer --file, fallback to --image for legacy
  final filePath = results['file'] as String? ?? results['image'] as String?;
  final prompt = results['prompt'] as String?;
  final isTextOnly = results['text'] as bool? ?? false;
  final apiKey = env['OPENROUTER_API_KEY'] ?? results['api-key'] ?? '';
  final model = results['model'] as String;

  // Validate required fields
  if (prompt == null || prompt.isEmpty) {
    throw Exception('Prompt is required. Use -p or --prompt\nUse -h for help');
  }

  if (apiKey.isEmpty) {
    throw Exception(
        'API key is required. Set OPENROUTER_API_KEY environment variable or use -k');
  }

  // Validate file requirements for file mode
  bool isPdf = false;
  if (!isTextOnly) {
    await _validateFile(filePath);
    final ext = filePath!.toLowerCase().split('.').last;
    isPdf = _supportedPdfFormats.contains(ext);
  }

  return AppConfig(
    filePath: filePath,
    prompt: prompt,
    apiKey: apiKey,
    model: model,
    isTextOnly: isTextOnly,
    isPdf: isPdf,
  );
}

/// Display help information
void _showHelp(ArgParser parser) {
  print('🖼️  Image/PDF/Text Analyzer CLI Tool');
  print(
      'Usage: dart run bin/main.dart -f <file_path> -p "<prompt>" -k <api_key>');
  print('   or: dart run bin/main.dart -t -p "<prompt>" -k <api_key>');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print(
      '  dart run bin/main.dart -f screenshot.png -p "What do you see?" -k your_api_key');
  print(
      '  dart run bin/main.dart -f document.pdf -p "Summarize this PDF" -k your_api_key');
  print(
      '  dart run bin/main.dart -f photo.jpg -p "Describe this image" -k your_api_key -m "google/gemini-2.0-flash-001"');
  print('  dart run bin/main.dart -t -p "What is the capital of France?"');
  print('');
  print('💬 After analysis, you can continue chatting with context!');
  print('Type "exit" or press Ctrl+C to quit the conversation.');
}

/// Validate file exists and is supported format (image or PDF)
Future<void> _validateFile(String? filePath) async {
  if (filePath == null || filePath.isEmpty) {
    throw Exception(
        'File path is required. Use -f or --file\nOr use -t for text-only mode.\nUse -h for help');
  }

  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('File not found: $filePath');
  }

  if (!_isFileSupported(filePath)) {
    throw Exception('Unsupported file format. Supported formats: ${[
      ..._supportedImageFormats,
      ..._supportedPdfFormats
    ].join(', ').toUpperCase()}');
  }
}

/// Initialize conversation with system message and user's first message
Future<List<Map<String, dynamic>>> _initializeConversation(
    AppConfig config) async {
  final conversation = <Map<String, dynamic>>[];

  // Add system message - same for all modes
  conversation.add({
    'role': 'system',
    'content': config.isTextOnly
        ? 'You are an AI assistant that engages in conversations. Provide detailed, accurate answers and maintain context throughout the conversation.'
        : config.isPdf
            ? 'You are an AI assistant that analyzes PDF documents and engages in conversations about them. Provide detailed, accurate descriptions and answer questions about the PDF. Maintain context throughout the conversation.'
            : 'You are an AI assistant that analyzes images and engages in conversations about them. Provide detailed, accurate descriptions and answer questions about images. Maintain context throughout the conversation.',
  });

  // Add user message (with or without file)
  if (config.isTextOnly) {
    conversation.add({
      'role': 'user',
      'content': config.prompt,
    });
  } else {
    // Create file message with base64 encoded file
    final fileContent = await _createFileContent(
      config.filePath!,
      config.prompt,
      config.isPdf,
    );
    conversation.add({
      'role': 'user',
      'content': fileContent,
    });
  }

  return conversation;
}

/// Create file content for API request (image or PDF)
Future<List<Map<String, dynamic>>> _createFileContent(
    String filePath, String prompt, bool isPdf) async {
  final file = File(filePath);
  final fileBytes = await file.readAsBytes();
  final base64Data = base64Encode(fileBytes);

  final extension = filePath.toLowerCase().split('.').last;
  if (isPdf) {
    // PDF
    return [
      {'type': 'text', 'text': prompt},
      {
        'type': 'file',
        'file': {
          'file_data': 'data:application/pdf;base64,$base64Data',
          'filename': file.uri.pathSegments.last,
        }
      }
    ];
  } else {
    // Image
    final mimeType = _getMimeType(extension);
    final dataUrl = 'data:$mimeType;base64,$base64Data';
    return [
      {'type': 'text', 'text': prompt},
      {
        'type': 'image_url',
        'image_url': {'url': dataUrl},
      },
    ];
  }
}

/// Get MIME type from file extension
String _getMimeType(String extension) {
  return switch (extension) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/jpeg' // fallback
  };
}

/// Handle initial AI response and display it
Future<void> _handleInitialResponse(
  List<Map<String, dynamic>> conversation,
  AppConfig config,
) async {
  print(
      '🔍 ${config.isTextOnly ? 'Starting text-only chat' : config.isPdf ? 'Analyzing PDF: ${config.filePath}' : 'Analyzing image: ${config.filePath}'}');
  print('💬 Initial prompt: ${config.prompt}');
  print('🤖 Model: ${config.model}');
  print('');
  print('🤖 AI Response:');
  print('─' * 50);

  final response = await _getChatResponse(conversation, config);

  if (response.startsWith('[ERROR]')) {
    throw Exception(response.substring(7)); // Remove '[ERROR]' prefix
  }

  // Add AI response to conversation history
  conversation.add({
    'role': 'assistant',
    'content': response,
  });

  print('\n');
  print('─' * 50);
  print('💬 Continue the conversation! (Type "exit" to quit)');
  print('');
}

/// Interactive chat loop - handles ongoing conversation
Future<void> _startInteractiveChat(
  List<Map<String, dynamic>> conversation,
  AppConfig config,
) async {
  while (true) {
    // Get user input
    stdout.write('You: ');
    final userInput = stdin.readLineSync()?.trim();

    // Handle empty input or exit command
    if (userInput == null || userInput.isEmpty) continue;
    if (userInput.toLowerCase() == 'exit') {
      print('👋 Goodbye!');
      break;
    }

    // Add user message and get AI response
    conversation.add({'role': 'user', 'content': userInput});

    print('\n🤖 AI: ');
    final response = await _getChatResponse(conversation, config);

    if (response.startsWith('[ERROR]')) {
      print('❌ ${response.substring(7)}'); // Remove '[ERROR]' prefix
      print('');
      continue;
    }

    // Add AI response to conversation history
    conversation.add({'role': 'assistant', 'content': response});
    print('\n');
  }
}

/// Get streaming chat response from OpenRouter API
Future<String> _getChatResponse(
  List<Map<String, dynamic>> conversation,
  AppConfig config,
) async {
  final dio = Dio();
  final responseBuffer = StringBuffer();

  try {
    final response = await dio.post<ResponseBody>(
      'https://openrouter.ai/api/v1/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiKey}',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.stream,
      ),
      data: {
        'model': config.model,
        'messages': conversation,
        'temperature': 0.7,
        'max_tokens': 1500,
        'stream': true,
      },
    );

    // Process streaming response
    if (response.data != null) {
      await for (final chunk in _parseSSEStream(response.data!)) {
        if (chunk.startsWith('[ERROR]')) return chunk;

        stdout.write(chunk);
        responseBuffer.write(chunk);
      }
    }

    return responseBuffer.toString();
  } catch (e) {
    return '[ERROR] Failed to get response: $e';
  } finally {
    dio.close();
  }
}

/// Parse Server-Sent Events (SSE) stream from OpenRouter
Stream<String> _parseSSEStream(ResponseBody responseBody) async* {
  final stream = responseBody.stream.cast<List<int>>();
  String buffer = '';

  await for (final chunk in stream.transform(utf8.decoder)) {
    buffer += chunk;

    // Process complete lines
    while (buffer.contains('\n')) {
      final lineEnd = buffer.indexOf('\n');
      final line = buffer.substring(0, lineEnd).trim();
      buffer = buffer.substring(lineEnd + 1);

      // Skip empty lines and comments
      if (line.isEmpty || line.startsWith(':')) continue;

      // Parse SSE data lines
      if (line.startsWith('data: ')) {
        final data = line.substring(6);

        // Check for end of stream
        if (data == '[DONE]') return;

        try {
          final jsonData = jsonDecode(data) as Map<String, dynamic>;
          final choices = jsonData['choices'] as List?;

          if (choices != null && choices.isNotEmpty) {
            final delta = choices.first['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;

            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (e) {
          // Skip malformed JSON chunks - this is normal in streaming
          continue;
        }
      }
    }
  }
}

/// Check if file format is supported (image or PDF)
bool _isFileSupported(String filePath) {
  final extension = filePath.toLowerCase().split('.').last;
  return _supportedImageFormats.contains(extension) ||
      _supportedPdfFormats.contains(extension);
}
