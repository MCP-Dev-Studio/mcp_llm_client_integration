import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Tool Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AiAssistantScreen(),
    );
  }
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  _AiAssistantScreenState createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final AiService _aiService = AiService();
  bool _isConnected = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeAiService();
  }

  Future<void> _initializeAiService() async {
    try {
      await _aiService.initialize();

      _aiService.connectionState.listen((connected) {
        setState(() {
          _isConnected = connected;
        });
      });

      // List available tools
      final tools = await _aiService.getAvailableTools();
      setState(() {
        _messages.add(ChatMessage(
          text: 'Available tools:\n' +
              tools.map((t) => '- ${t.name}: ${t.description}').join('\n'),
          isUser: false,
        ));
      });
    } catch (e) {
      _showError('AI service initialization error: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    _textController.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
      ));
      _isTyping = true;
    });

    try {
      if (text.startsWith('/stream')) {
        // Streaming mode
        await _handleStreamChat(text.replaceFirst('/stream', '').trim());
      } else if (text.startsWith('/tool ')) {
        // Direct tool call
        await _handleDirectToolCall(text.replaceFirst('/tool ', '').trim());
      } else {
        // Regular chat
        final response = await _aiService.chat(text);

        // Extract tool call information
        final List<Map<String, dynamic>> toolCallsList = [];
        if (response.toolCalls != null) {
          for (var i = 0; i < response.toolCalls!.length; i++) {
            final call = response.toolCalls![i];
            toolCallsList.add({
              'name': call.name,
              'arguments': call.arguments,
            });
          }
        }

        setState(() {
          _messages.add(ChatMessage(
            text: response.text,
            isUser: false,
            toolCalls: toolCallsList,
          ));
          _isTyping = false;
        });
      }
    } catch (e) {
      _showError('Error: $e');
      setState(() {
        _isTyping = false;
      });
    }
  }

  Future<void> _handleStreamChat(String text) async {
    // Add temporary message for streaming response
    final int messageIndex = _messages.length;
    setState(() {
      _messages.add(ChatMessage(
        text: 'Generating...',
        isUser: false,
      ));
    });

    final StringBuffer fullResponse = StringBuffer();
    final List<Map<String, dynamic>> toolCallsList = [];

    try {
      final responseStream = _aiService.streamChat(text);

      await for (final chunk in responseStream) {
        // Add text chunks to response
        if (chunk['textChunk'] != null && chunk['textChunk'].isNotEmpty) {
          fullResponse.write(chunk['textChunk']);

          setState(() {
            _messages[messageIndex] = ChatMessage(
              text: fullResponse.toString(),
              isUser: false,
              toolCalls: toolCallsList,
            );
          });
        }

        // Add tool call info to list
        if (chunk['toolCalls'] != null) {
          final calls = chunk['toolCalls'] as List;
          for (var i = 0; i < calls.length; i++) {
            toolCallsList.add({
              'name': calls[i]['name'],
              'arguments': calls[i]['arguments'],
            });
          }

          setState(() {
            _messages[messageIndex] = ChatMessage(
              text: fullResponse.toString(),
              isUser: false,
              toolCalls: toolCallsList,
            );
          });
        }

        // Check for stream completion
        if (chunk['isDone'] == true) {
          setState(() {
            _isTyping = false;
          });
        }
      }
    } catch (e) {
      _showError('Streaming error: $e');
      setState(() {
        _isTyping = false;
      });
    }
  }

  Future<void> _handleDirectToolCall(String text) async {
    // Tool command format: /tool {toolName} {arguments(JSON)}
    final parts = text.split(' ');
    if (parts.length < 2) {
      _showError('Invalid tool call format. Use "/tool toolName {arguments}" format.');
      setState(() {
        _isTyping = false;
      });
      return;
    }

    final toolName = parts[0];
    final argsText = parts.sublist(1).join(' ');
    Map<String, dynamic> args;

    try {
      args = jsonDecode(argsText);
    } catch (e) {
      _showError('Arguments are not valid JSON: $e');
      setState(() {
        _isTyping = false;
      });
      return;
    }

    try {
      final result = await _aiService.executeTool(toolName, args);

      setState(() {
        _messages.add(ChatMessage(
          text: 'Tool execution result: $result',
          isUser: false,
        ));
        _isTyping = false;
      });
    } catch (e) {
      _showError('Tool execution error: $e');
      setState(() {
        _isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tool Assistant'),
        actions: [
          Icon(
            _isConnected ? Icons.cloud_done : Icons.cloud_off,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (_, index) => _messages[index],
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 8),
                  Text('AI is typing...'),
                ],
              ),
            ),
          const Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
            ),
            child: _buildTextComposer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.primary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Send a message (supports /stream and /tool commands)',
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _aiService.dispose();
    _textController.dispose();
    super.dispose();
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final List<Map<String, dynamic>> toolCalls;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.toolCalls = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: isUser
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.secondary,
              child: Text(isUser ? 'You' : 'AI'),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? 'You' : 'AI Assistant',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: Text(text),
                ),
                // Display tool call information
                if (toolCalls.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10.0),
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tools used:',
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ...toolCalls.map((toolCall) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            '- ${toolCall["name"] ?? "Unknown"}: ${jsonEncode(toolCall["arguments"] ?? {})}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}