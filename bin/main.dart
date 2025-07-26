// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'constants.dart';

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
  final results = parser.parse(arguments);
  final env = DotEnv()..load();

  // Show help if requested
  if (results['help'] as bool) {
    _showHelp(parser);
    exit(0);
  }

  final config = AppConfig.fromArgs(results).copyWith(
    apiKey: env['OPENROUTER_API_KEY'],
  );

  // Validate required fields
  if (config.prompt.isEmpty) {
    throw Exception('Prompt is required. Use -p or --prompt\nUse -h for help');
  }

  if (config.apiKey.isEmpty) {
    throw Exception(
      'API key is required. Set OPENROUTER_API_KEY environment variable or use -k',
    );
  }

  final fileIsValid = await _fileIsValid(config);
  if (!fileIsValid) {
    throw Exception('File is not valid. Use -h for help');
  }

  return config;
}

/// Display help information
void _showHelp(ArgParser parser) {
  print('''
🖼️  Image/PDF/Text Analyzer CLI Tool

Usage: dart run bin/main.dart -f <file_path> -p "<prompt>" -k <api_key>
   or: dart run bin/main.dart -p "<prompt>" -k <api_key>

Options:
${parser.usage}

Examples:
  dart run bin/main.dart -f screenshot.png -p "What do you see?" -k your_api_key
  dart run bin/main.dart -f document.pdf -p "Summarize this PDF" -k your_api_key
  dart run bin/main.dart -f photo.jpg -p "Describe this image" -k your_api_key -m "google/gemini-2.0-flash-001"
  dart run bin/main.dart -p "What is the capital of France?"

💬 After analysis, you can continue chatting with context!
Type "exit" or press Ctrl+C to quit the conversation.
''');
}

/// Validate file exists and is supported format (image or PDF)
Future<bool> _fileIsValid(AppConfig config) async {
  if (config.file == null) {
    return true;
  }

  if (!await config.file!.exists()) {
    throw Exception('File not found: ${config.file}');
  }

  final extension = path.extension(config.file!.path).toLowerCase();
  return ['png', 'jpg', 'jpeg', 'webp', 'pdf'].contains(extension);
}

/// Initialize conversation with system message and user's first message
Future<List<Map<String, dynamic>>> _initializeConversation(
  AppConfig config,
) async {
  final conversation = <Map<String, dynamic>>[];

  // Add system message - same for all modes
  final systemContent = switch ((config.isTextOnly, config.isPdf)) {
    (true, _) => '''
          You are an AI assistant that engages in conversations.
          - Provide detailed, accurate answers.
          - Maintain context throughout the conversation.
          - Respond in a clear and helpful manner.
          ''',
    (false, true) => '''
          You are an AI assistant that analyzes PDF documents and engages in conversations about them.
          - Provide detailed, accurate descriptions of the PDF content.
          - Answer questions about the PDF.
          - Maintain context throughout the conversation.
          - If asked, summarize, extract key points, or explain sections of the PDF.
          ''',
    _ => '''
          You are an AI assistant that analyzes images and engages in conversations about them.
          - Provide detailed, accurate descriptions of the image content.
          - Answer questions about the image.
          - Maintain context throughout the conversation.
          - If asked, identify objects, describe scenes, or explain visual details.
          '''
  };

  conversation.add({
    'role': 'system',
    'content': systemContent,
  });

  // Add user message (with or without file)
  if (config.isTextOnly) {
    conversation.add(
      {
        'role': 'user',
        'content': config.prompt,
      },
    );
  } else {
    // Create file message with base64 encoded file
    final fileContent = await _createFileContent(config);
    conversation.add({
      'role': 'user',
      'content': [
        {
          'type': 'text',
          'text': config.prompt,
        },
        fileContent,
      ],
    });
  }

  return conversation;
}

/// Create file content for API request (image or PDF)
Future<Map<String, dynamic>> _createFileContent(AppConfig config) async {
  final fileBytes = await config.file!.readAsBytes();
  final base64Data = base64Encode(fileBytes);

  final mimeType = lookupMimeType(path.extension(config.file!.path));
  final dataUrl = 'data:$mimeType;base64,$base64Data';

  return switch (config.isPdf) {
    true => {
        'type': 'file',
        'file': {
          'file_data': 'data:application/pdf;base64,$base64Data',
          'filename': path.basename(config.file!.path),
        }
      },
    false =>
      // Image
      {
        'type': 'image_url',
        'image_url': {'url': dataUrl},
      }
  };
}

/// Handle initial AI response and display it
Future<void> _handleInitialResponse(
  List<Map<String, dynamic>> conversation,
  AppConfig config,
) async {
  print('''
        🔍 ${config.isTextOnly ? 'Starting text-only chat' : config.isPdf ? 'Analyzing PDF: ${config.file}' : 'Analyzing image: ${config.file}'}
        💬 Initial prompt: ${config.prompt}
        🤖 Model: ${config.model}

        🤖 AI Response:
        ${'─' * 50}
  ''');

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
