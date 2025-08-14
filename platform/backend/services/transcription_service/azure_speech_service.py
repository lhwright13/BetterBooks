"""Azure Speech Service implementation for transcription."""

import os
import io
import logging
import asyncio
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
import azure.cognitiveservices.speech as speechsdk
from azure.cognitiveservices.speech.audio import AudioConfig, AudioStreamFormat, PushAudioInputStream

logger = logging.getLogger(__name__)

@dataclass
class AzureSpeechConfig:
    """Configuration for Azure Speech Service."""
    api_key: str
    region: str
    language: str = "en-US"
    profanity_filter: bool = False
    enable_dictation: bool = True
    enable_punctuation: bool = True
    
    @classmethod
    def from_env(cls) -> "AzureSpeechConfig":
        """Create config from environment variables."""
        return cls(
            api_key=os.getenv("AZURE_SPEECH_KEY", ""),
            region=os.getenv("AZURE_SPEECH_REGION", "eastus"),
            language=os.getenv("AZURE_SPEECH_LANGUAGE", "en-US"),
            profanity_filter=os.getenv("AZURE_SPEECH_PROFANITY_FILTER", "false").lower() == "true",
            enable_dictation=os.getenv("AZURE_SPEECH_ENABLE_DICTATION", "true").lower() == "true",
            enable_punctuation=os.getenv("AZURE_SPEECH_ENABLE_PUNCTUATION", "true").lower() == "true"
        )


class AzureSpeechService:
    """Azure Speech Service for audio transcription."""
    
    def __init__(self, config: Optional[AzureSpeechConfig] = None):
        """Initialize Azure Speech Service.
        
        Args:
            config: Azure Speech configuration. If None, loads from environment.
        """
        self.config = config or AzureSpeechConfig.from_env()
        
        if not self.config.api_key:
            raise ValueError("Azure Speech API key is required. Set AZURE_SPEECH_KEY environment variable.")
        
        # Create speech config
        self.speech_config = speechsdk.SpeechConfig(
            subscription=self.config.api_key,
            region=self.config.region
        )
        
        # Set speech recognition language
        self.speech_config.speech_recognition_language = self.config.language
        
        # Configure service properties
        if self.config.enable_dictation:
            self.speech_config.enable_dictation()
        
        # Set output format to include detailed results
        self.speech_config.output_format = speechsdk.OutputFormat.Detailed
        
        # Configure profanity filter
        if not self.config.profanity_filter:
            self.speech_config.set_profanity(speechsdk.ProfanityOption.Raw)
        
        logger.info(f"Azure Speech Service initialized for region: {self.config.region}, language: {self.config.language}")
    
    async def transcribe_audio_file(self, file_path: str) -> Dict[str, Any]:
        """Transcribe an audio file.
        
        Args:
            file_path: Path to the audio file.
            
        Returns:
            Transcription result with text and metadata.
        """
        try:
            # Create audio config from file
            audio_config = AudioConfig(filename=file_path)
            
            # Create speech recognizer
            recognizer = speechsdk.SpeechRecognizer(
                speech_config=self.speech_config,
                audio_config=audio_config
            )
            
            # Perform continuous recognition
            result = await self._continuous_recognition(recognizer)
            
            return result
            
        except Exception as e:
            logger.error(f"Error transcribing audio file: {e}")
            raise
    
    async def transcribe_audio_stream(self, audio_data: bytes, audio_format: Dict[str, Any]) -> Dict[str, Any]:
        """Transcribe audio from a byte stream.
        
        Args:
            audio_data: Audio data as bytes.
            audio_format: Audio format information (sample_rate, channels, bits_per_sample).
            
        Returns:
            Transcription result with text and metadata.
        """
        try:
            # Create push stream for audio data
            stream_format = AudioStreamFormat(
                samples_per_second=audio_format.get("sample_rate", 16000),
                bits_per_sample=audio_format.get("bits_per_sample", 16),
                channels=audio_format.get("channels", 1)
            )
            
            push_stream = PushAudioInputStream(stream_format)
            audio_config = AudioConfig(stream=push_stream)
            
            # Create speech recognizer
            recognizer = speechsdk.SpeechRecognizer(
                speech_config=self.speech_config,
                audio_config=audio_config
            )
            
            # Push audio data to stream
            push_stream.write(audio_data)
            push_stream.close()
            
            # Perform continuous recognition
            result = await self._continuous_recognition(recognizer)
            
            return result
            
        except Exception as e:
            logger.error(f"Error transcribing audio stream: {e}")
            raise
    
    async def _continuous_recognition(self, recognizer: speechsdk.SpeechRecognizer) -> Dict[str, Any]:
        """Perform continuous recognition on audio.
        
        Args:
            recognizer: Configured speech recognizer.
            
        Returns:
            Complete transcription result.
        """
        transcribed_text = []
        word_timestamps = []
        recognition_done = asyncio.Event()
        
        def handle_recognized(evt):
            """Handle recognized speech."""
            if evt.result.reason == speechsdk.ResultReason.RecognizedSpeech:
                transcribed_text.append(evt.result.text)
                
                # Extract word-level timestamps if available
                if hasattr(evt.result, 'offset') and hasattr(evt.result, 'duration'):
                    word_data = {
                        "text": evt.result.text,
                        "offset_ms": evt.result.offset / 10000,  # Convert to milliseconds
                        "duration_ms": evt.result.duration / 10000
                    }
                    word_timestamps.append(word_data)
                    
                logger.debug(f"Recognized: {evt.result.text}")
            elif evt.result.reason == speechsdk.ResultReason.NoMatch:
                logger.warning(f"No speech could be recognized: {evt.result.no_match_details}")
        
        def handle_canceled(evt):
            """Handle recognition cancellation."""
            if evt.reason == speechsdk.CancellationReason.Error:
                logger.error(f"Recognition canceled: {evt.error_details}")
            recognition_done.set()
        
        def handle_session_stopped(evt):
            """Handle session stop."""
            logger.info("Recognition session stopped")
            recognition_done.set()
        
        # Connect callbacks
        recognizer.recognized.connect(handle_recognized)
        recognizer.canceled.connect(handle_canceled)
        recognizer.session_stopped.connect(handle_session_stopped)
        
        # Start continuous recognition
        await asyncio.get_event_loop().run_in_executor(
            None, recognizer.start_continuous_recognition
        )
        
        # Wait for recognition to complete
        await recognition_done.wait()
        
        # Stop recognition
        await asyncio.get_event_loop().run_in_executor(
            None, recognizer.stop_continuous_recognition
        )
        
        # Compile results
        result = {
            "text": " ".join(transcribed_text),
            "segments": transcribed_text,
            "word_timestamps": word_timestamps,
            "language": self.config.language,
            "service": "azure",
            "metadata": {
                "region": self.config.region,
                "language": self.config.language,
                "punctuation_enabled": self.config.enable_punctuation,
                "dictation_enabled": self.config.enable_dictation
            }
        }
        
        return result
    
    async def transcribe_with_translation(
        self, 
        audio_data: bytes, 
        audio_format: Dict[str, Any],
        target_languages: List[str]
    ) -> Dict[str, Any]:
        """Transcribe audio and translate to multiple languages.
        
        Args:
            audio_data: Audio data as bytes.
            audio_format: Audio format information.
            target_languages: List of target language codes for translation.
            
        Returns:
            Transcription and translation results.
        """
        try:
            # First transcribe the audio
            transcription = await self.transcribe_audio_stream(audio_data, audio_format)
            
            # Create translation config
            translation_config = speechsdk.translation.SpeechTranslationConfig(
                subscription=self.config.api_key,
                region=self.config.region
            )
            
            translation_config.speech_recognition_language = self.config.language
            
            # Add target languages
            for lang in target_languages:
                translation_config.add_target_language(lang)
            
            # Create push stream for audio data
            stream_format = AudioStreamFormat(
                samples_per_second=audio_format.get("sample_rate", 16000),
                bits_per_sample=audio_format.get("bits_per_sample", 16),
                channels=audio_format.get("channels", 1)
            )
            
            push_stream = PushAudioInputStream(stream_format)
            audio_config = AudioConfig(stream=push_stream)
            
            # Create translation recognizer
            recognizer = speechsdk.translation.TranslationRecognizer(
                translation_config=translation_config,
                audio_config=audio_config
            )
            
            # Push audio data
            push_stream.write(audio_data)
            push_stream.close()
            
            # Perform recognition
            result = await asyncio.get_event_loop().run_in_executor(
                None, recognizer.recognize_once
            )
            
            translations = {}
            if result.reason == speechsdk.ResultReason.TranslatedSpeech:
                for lang in target_languages:
                    translations[lang] = result.translations.get(lang, "")
            
            return {
                "transcription": transcription,
                "translations": translations
            }
            
        except Exception as e:
            logger.error(f"Error in transcription with translation: {e}")
            raise
    
    def get_supported_languages(self) -> List[str]:
        """Get list of supported languages for speech recognition.
        
        Returns:
            List of language codes.
        """
        # Common Azure Speech Service supported languages
        return [
            "en-US", "en-GB", "en-AU", "en-CA", "en-IN",
            "es-ES", "es-MX", "fr-FR", "de-DE", "it-IT",
            "ja-JP", "ko-KR", "zh-CN", "zh-TW", "pt-BR",
            "ru-RU", "ar-SA", "hi-IN", "nl-NL", "sv-SE"
        ]
    
    async def detect_language(self, audio_data: bytes, audio_format: Dict[str, Any]) -> str:
        """Detect the language of the audio.
        
        Args:
            audio_data: Audio data as bytes.
            audio_format: Audio format information.
            
        Returns:
            Detected language code.
        """
        try:
            # Create auto-detect language config
            auto_detect_config = speechsdk.languageconfig.AutoDetectSourceLanguageConfig(
                languages=["en-US", "es-ES", "fr-FR", "de-DE", "zh-CN"]
            )
            
            # Create push stream
            stream_format = AudioStreamFormat(
                samples_per_second=audio_format.get("sample_rate", 16000),
                bits_per_sample=audio_format.get("bits_per_sample", 16),
                channels=audio_format.get("channels", 1)
            )
            
            push_stream = PushAudioInputStream(stream_format)
            audio_config = AudioConfig(stream=push_stream)
            
            # Create speech recognizer with auto-detect
            recognizer = speechsdk.SpeechRecognizer(
                speech_config=self.speech_config,
                audio_config=audio_config,
                auto_detect_source_language_config=auto_detect_config
            )
            
            # Push audio data
            push_stream.write(audio_data)
            push_stream.close()
            
            # Recognize once to detect language
            result = await asyncio.get_event_loop().run_in_executor(
                None, recognizer.recognize_once
            )
            
            if result.reason == speechsdk.ResultReason.RecognizedSpeech:
                # Extract detected language from result
                detected_language = result.properties.get(
                    speechsdk.PropertyId.SpeechServiceConnection_AutoDetectSourceLanguageResult,
                    "unknown"
                )
                return detected_language
            
            return "unknown"
            
        except Exception as e:
            logger.error(f"Error detecting language: {e}")
            return "unknown"