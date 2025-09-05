# User Interaction Plan for our voice chat

multi-modal model (**GPT-4o**) that processes audio input directly and responds quickly, creating a fluid, back-and-forth dialogue.  

This document breaks down the **user interaction flow** and **UI design elements** that you can emulate in a Flutter app.

---

## User Interaction Flow

1. **Initiating a Conversation**  
   - The user taps a prominent **microphone icon**, bottom of the screen, to begin speaking.  
   - A single tap minimizes friction and indicates the app is ready to listen.
   - This chat icon should be present in the bottom bar of the listen page
   - There should be a drop down menu where you can select the persona you art chatting with.

2. **Visual Feedback for Listening**  
   - A **visual indicator** confirms the app is listening.  
   - represented by a **pulsating, animated orb** The cover should morph from a square to a circle and blur to 70%
   - This reassures the user that the app is active and processing input.

3. **Real-Time Transcription and Processing**  
   - Spoken words are **transcribed** and are viewable by the user in the text chat page.
   - The AI processes audio input directly, understanding context, pauses, tone, and emotion.

4. **Interruption and Turn-Taking**  
   - The AI can be **interrupted mid-sentence**.  
   - If the user speaks, the AI stops and begins processing the new input immediately.  
   - This creates a **natural, dynamic conversation flow**.

5. **Speaking the Response**  
   - The AI responds in a **natural voice** using Text-to-Speech (TTS).  
   - Playback is smooth and low-latency, avoiding awkward delays.

6. **Continuous Listening**  
   - After speaking, the AI immediately starts listening again for follow-ups.  
   - Removes the need to repeatedly tap the microphone.
   - this will be a configurable setting in the voice query settings (return to story or wait for follow up question)

7. **Ending the Conversation**  
   - The user can tap the microphone icon again to **end voice mode**.  
   - The system also **times out after silence**, reverting to the standard chat interface.

---

## UI Design Elements for Flutter

### Core Interface

- **Microphone Button**
  - Button on the bottom bar on the listening page and button present on the mini player/now playing bar
    - persistent bottom sheet when activley listening to a book
  - **Initial state:** static microphone icon.  
  - pressing the button should bring you to the listening page and transform the cover to our circle voice animation.

- **Transcript Display**
  - past conversations show up in chat, the user can also use this chat to write text querys to the model

### Animation and Feedback

- **Audio Waveform**   
  - circle should respond to user voice and its own talking voice via expanding and contracting with the voice waveform
  - Subtle, expanding circle during processing/output. 
    - Provides a **visual signal** that the AI is thinking or responding.

---

## Integration Points in Flutter

To replicate this experience, integrate the following:

- **Speech-to-Text (STT):**  
  Use [`speech_to_text`](https://pub.dev/packages/speech_to_text) to capture voice input.

- **Text-to-Speech (TTS):**  
  - Use [`flutter_tts`](https://pub.dev/packages/flutter_tts) for AI voice playback.
  - also leave room for backend proc in the future. We will move to an end to end audio model

- **Real-Time Feedback:**  
  Leverage Flutter’s **animation system** (e.g., `AnimationController`) to create responsive UI tied to audio events.

---
