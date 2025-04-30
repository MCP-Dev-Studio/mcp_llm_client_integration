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