# 🤖 AI Chat CLI in Dart

> **Building an AI Chat CLI in Dart: Real-Time Conversations with Gemini + OpenRouter**
> 
> Imagine chatting with AI from your terminal, feeding it PDFs or images, and getting instant answers! This project demonstrates how to build a powerful, interactive AI assistant that runs entirely in your command line.

## ✨ Features

🗣️ **Real-Time Conversations** - Stream AI responses in real-time, just like ChatGPT  
🖼️ **Image Analysis** - Upload and analyze images (PNG, JPG, JPEG, WEBP)  
📄 **PDF Document Processing** - Ask questions about PDF documents  
🎨 **Beautiful Terminal UI** - Colorized output with markdown formatting  
💬 **Conversation Memory** - Maintains context throughout your chat session  
🔄 **Multiple Modes** - Simple mode for quick queries, advanced mode for rich interactions  
🌐 **Powered by OpenRouter** - Access to multiple AI models including Google Gemini  

## 🚀 Demo Highlights

This CLI tool showcases:

- **Multimodal AI Interactions**: Send images and PDFs alongside text prompts
- **Streaming Responses**: See AI responses appear in real-time
- **Context Preservation**: Continue conversations with full context awareness  
- **Professional Terminal UI**: Color-coded output with proper formatting
- **Error Handling**: Graceful handling of API errors and file issues
- **Flexible Configuration**: Support for different AI models and configurations

## 📋 Prerequisites

- **Dart SDK** (3.0.0 or higher)
- **OpenRouter API Key** - Get one at [OpenRouter.ai](https://openrouter.ai)

## ⚡ Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd demo
dart pub get
```

### 2. Configure API Key

Create a `.env` file in the project root:

```env
OPENROUTER_API_KEY=your_openrouter_api_key_here
```

### 3. Run the CLI

**Simple Mode (main.dart):**
```bash
# Text-only chat
dart run bin/main.dart -t -p "Hello, what can you help me with?"

# Image analysis
dart run bin/main.dart -i screenshot.png -p "What do you see in this image?"

# Custom model
dart run bin/main.dart -t -p "Explain quantum computing" -m "google/gemini-2.0-flash-001"
```

**Advanced Mode (advanced.dart):**
```bash
# Start interactive chat
dart run bin/advanced.dart

# Analyze an image
dart run bin/advanced.dart -f image.jpg

# Process a PDF document
dart run bin/advanced.dart -f document.pdf

# Quick text prompt
dart run bin/advanced.dart -t "What is machine learning?"
```

## 🎯 Usage Examples

### Image Analysis
```bash
$ dart run bin/advanced.dart -f screenshot.png
📁 Loading file: screenshot.png
✅ File loaded successfully
💭 What would you like to know about this file? Describe what you see

🤖 AI: I can see a screenshot of a code editor showing...
```

### PDF Question Answering
```bash
$ dart run bin/advanced.dart -f research_paper.pdf
📁 Loading file: research_paper.pdf
✅ File loaded successfully  
💭 What would you like to know about this file? Summarize the main findings

🤖 AI: Based on the PDF document, the main findings are...
```

### Interactive Chat Session
```bash
$ dart run bin/advanced.dart
╔═══════════════════════════════════════════════════════════════╗
║                     🤖 AI Chat Assistant                      ║
║                  Powered by OpenRouter API                    ║
║                     Model: google/gemini-2.0-flash-lite-001   ║
╚═══════════════════════════════════════════════════════════════╝

💬 Conversation Mode Active
Commands: "exit"/"quit" to end, "clear" to clear screen

┌─ You
└─ Tell me about Dart programming language

🤖 AI: Dart is a modern, object-oriented programming language...
```

## 🛠️ Project Structure

```
demo/
├── bin/
│   ├── main.dart          # Simple CLI implementation
│   └── advanced.dart      # Advanced CLI with rich formatting
├── pubspec.yaml           # Dependencies and project config
├── .env                   # API key configuration
└── README.md             # This file
```

## 🔧 Configuration Options

### Main.dart Options
- `-i, --image`: Path to image file
- `-p, --prompt`: Your question or prompt  
- `-k, --api-key`: OpenRouter API key (or use .env)
- `-m, --model`: AI model to use
- `-t, --text`: Text-only mode (no image required)
- `-h, --help`: Show help information

### Advanced.dart Options  
- `-f, --file`: Path to image or PDF file
- `-t, --text`: Direct text prompt
- `-h, --help`: Show usage information

## 🎨 Features Showcase

### Real-Time Streaming
Watch AI responses appear word-by-word in real-time, creating a natural conversation flow.

### Multimodal Capabilities
```bash
# Analyze code screenshots
dart run bin/main.dart -i code_screenshot.png -p "Find bugs in this code"

# Process research papers  
dart run bin/advanced.dart -f research.pdf
```

### Rich Terminal UI
- **Color-coded output** for different message types
- **Markdown formatting** with proper rendering
- **Progress indicators** and status messages
- **Error handling** with clear user feedback

### Conversation Context
The AI maintains context throughout your session:
```
You: What's the capital of France?
AI: The capital of France is Paris...

You: What's the population there?  
AI: Paris has a population of approximately 2.1 million people...
```

## 🚀 Supported AI Models

- `google/gemini-2.0-flash-001` (default for main.dart)
- `google/gemini-2.0-flash-lite-001` (default for advanced.dart)
- Any OpenRouter supported model

## 📝 Dependencies

```yaml
dependencies:
  args: ^2.4.2          # Command line argument parsing
  dio: ^5.4.0           # HTTP client for API requests  
  dotenv: ^4.2.0        # Environment variable loading
  path: ^1.8.3          # File path utilities
  ansicolor: ^2.0.3     # Terminal color output
  markdown: ^7.2.2      # Markdown processing
```

## 🎪 Demo Script Ideas

1. **Image Analysis Demo**: Show a complex diagram and ask the AI to explain it
2. **PDF Processing**: Upload a research paper and ask for key insights
3. **Code Review**: Take a screenshot of code and ask for improvements
4. **Interactive Chat**: Demonstrate context preservation across multiple questions
5. **Real-time Streaming**: Show the smooth, word-by-word response generation

## 🔍 Technical Highlights

- **Streaming API Integration**: Implements Server-Sent Events (SSE) parsing
- **Base64 Encoding**: Handles image and PDF file encoding for API transmission
- **Error Handling**: Comprehensive error handling for network and API issues
- **Terminal UI**: Advanced ANSI escape codes for rich terminal formatting
- **Multimodal Content**: Proper handling of mixed text and media content
- **Conversation State**: Maintains conversation history for context awareness

## 🤝 Contributing

This is a demo project showcasing Dart CLI development with AI integration. Feel free to fork and experiment!

## 📄 License

This project is for educational and demonstration purposes.

---

**Ready to experience the future of terminal-based AI interactions?** 🚀

Try it out: `dart run bin/advanced.dart` 