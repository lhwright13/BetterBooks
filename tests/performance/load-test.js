// K6 Load Testing Script for EchoWright Platform
// Tests critical API endpoints under various load scenarios

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
export const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 }, // Ramp up to 10 users
    { duration: '5m', target: 10 }, // Stay at 10 users
    { duration: '2m', target: 20 }, // Ramp up to 20 users
    { duration: '5m', target: 20 }, // Stay at 20 users
    { duration: '2m', target: 0 },  // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.05'],   // Error rate should be less than 5%
    errors: ['rate<0.1'],             // Custom error rate should be less than 10%
  },
};

const API_BASE_URL = __ENV.API_BASE_URL || 'http://localhost:8000';

// Test data
const testMessages = [
  'What are the main themes in this chapter?',
  'Can you summarize what just happened?',
  'Who are the key characters introduced?',
  'What is the significance of this scene?',
  'How does this relate to earlier chapters?',
];

const testChapterData = {
  title: 'Test Chapter',
  content: 'This is a test chapter content for load testing purposes. It contains various themes and characters that can be analyzed by the AI system.',
  start_time: 0,
  end_time: 300,
  book_id: 'test-book-123'
};

export default function () {
  // Test 1: Health Check
  let response = http.get(`${API_BASE_URL}/health`);
  check(response, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 100ms': (r) => r.timings.duration < 100,
  }) || errorRate.add(1);

  sleep(1);

  // Test 2: Detailed Health Check
  response = http.get(`${API_BASE_URL}/health/detailed`);
  check(response, {
    'detailed health check status is 200': (r) => r.status === 200,
    'detailed health check response time < 200ms': (r) => r.timings.duration < 200,
  }) || errorRate.add(1);

  sleep(1);

  // Test 3: LLM Gateway Chat Completion
  const chatPayload = {
    messages: [
      { role: 'user', content: testMessages[Math.floor(Math.random() * testMessages.length)] }
    ],
    persona: 'test',
    max_tokens: 150
  };

  response = http.post(
    `${API_BASE_URL}/api/v1/llm/chat/completions`,
    JSON.stringify(chatPayload),
    {
      headers: { 'Content-Type': 'application/json' },
    }
  );

  check(response, {
    'chat completion status is 200': (r) => r.status === 200,
    'chat completion response time < 2000ms': (r) => r.timings.duration < 2000,
    'chat completion has content': (r) => {
      try {
        const json = JSON.parse(r.body);
        return json.choices && json.choices[0] && json.choices[0].message.content;
      } catch (e) {
        return false;
      }
    },
  }) || errorRate.add(1);

  sleep(2);

  // Test 4: Context Service Embedding
  const embeddingPayload = {
    text: `Test embedding text for performance testing. ${Math.random()}`,
    metadata: { test: true, timestamp: new Date().toISOString() }
  };

  response = http.post(
    `${API_BASE_URL}/api/v1/context/embeddings`,
    JSON.stringify(embeddingPayload),
    {
      headers: { 'Content-Type': 'application/json' },
    }
  );

  check(response, {
    'embedding creation status is 200': (r) => r.status === 200,
    'embedding creation response time < 1000ms': (r) => r.timings.duration < 1000,
  }) || errorRate.add(1);

  sleep(1);

  // Test 5: TTS Service Synthesis
  const ttsPayload = {
    text: 'This is a test text for speech synthesis performance testing.',
    voice: 'default',
    speed: 1.0
  };

  response = http.post(
    `${API_BASE_URL}/api/v1/tts/synthesize`,
    JSON.stringify(ttsPayload),
    {
      headers: { 'Content-Type': 'application/json' },
    }
  );

  check(response, {
    'tts synthesis status is 200': (r) => r.status === 200,
    'tts synthesis response time < 3000ms': (r) => r.timings.duration < 3000,
  }) || errorRate.add(1);

  sleep(2);

  // Test 6: Transcription Service Summary Styles
  response = http.get(`${API_BASE_URL}/api/v1/transcription/summary-styles`);
  check(response, {
    'summary styles status is 200': (r) => r.status === 200,
    'summary styles response time < 100ms': (r) => r.timings.duration < 100,
  }) || errorRate.add(1);

  // Test 7: Chapter Summary Generation
  const summaryPayload = {
    chapters: [testChapterData],
    summary_styles: ['brief', 'detailed']
  };

  response = http.post(
    `${API_BASE_URL}/api/v1/transcription/generate-summaries`,
    JSON.stringify(summaryPayload),
    {
      headers: { 'Content-Type': 'application/json' },
    }
  );

  check(response, {
    'summary generation status is 200': (r) => r.status === 200,
    'summary generation response time < 5000ms': (r) => r.timings.duration < 5000,
  }) || errorRate.add(1);

  sleep(3);

  // Test 8: Question Generation
  const questionPayload = {
    chapter_text: testChapterData.content,
    question_types: ['comprehension', 'analysis'],
    difficulty_level: 'intermediate',
    reading_mode: 'educational',
    num_questions: 3
  };

  response = http.post(
    `${API_BASE_URL}/api/v1/transcription/generate-questions`,
    JSON.stringify(questionPayload),
    {
      headers: { 'Content-Type': 'application/json' },
    }
  );

  check(response, {
    'question generation status is 200': (r) => r.status === 200,
    'question generation response time < 4000ms': (r) => r.timings.duration < 4000,
  }) || errorRate.add(1);

  sleep(2);

  // Test 9: Metrics Endpoint
  response = http.get(`${API_BASE_URL}/metrics`);
  check(response, {
    'metrics endpoint status is 200': (r) => r.status === 200,
    'metrics endpoint response time < 500ms': (r) => r.timings.duration < 500,
  }) || errorRate.add(1);

  sleep(1);
}

export function teardown(data) {
  console.log('Load test completed');
  console.log(`Error rate: ${errorRate.rate * 100}%`);
}