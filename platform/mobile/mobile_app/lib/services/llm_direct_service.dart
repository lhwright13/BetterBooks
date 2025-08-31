/**
 * llm_direct_service.dart - Direct LLM Gateway communication for MVP
 * 
 * This file provides direct communication with the LLM Gateway in Azure cloud
 * bypassing the API Gateway for MVP testing. This is a workaround to enable
 * AI chat functionality while the API Gateway proxy is being fixed.
 * 
 * Key responsibilities:
 * - Connect directly to LLM Gateway at 172.212.125.29:8002 (Azure LoadBalancer)
 * - Load available AI personas from cloud persona configs
 * - Send chat messages and receive AI responses
 * - Handle network errors and provide fallback responses
 * 
 * This approach works completely in the cloud - no laptop required.
 * Should be replaced with proper API Gateway routing in production.
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/persona.dart';
import 'log_service.dart';

/// Direct LLM Gateway communication service for MVP testing
class LlmDirectService {
  // Direct connection to LLM Gateway in Azure cloud
  static const String _llmBaseUrl = 'http://172.212.125.29:8002';
  static const Duration _timeoutDuration = Duration(seconds: 30);

  /// Load available AI personas directly from LLM Gateway
  /// Returns a list of Persona objects configured on the LLM Gateway
  static Future<List<Persona>> getPersonas() async {
    try {
      LogService.api('GET', '$_llmBaseUrl/configs');
      final response = await http.get(
        Uri.parse('$_llmBaseUrl/configs'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeoutDuration);

      LogService.api('GET', '$_llmBaseUrl/configs', statusCode: response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final configNames = data['configs'] as List;
        
        return configNames.map((configName) {
          String displayName = _formatPersonaName(configName.toString());
          String description = _getPersonaDescription(configName.toString());
          
          return Persona(
            name: configName.toString(),
            displayName: displayName,
            description: description,
            voice: 'en-US-Neural2-C',
            voiceConfig: {},
          );
        }).toList();
      } else {
        throw Exception('Failed to load personas: ${response.statusCode}');
      }
    } catch (e) {
      LogService.api('GET', '$_llmBaseUrl/configs', error: e.toString());
      
      // Return fallback personas for MVP testing
      return _getFallbackPersonas();
    }
  }

  /// Send a chat message directly to LLM Gateway
  /// Returns the AI's response text using the specified persona
  static Future<String> sendMessage(String message, String persona) async {
    try {
      LogService.api('POST', '$_llmBaseUrl/complete');
      
      // Format the prompt to include persona context
      String contextualPrompt = _buildPersonaPrompt(message, persona);
      
      final response = await http.post(
        Uri.parse('$_llmBaseUrl/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': contextualPrompt,
          'persona': persona,
        }),
      ).timeout(_timeoutDuration);

      LogService.api('POST', '$_llmBaseUrl/complete', statusCode: response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['text'] ?? data['response'] ?? 'No response received';
      } else if (response.statusCode == 502 || response.statusCode == 400) {
        // LLM Gateway is running but API key invalid - use fallback for MVP
        LogService.api('POST', '$_llmBaseUrl/complete', error: 'Invalid API key, using fallback response');
        return _getFallbackResponse(message, persona);
      } else {
        throw Exception('Failed to send message: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      LogService.api('POST', '$_llmBaseUrl/complete', error: e.toString());
      
      // Return fallback response for MVP testing
      return _getFallbackResponse(message, persona);
    }
  }

  /// Test connection to LLM Gateway
  /// Returns true if the service is reachable
  static Future<bool> testConnection() async {
    try {
      LogService.api('GET', '$_llmBaseUrl/health');
      final response = await http.get(
        Uri.parse('$_llmBaseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      LogService.api('GET', '$_llmBaseUrl/health', statusCode: response.statusCode);
      return response.statusCode == 200;
    } catch (e) {
      LogService.api('GET', '$_llmBaseUrl/health', error: e.toString());
      return false;
    }
  }

  /// Format persona name for display
  static String _formatPersonaName(String configName) {
    switch (configName.toLowerCase()) {
      case 'nick carraway':
        return 'Nick Carraway';
      case 'english teacher':
        return 'English Teacher';
      case 'language tutor':
        return 'Language Tutor';
      case 'omniscient helper':
        return 'Omniscient Helper';
      default:
        return configName.split(' ').map((word) => 
          word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
        ).join(' ');
    }
  }

  /// Get persona description for UI display
  static String _getPersonaDescription(String configName) {
    switch (configName.toLowerCase()) {
      case 'nick carraway':
        return 'The narrator of The Great Gatsby - observant and literary';
      case 'english teacher':
        return 'Encouraging guide for literary analysis and discussion';
      case 'language tutor':
        return 'Patient instructor for language learning and practice';
      case 'omniscient helper':
        return 'Knowledgeable assistant for general questions and guidance';
      default:
        return 'AI assistant persona: $configName';
    }
  }

  /// Build a contextual prompt including persona instructions
  static String _buildPersonaPrompt(String message, String persona) {
    // For MVP, add basic persona context
    switch (persona.toLowerCase()) {
      case 'nick carraway':
        return 'You are Nick Carraway from The Great Gatsby. Respond in character as the observant narrator from 1922. User asks: $message';
      case 'english teacher':
        return 'You are an encouraging English teacher helping analyze literature. Guide the student with thoughtful questions. User asks: $message';
      case 'language tutor':
        return 'You are a patient language tutor helping with learning. Provide clear explanations and encouragement. User asks: $message';
      case 'omniscient helper':
        return 'You are a knowledgeable assistant ready to help with any question. User asks: $message';
      default:
        return message;
    }
  }

  /// Provide fallback personas for offline testing
  static List<Persona> _getFallbackPersonas() {
    return [
      Persona(
        name: 'Nick Carraway',
        displayName: 'Nick Carraway',
        description: 'The narrator of The Great Gatsby - observant and literary',
        voice: 'en-US-Neural2-J',
        voiceConfig: {},
      ),
      Persona(
        name: 'English Teacher',
        displayName: 'English Teacher',
        description: 'Encouraging guide for literary analysis and discussion',
        voice: 'en-US-Neural2-C',
        voiceConfig: {},
      ),
      Persona(
        name: 'Language Tutor',
        displayName: 'Language Tutor',
        description: 'Patient instructor for language learning and practice',
        voice: 'en-US-Neural2-F',
        voiceConfig: {},
      ),
      Persona(
        name: 'Omniscient Helper',
        displayName: 'Omniscient Helper',
        description: 'Knowledgeable assistant for general questions and guidance',
        voice: 'en-US-Neural2-A',
        voiceConfig: {},
      ),
    ];
  }

  /// Provide fallback AI responses for testing
  static String _getFallbackResponse(String message, String persona) {
    switch (persona.toLowerCase()) {
      case 'nick carraway':
        return 'Well, old sport, that\'s quite an interesting observation. From my vantage point here in West Egg, I\'ve seen many curious things. What you mention reminds me of something I witnessed at one of Gatsby\'s grand soirées...';
      case 'english teacher':
        return 'That\'s a thoughtful question! Let\'s explore this idea together. What themes do you notice emerging in this passage? Think about how the author uses literary devices to convey meaning.';
      case 'language tutor':
        return 'Excellent question! Let me help you understand this concept step by step. Remember, learning a language is about practice and patience. Would you like me to break this down further?';
      case 'omniscient helper':
        return 'I understand what you\'re asking about. This is an interesting topic that connects to several important concepts. Let me share some insights that might be helpful...';
      default:
        return 'Thank you for your message. I\'m here to help and would be happy to discuss this topic with you. What specific aspect would you like to explore?';
    }
  }
}