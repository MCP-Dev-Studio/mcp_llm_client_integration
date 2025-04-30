# Integrating AI with Flutter: Building Powerful Apps with LlmClient and mcp_client

![Flutter and AI Integration](https://images.unsplash.com/photo-1617040619263-41c5a9ca7521?q=80&w=2070&auto=format&fit=crop)

## Introduction

In our ongoing series about integrating AI with Flutter applications, we previously introduced the `mcp_llm` package as a comprehensive toolkit for connecting Large Language Models with Flutter apps. This article—the fourth in our Model Context Protocol (MCP) series and the second focused on `mcp_llm`—dives deeper into the integration between `LlmClient` and `mcp_client`, exploring how this powerful combination enables AI models to access external tools and resources.

The synergy between these components transforms AI capabilities from simple text generation to genuinely interactive and functional features that can interact with the real world. Let's explore how to build AI-powered applications with these components.

## Table of Contents

1. [Understanding LlmClient and mcp_client](#understanding-llmclient-and-mcp_client)
2. [Integration Architecture](#integration-architecture)
3. [Setting Up the Integration](#setting-up-the-integration)
4. [Leveraging MCP Tools](#leveraging-mcp-tools)
5. [Working with MCP Resources](#working-with-mcp-resources)
6. [Managing Multiple MCP Clients](#managing-multiple-mcp-clients)
7. [Implementing a Sample App](#implementing-a-sample-app)
8. [Next Steps](#next-steps)

## Understanding LlmClient and mcp_client

Before diving into integration details, let's clarify the roles of these two key components:

### The Role of LlmClient

`LlmClient` is a core component from the `mcp_llm` package responsible for:

- Communicating with Large Language Models (LLMs) like Claude, GPT, etc.
- Managing chat sessions and contexts
- Processing tool calls from the LLM
- Handling streaming responses
- Managing system prompts and parameters

It essentially serves as your app's gateway to AI capabilities.

### The Role of mcp_client

`mcp_client` implements the Model Context Protocol (MCP) on the client side, allowing:

- Communication with MCP servers
- Access to external tools
- Access to resources (databases, APIs, files)
- Access to standardized prompt templates
- Management of authentication and connections

### The Value of Integration

When integrated, these components enable:

1. LLMs to call external tools and utilize results
2. Access to external data sources and APIs
3. Use of standardized prompt templates
4. Complex tool-based workflows
5. Bi-directional communication between AI and external systems

This integration transforms AI applications from simple chat interfaces to functional tools that can perform real-world actions based on user requests.

## Integration Architecture

Understanding the architecture of this integration is crucial for implementation:

### Integration Model

```
┌────────────────┐       ┌────────────────┐
│   LlmClient    │◄─────►│   mcp_client   │
└───────┬────────┘       └───────┬────────┘
        │                        │
        ▼                        ▼
┌────────────────┐       ┌────────────────┐
│  LLM Provider  │       │   MCP Server   │
│  (Claude, GPT) │       │  (Tools, etc.) │
└────────────────┘       └────────────────┘
```

### Communication Flow

The communication flow between components follows this pattern:

1. `LlmClient` sends user queries to the LLM provider
2. If the LLM determines a tool is needed, it returns a tool call request
3. `LlmClient` forwards the tool call to `mcp_client`
4. `mcp_client` executes the tool via the MCP server
5. Tool results are returned to `mcp_client`
6. `LlmClient` passes tool results back to the LLM
7. The LLM generates a final response based on tool results

This architecture enables a seamless flow from user input to intelligent, tool-augmented AI responses.

## Setting Up the Integration

Let's walk through the setup process for integrating `LlmClient` with `mcp_client`:

### Project Setup

Start by creating a new Flutter project and adding the required dependencies:

```bash
# Create a new Flutter project
flutter create mcp_llm_client_integration

# Navigate to the project directory
cd mcp_llm_client_integration

# Add necessary packages
flutter pub add mcp_llm
flutter pub add mcp_client
flutter pub add flutter_dotenv
```

Create a `.env` file in your project root for configuration:
```
CLAUDE_API_KEY=your-claude-api-key
MCP_SERVER_URL=http://localhost:8999/sse
MCP_AUTH_TOKEN=your-auth-token
```

Update your `pubspec.yaml` to include the `.env` file as an asset:
```yaml
flutter:
  assets:
    - .env
    # Other assets...
```

### Basic Integration Setup

Here's how to set up the basic integration between `LlmClient` and `mcp_client`:

```dart
import 'package:mcp_llm/mcp_llm.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;

Future<void> setupIntegration() async {
  // Create McpLlm instance
  final mcpLlm = McpLlm();
  
  // Register LLM provider
  mcpLlm.registerProvider('claude', ClaudeProviderFactory());
  
  // Create MCP client
  final mcpClient = mcp.McpClient.createClient(
    name: 'flutter_app',
    version: '1.0.0',
    capabilities: mcp.ClientCapabilities(
      roots: true,
      rootsListChanged: true,
      sampling: true,
    ),
  );
  
  // Create transport
  final transport = await mcp.McpClient.createSseTransport(
    serverUrl: 'http://localhost:8999/sse',
    headers: {'Authorization': 'Bearer your_token'},
  );
  
  // Connect to MCP server
  await mcpClient.connectWithRetry(
    transport,
    maxRetries: 3,
    delay: const Duration(seconds: 2),
  );
  
  // Create LlmClient with MCP client integration
  final llmClient = await mcpLlm.createClient(
    providerName: 'claude',
    config: LlmConfiguration(
      apiKey: 'your-claude-api-key',
      model: 'claude-3-haiku-20240307',
    ),
    mcpClient: mcpClient,  // Connect MCP client
    systemPrompt: 'You are a helpful assistant with access to various tools.',
  );
  
  // Now you can use llmClient to interact with AI and tools
}
```

### Monitoring Connection State

It's important to monitor the connection state of your MCP client:

```dart
mcpClient.onNotification('connection_state_changed', (params) {
  final state = params['state'] as String;
  print('MCP connection state: $state');
  // Update UI or take action based on state changes
});
```

## Leveraging MCP Tools

One of the most powerful aspects of this integration is the ability to use external tools through MCP. Here's how to leverage them:

### Listing Available Tools

```dart
Future<void> listAvailableTools() async {
  final tools = await mcpClient.listTools();
  
  print('Available tools:');
  for (final tool in tools) {
    print('- ${tool.name}: ${tool.description}');
  }
}
```

### Indirect Tool Calls via AI

Set up your AI to call tools when needed:

```dart
Future<void> chatWithToolUse() async {
  final response = await llmClient.chat(
    "What's the weather in New York today?", 
    enableTools: true,  // Enable tool usage
  );
  
  print('AI Response: ${response.text}');
}
```

### Direct Tool Calls

You can also directly call tools:

```dart
Future<void> executeToolDirectly() async {
  try {
    final result = await llmClient.executeTool(
      'weather',  // Tool name
      {
        'location': 'New York',
        'unit': 'celsius',
      },
    );
    
    print('Tool execution result: $result');
  } catch (e) {
    print('Tool execution error: $e');
  }
}
```

### Handling Tool Calls in Streaming Responses

Process tool calls while streaming responses:

```dart
Future<void> streamChatWithToolUse() async {
  final responseStream = llmClient.streamChat(
    "Tell me the weather in New York and San Francisco",
    enableTools: true,
  );
  
  final StringBuffer currentResponse = StringBuffer();
  
  await for (final chunk in responseStream) {
    // Handle text chunks
    if (chunk['textChunk'] != null && chunk['textChunk'].isNotEmpty) {
      currentResponse.write(chunk['textChunk']);
      print('Current response: ${currentResponse.toString()}');
    }
    
    // Check for stream completion
    if (chunk['isDone'] == true) {
      print('Response stream completed');
    }
  }
}
```

## Working with MCP Resources

MCP resources provide structured access to external data and systems:

### Listing Available Resources

```dart
Future<void> listAvailableResources() async {
  final resources = await mcpClient.listResources();
  
  print('Available resources:');
  for (final resource in resources) {
    print('- ${resource.name}: ${resource.description}');
    print('  URI: ${resource.uri}');
  }
}
```

### Reading Resources

```dart
Future<void> readResource() async {
  try {
    final resourceContent = await mcpClient.readResource('company_data');
    
    print('Resource content: $resourceContent');
    
    // Use resource with AI
    final response = await llmClient.chat(
      "Analyze this company data: $resourceContent",
    );
    
    print('AI Analysis: ${response.text}');
  } catch (e) {
    print('Resource reading error: $e');
  }
}
```

### Using Resource Templates

```dart
Future<void> getResourceWithTemplate() async {
  try {
    final result = await mcpClient.getResourceWithTemplate(
      'files://project/{filename}',
      {'filename': 'config.json'},
    );
    
    print('Template resource result: $result');
  } catch (e) {
    print('Template resource error: $e');
  }
}
```

## Managing Multiple MCP Clients

For more complex applications, you might need to manage multiple MCP clients:

### Registering Multiple MCP Clients

```dart
// Create LlmClient with multiple MCP clients
final llmClient = await mcpLlm.createClient(
  providerName: 'claude',
  config: LlmConfiguration(
    apiKey: 'your-claude-api-key',
    model: 'claude-3-haiku-20240307',
  ),
  mcpClients: {
    'tools': toolsClient,
    'resources': resourcesClient,
  },
  systemPrompt: 'You are a helpful assistant with access to various tools and resources.',
);
```

### Managing MCP Clients

```dart
// Add a new MCP client to an existing LlmClient
await mcpLlm.addMcpClientToLlmClient(
  'main_client',  // LlmClient ID
  'prompts',      // New MCP client ID
  promptsClient,  // MCP client instance
);

// Remove an MCP client
await mcpLlm.removeMcpClientFromLlmClient(
  'main_client',  // LlmClient ID
  'tools',        // MCP client ID to remove
);

// Set default MCP client
await mcpLlm.setDefaultMcpClient(
  'main_client',  // LlmClient ID
  'resources',    // MCP client ID to set as default
);

// Get list of registered MCP client IDs
final mcpIds = mcpLlm.getMcpClientIds('main_client');
```

## Implementing a Sample App

Let's implement a sample Flutter app that integrates `LlmClient` with `mcp_client` to create a tool-augmented AI assistant.

First, let's create an `AiService` class to handle the integration:

```dart
// lib/services/ai_service.dart
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mcp_llm/mcp_llm.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;

class AiService {
  late McpLlm _mcpLlm;
  LlmClient? _llmClient;
  mcp.Client? _mcpClient;
  final _connectionStateController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _mcpClient != null && _mcpClient!.isConnected;
  
  // Initialize service
  Future<void> initialize() async {
    try {
      // Create McpLlm instance
      _mcpLlm = McpLlm();
      _mcpLlm.registerProvider('claude', ClaudeProviderFactory());
      
      // Set up MCP client
      await _setupMcpClient();
      
      // Set up LLM client
      await _setupLlmClient();
      
      // Successfully initialized
      _connectionStateController.add(true);
    } catch (e) {
      print('AI service initialization error: $e');
      _connectionStateController.add(false);
      rethrow;
    }
  }
  
  Future<void> _setupMcpClient() async {
    final serverUrl = dotenv.env['MCP_SERVER_URL'] ?? '';
    final authToken = dotenv.env['MCP_AUTH_TOKEN'] ?? '';
    
    if (serverUrl.isEmpty || authToken.isEmpty) {
      throw Exception('Please set MCP server URL and auth token');
    }
    
    // Create MCP client
    _mcpClient = mcp.McpClient.createClient(
      name: 'flutter_app',
      version: '1.0.0',
      capabilities: mcp.ClientCapabilities(
        roots: true,
        rootsListChanged: true,
        sampling: true,
      ),
    );
    
    // Create transport
    final transport = await mcp.McpClient.createSseTransport(
      serverUrl: serverUrl,
      headers: {'Authorization': 'Bearer $authToken'},
    );
    
    // Set up event handling for connection state changes
    bool isConnectedState = false;
    
    // Handle connection state changes
    _mcpClient!.onNotification('connection_state_changed', (params) {
      final state = params['state'] as String;
      isConnectedState = state == 'connected';
      print('MCP connection state: $state');
      _connectionStateController.add(isConnectedState);
    });
    
    // Connect to server
    await _mcpClient!.connectWithRetry(
      transport,
      maxRetries: 3,
      delay: const Duration(seconds: 2),
    );
    
    // Update initial connection state
    _connectionStateController.add(true);
  }
  
  Future<void> _setupLlmClient() async {
    final apiKey = dotenv.env['CLAUDE_API_KEY'] ?? '';
    
    if (apiKey.isEmpty) {
      throw Exception('Please set Claude API key');
    }
    
    // Create LLM client
    _llmClient = await _mcpLlm.createClient(
      providerName: 'claude',
      config: LlmConfiguration(
        apiKey: apiKey,
        model: 'claude-3-haiku-20240307',
        options: {
          'temperature': 0.7,
          'max_tokens': 1500,
        },
      ),
      mcpClient: _mcpClient,
      systemPrompt: 'You are a helpful assistant with access to various tools and resources. Provide concise and accurate responses.',
    );
  }
  
  // Get available tools
  Future<List<mcp.Tool>> getAvailableTools() async {
    if (_mcpClient == null || !isConnected) {
      throw Exception('MCP client is not connected');
    }
    
    return await _mcpClient!.listTools();
  }
  
  // Chat with AI (with tools enabled)
  Future<LlmResponse> chat(String message, {bool enableTools = true}) async {
    if (_llmClient == null) {
      throw Exception('LLM client not initialized');
    }
    
    return await _llmClient!.chat(
      message,
      enableTools: enableTools,
    );
  }
  
  // Stream chat responses
  Stream<dynamic> streamChat(String message, {bool enableTools = true}) {
    if (_llmClient == null) {
      throw Exception('LLM client not initialized');
    }
    
    return _llmClient!.streamChat(
      message,
      enableTools: enableTools,
    );
  }
  
  // Execute tool directly
  Future<dynamic> executeTool(String toolName, Map<String, dynamic> arguments) async {
    if (_llmClient == null) {
      throw Exception('LLM client not initialized');
    }
    
    return await _llmClient!.executeTool(
      toolName,
      arguments,
    );
  }
  
  // Get resource
  Future<dynamic> getResource(String resourceName, {Map<String, dynamic>? params}) async {
    if (_mcpClient == null || !isConnected) {
      throw Exception('MCP client is not connected');
    }
    
    return await _mcpClient!.readResource(resourceName);
  }
  
  // Get resource with template
  Future<dynamic> getResourceWithTemplate(String templateUri, Map<String, dynamic> params) async {
    if (_mcpClient == null || !isConnected) {
      throw Exception('MCP client is not connected');
    }
    
    return await _mcpClient!.getResourceWithTemplate(templateUri, params);
  }
  
  // Cleanup
  Future<void> dispose() async {
    await _mcpLlm.shutdown();
    _connectionStateController.close();
  }
}
```

Next, let's create a simple chat UI that uses this service:

```dart
// lib/main.dart
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
```

This sample application demonstrates the key capabilities of the integration:

1. Connection to an MCP server and displaying available tools
2. Chatting with AI with tool usage enabled
3. Streaming responses
4. Direct tool calls with the `/tool` command
5. Display of tool call information
6. Connection status indicator

## Next Steps

After mastering the integration between `LlmClient` and `mcp_client`, consider exploring these advanced topics:

1. **LlmServer and mcp_server Integration**: Learn how to provide AI capabilities as a service.
2. **Multiple LLM Provider Integration**: Leverage different AI models (Claude, GPT, etc.) with MCP ecosystem.
3. **MCP Plugin System**: Develop custom tools and resources as plugins.
4. **Distributed MCP Environments**: Build complex systems with multiple MCP clients and servers.
5. **Building MCP-based RAG Systems**: Implement knowledge-based AI systems with document retrieval.

The integration between `LlmClient` and `mcp_client` opens up numerous possibilities for building AI-powered Flutter applications that can interact with external tools and resources. This approach transforms AI from simple text generation to a genuine interactive system that can perform real-world tasks.

---

## Resources

- [mcp_llm_client_integration Sample App Repository](https://github.com/MCP-Dev-Studio/mcp_llm_client_integration)
- [mcp_client GitHub Repository](https://github.com/app-appplayer/mcp_client)
- [mcp_llm GitHub Repository](https://github.com/app-appplayer/mcp_llm)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Claude API Documentation](https://docs.anthropic.com/)
- [Flutter Documentation](https://flutter.dev/docs)

---

### Support the Developer

If you found this article helpful, please consider supporting the development of more free content through Patreon. Your support makes a big difference!

[![Support on Patreon](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://www.patreon.com/mcpdevstudio)

**Tags**: #Flutter #AI #MCP #LLM #Dart #Claude #OpenAI #ModelContextProtocol #AIIntegration #mcp_client #LlmClient