import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:path/path.dart' as path;

const model = 'google/gemini-2.0-flash-lite-001';
const baseUrl = 'https://openrouter.ai/api/v1';

// Initialize color pens
final userPen = AnsiPen()..blue(bold: true);
final aiPen = AnsiPen()..magenta(bold: true);
final errorPen = AnsiPen()..red(bold: true);
final successPen = AnsiPen()..green(bold: true);
final infoPen = AnsiPen()..blue();
final grayPen = AnsiPen()..gray();
final cyanPen = AnsiPen()..cyan(bold: true);
final yellowPen = AnsiPen()..yellow();
final whitePen = AnsiPen()..white();
final greenPen = AnsiPen()..green(bold: true);
final dimPen = AnsiPen()..gray(level: 0.5);

// Markdown styling pens
final boldPen = AnsiPen()..white(bold: true);
final italicPen = AnsiPen()..white();
final codePen = AnsiPen()
  ..yellow()
  ..black(bg: true);
final codeBlockPen = AnsiPen()
  ..gray(level: 0.8)
  ..black(bg: true);
final headingPen = AnsiPen()..cyan(bold: true);
final linkPen = AnsiPen()..blue();

// Load environment variables

void main(List<String> args) async {
  // Clear screen and show header
  _clearScreen();
  _showHeader();

  final env = DotEnv()..load();
  final apiKey = env['OPENROUTER_API_KEY'] ?? '';
  final parser = ArgParser()
    ..addOption('file', abbr: 'f', help: 'Path to an image or PDF')
    ..addOption('text', abbr: 't', help: 'Text prompt instead of file')
    ..addFlag('help', abbr: 'h', help: 'Show usage', negatable: false);

  final parsed = parser.parse(args);

  if (parsed['help']) {
    _showUsage(parser);
    exit(0);
  }

  // Check if API key is loaded
  if (apiKey.isEmpty) {
    _printError('OPENROUTER_API_KEY not found. Please check your .env file.');
    exit(1);
  }

  final dio = Dio();

  // Initialize conversation history
  final messages = <Map<String, dynamic>>[
    {
      'role': 'system',
      'content': 'You are a helpful assistant. Respond conversationally.'
    }
  ];

  try {
    // Handle initial file or text input if provided
    if (parsed.wasParsed('file') || parsed.wasParsed('text')) {
      final content = <Map<String, dynamic>>[];

      if (parsed.wasParsed('file')) {
        final filePath = parsed['file'];
        _printInfo('📁 Loading file: ${path.basename(filePath)}');

        try {
          final fileContent = await _encodeFile(filePath);
          _printSuccess('✅ File loaded successfully');

          final prompt =
              _stdinPrompt('💭 What would you like to know about this file?');
          content.add({'type': 'text', 'text': prompt});
          content.add(fileContent);
        } catch (e) {
          _printError('Failed to load file: $e');
          exit(1);
        }
      } else {
        content.add({'type': 'text', 'text': parsed['text']});
      }

      // Add initial user message
      messages.add({
        'role': 'user',
        'content': content.length == 1 && content[0]['type'] == 'text'
            ? content[0]['text'] // For text-only, use string format
            : content, // For multimodal, use array format
      });

      // Get AI response for initial input
      await _getAIResponse(dio, apiKey, messages);
    }

    // Start conversation loop
    _showConversationHeader();

    while (true) {
      final userInput = _stdinPrompt(userPen('You'));

      if (userInput.toLowerCase().trim() == 'exit' ||
          userInput.toLowerCase().trim() == 'quit' ||
          userInput.trim().isEmpty) {
        _showGoodbye();
        break;
      }

      // Handle clear command
      if (userInput.toLowerCase().trim() == 'clear') {
        _clearScreen();
        _showHeader();
        _showConversationHeader();
        continue;
      }

      // Add user message to conversation
      messages.add({
        'role': 'user',
        'content': userInput,
      });

      // Get AI response
      await _getAIResponse(dio, apiKey, messages);
    }
  } catch (e) {
    _printError('Unexpected error: $e');
  } finally {
    dio.close();
  }
}

Future<void> _getAIResponse(
  Dio dio,
  String apiKey,
  List<Map<String, dynamic>> messages,
) async {
  // Show thinking indicator
  _showThinking();

  try {
    final response = await dio.post<ResponseBody>(
      '$baseUrl/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/your-username/your-repo',
          'X-Title': 'Dart CLI Chat App',
        },
        responseType: ResponseType.stream,
      ),
      data: {
        'model': model,
        'stream': true,
        'messages': messages,
      },
    );

    // Clear thinking indicator and show AI label
    _clearLine();
    print(aiPen('🤖 AI:'));

    String assistantResponse = '';
    await for (final chunk in _parseStream(response.data!)) {
      assistantResponse += chunk;
      // For streaming, we'll show raw text but format the final response
      stdout.write(whitePen(chunk));
    }

    // Clear the raw response and show formatted markdown
    if (assistantResponse.isNotEmpty) {
      // Move cursor up to overwrite the raw text
      final lines = assistantResponse.split('\n').length;
      stdout.write('\x1B[${lines}A'); // Move cursor up
      stdout.write('\x1B[J'); // Clear from cursor to end of screen

      // Print formatted markdown
      _printMarkdown(assistantResponse);
    }

    print(''); // Empty line for spacing

    // Add assistant response to conversation history
    if (assistantResponse.isNotEmpty) {
      messages.add({
        'role': 'assistant',
        'content': assistantResponse,
      });
    }
  } on DioException catch (e) {
    _clearLine();
    if (e.response?.data != null) {
      try {
        final errorData = e.response!.data;
        if (errorData is ResponseBody) {
          final stream = errorData.stream.cast<List<int>>();
          final errorString = await stream.transform(utf8.decoder).join();
          _printError('API Error: $errorString');
        } else if (errorData is String) {
          _printError('API Error: $errorData');
        } else if (errorData is Map) {
          final errorJson = jsonEncode(errorData);
          _printError('API Error: $errorJson');
        } else {
          _printError(
              'HTTP ${e.response!.statusCode}: ${e.response!.statusMessage}');
        }
      } catch (_) {
        _printError(
            'HTTP ${e.response!.statusCode}: ${e.response!.statusMessage}');
      }
    } else {
      _printError('Network Error: ${e.message}');
    }
  }
}

// UI Helper Functions
void _clearScreen() {
  // Use ANSI escape codes for reliable cross-platform screen clearing
  stdout.write('\x1B[2J\x1B[H'); // Clear screen and move cursor to top-left
}

void _clearLine() {
  stdout.write('\r\x1B[K');
}

void _showHeader() {
  print(cyanPen(
      '╔═══════════════════════════════════════════════════════════════╗'));
  print(cyanPen(
      '║                     🤖 AI Chat Assistant                      ║'));
  print(cyanPen(
      '║                  Powered by OpenRouter API                    ║'));
  print(cyanPen(
      '║                     Model: $model                           ║'));
  print(cyanPen(
      '╚═══════════════════════════════════════════════════════════════╝'));
  print(''); // Empty line for spacing
}

void _showUsage(ArgParser parser) {
  print(yellowPen('Usage:'));
  print('  dart run main.dart [options]\n');
  print(yellowPen('Options:'));
  print(parser.usage);
  print('\n${greenPen('Examples:')}');
  print('  ${dimPen('dart run main.dart --file image.jpg')}');
  print('  ${dimPen('dart run main.dart --text "Hello, AI!"')}');
  print('  ${dimPen('dart run main.dart')} ${grayPen('(start conversation)')}');
  print(
      '\n${cyanPen('Note: If no initial input is provided, you can start chatting immediately.')}');
}

void _showConversationHeader() {
  print(greenPen('💬 Conversation Mode Active'));
  print(grayPen('Commands: "exit"/"quit" to end, "clear" to clear screen\n'));
}

void _showGoodbye() {
  print('\n${cyanPen('👋 Thanks for chatting! Goodbye!')}');
}

void _showThinking() {
  stdout.write(yellowPen('🤔 AI is thinking'));
  Timer.periodic(Duration(milliseconds: 500), (timer) {
    if (timer.tick > 6) {
      timer.cancel();
      return;
    }
    stdout.write('.');
  });
}

void _printError(String message) {
  stderr.writeln('${errorPen('❌ ERROR:')} ${errorPen(message)}');
}

void _printSuccess(String message) {
  print(successPen(message));
}

void _printInfo(String message) {
  print(infoPen(message));
}

Future<Map<String, dynamic>> _encodeFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('File not found: $filePath');
  }

  final ext =
      path.extension(filePath).toLowerCase().substring(1); // Remove the dot
  final bytes = await file.readAsBytes();
  final base64Data = base64Encode(bytes);

  if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
    final mime = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    return {
      'type': 'image_url',
      'image_url': {'url': 'data:$mime;base64,$base64Data'}
    };
  } else if (ext == 'pdf') {
    return {
      'type': 'file',
      'file': {
        'file_data': 'data:application/pdf;base64,$base64Data',
        'filename': path.basename(filePath),
      }
    };
  } else {
    throw Exception(
        'Unsupported file type: $filePath (supported: jpg, jpeg, png, webp, pdf)');
  }
}

Stream<String> _parseStream(ResponseBody body) async* {
  final stream = body.stream.cast<List<int>>();
  String buffer = '';

  await for (final chunk in stream.transform(utf8.decoder)) {
    buffer += chunk;
    while (buffer.contains('\n')) {
      final index = buffer.indexOf('\n');
      final line = buffer.substring(0, index).trim();
      buffer = buffer.substring(index + 1);

      if (line.startsWith('data: ')) {
        final payload = line.substring(6);
        if (payload == '[DONE]') return;

        try {
          final json = jsonDecode(payload);
          final content = json['choices']?[0]?['delta']?['content'];
          if (content != null) yield content;
        } catch (_) {}
      }
    }
  }
}

String _stdinPrompt(String label) {
  stdout.write('\n${grayPen('┌─')} $label\n');
  stdout.write('${grayPen('└─')} ');
  final input = stdin.readLineSync() ?? '';
  return input;
}

void _printMarkdown(String markdown) {
  // Simple markdown parser and renderer for terminal
  final lines = markdown.split('\n');

  for (var line in lines) {
    var processedLine = line;

    // Handle code blocks (```code```)
    if (line.trim().startsWith('```')) {
      if (line.trim() == '```') {
        print(grayPen('┌─ Code Block ──────────────────────┐'));
        continue;
      } else {
        print(grayPen('└───────────────────────────────────┘'));
        continue;
      }
    }

    // Handle headings (# ## ###)
    if (line.startsWith('#')) {
      final headingLevel = line.indexOf(' ');
      if (headingLevel > 0) {
        final heading = line.substring(headingLevel + 1);
        print(
            headingPen('${'=' * headingLevel} $heading ${'=' * headingLevel}'));
        continue;
      }
    }

    // Handle inline code (`code`)
    processedLine = processedLine.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (match) => '${codePen(' ${match.group(1)} ')}',
    );

    // Handle bold text (**text**)
    processedLine = processedLine.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => boldPen(match.group(1)!),
    );

    // Handle italic text (*text*)
    processedLine = processedLine.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => italicPen(
          '_${match.group(1)}_'), // Use underscores to indicate italic
    );

    // Handle links [text](url)
    processedLine = processedLine.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (match) =>
          '${linkPen(match.group(1)!)} ${grayPen('(${match.group(2)})')}',
    );

    // Handle bullet points
    if (line.trim().startsWith('- ') || line.trim().startsWith('* ')) {
      final indent = line.indexOf(RegExp(r'[-*]'));
      final bulletText = line.substring(line.indexOf(' ', indent) + 1);
      processedLine = '${' ' * indent}${cyanPen('•')} $bulletText';
    }

    // Handle numbered lists (1. 2. etc.)
    if (RegExp(r'^\s*\d+\.\s').hasMatch(line)) {
      processedLine = line.replaceFirstMapped(
        RegExp(r'^(\s*)(\d+)\.\s'),
        (match) => '${match.group(1)}${cyanPen('${match.group(2)}.')} ',
      );
    }

    print(whitePen(processedLine));
  }
}
