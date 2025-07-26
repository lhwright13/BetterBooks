# Customization Guide

This document explains where to add or modify code in order to extend BetterBooks.

## 1. Design the UI

The Flutter application lives under `mobile_app/`. Edit `lib/main.dart` or add new widgets under `lib/` to design the interface. The project was generated with `flutter create` and can be modified like any standard Flutter app.

## 2. Experiment with different language models

The service responsible for interacting with the language model is `services/llm_gateway`. Modify `main.py` or replace the OpenAI client with a different provider to try other models. The API Gateway forwards `/complete` requests directly to this service.

## 3. Change the preprompt

A preprompt can be injected before the user prompt inside `services/llm_gateway/main.py`. Insert custom logic in the `complete` endpoint to prepend your preprompt to `req.prompt` before sending the request to the LLM.

## 4. Change how the story is read to the user

Text-to-speech is handled by `services/tts_service`. Update `main.py` to load a different TTS model or adjust audio processing. The mobile app retrieves audio from the `/synthesize` endpoint.

## 5. Collect model inputs and outputs

Add logging or database writes inside the API Gateway or LLM Gateway services. For example, update `services/api_gateway/main.py` to store the prompt and response in a database for later analysis.

## 6. Include audio files and EPUBs with a custom preprompt

Additional content can be stored and served from a new service or an extension of the Context Service. You might create a directory such as `content/` to keep audio files and EPUBs, along with metadata that includes a custom preprompt for each item.

