"""
Audio Processing Pipeline for EchoWright Platform

Advanced audio processing infrastructure for real-time streaming, voice chat,
chapter detection, and audio optimization for the AI-powered audiobook platform.

Features:
- Real-time TTS streaming with chunked delivery
- Voice input processing for AI persona conversations
- Chapter boundary detection using silence analysis
- Audio compression and optimization for mobile
- Audio caching with Redis for performance
- WebSocket support for real-time communication
- Voice activity detection (VAD)
- Noise reduction and audio enhancement
- Format conversion and transcoding
"""

import asyncio
import io
import time
import json
import logging
import base64
import hashlib
from typing import Dict, Any, List, Optional, AsyncIterator, Tuple, Union, Callable
from enum import Enum
from dataclasses import dataclass, field
from pathlib import Path
import wave
import struct

# Audio processing libraries
import numpy as np
try:
    import librosa
    import soundfile as sf
    LIBROSA_AVAILABLE = True
except ImportError:
    LIBROSA_AVAILABLE = False
    logging.warning("librosa not available - advanced audio features disabled")

try:
    import webrtcvad
    VAD_AVAILABLE = True
except ImportError:
    VAD_AVAILABLE = False
    logging.warning("webrtcvad not available - voice activity detection disabled")

import redis
from fastapi import WebSocket, HTTPException
from starlette.websockets import WebSocketDisconnect

from core.infrastructure.metrics import Counter, Gauge, Histogram
from core.infrastructure.semantic_cache import SemanticCache, CacheType

logger = logging.getLogger(__name__)


class AudioFormat(Enum):
    """Supported audio formats."""
    WAV = "wav"
    MP3 = "mp3"
    OGG = "ogg"
    FLAC = "flac"
    WEBM = "webm"
    AAC = "aac"


class StreamingQuality(Enum):
    """Streaming quality levels for different use cases."""
    LOW = "low"          # 32kbps, 16kHz - voice chat
    MEDIUM = "medium"    # 64kbps, 22kHz - standard streaming
    HIGH = "high"        # 128kbps, 44kHz - high quality audio
    PREMIUM = "premium"  # 256kbps, 48kHz - premium experience


class ProcessingMode(Enum):
    """Audio processing modes."""
    STREAMING = "streaming"       # Real-time streaming
    BATCH = "batch"              # Offline processing
    VOICE_CHAT = "voice_chat"    # Voice conversation
    TRANSCRIPTION = "transcription" # Speech-to-text


@dataclass
class AudioConfig:
    """Configuration for audio processing."""
    sample_rate: int = 22050
    channels: int = 1  # Mono for most use cases
    bit_depth: int = 16
    format: AudioFormat = AudioFormat.WAV
    quality: StreamingQuality = StreamingQuality.MEDIUM
    chunk_size: int = 1024  # Samples per chunk
    buffer_size: int = 8192  # Buffer size for streaming


@dataclass
class ChapterMarker:
    """Chapter boundary detected in audio."""
    start_time: float  # Seconds
    end_time: Optional[float] = None
    title: Optional[str] = None
    confidence: float = 0.0  # Detection confidence (0-1)
    silence_duration: float = 0.0  # Silence duration in seconds


@dataclass
class AudioChunk:
    """Individual audio chunk for streaming."""
    data: bytes
    timestamp: float
    sequence: int
    format: AudioFormat
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class VoiceActivity:
    """Voice activity detection result."""
    is_speech: bool
    confidence: float
    start_time: float
    end_time: float


class AudioProcessor:
    """
    High-performance audio processing pipeline for EchoWright.
    
    Handles real-time streaming, voice processing, chapter detection,
    and audio optimization with caching and quality adaptation.
    """
    
    def __init__(
        self,
        redis_client: redis.Redis,
        cache: Optional[SemanticCache] = None,
        config: Optional[AudioConfig] = None
    ):
        """
        Initialize audio processor.
        
        Args:
            redis_client: Redis client for caching and buffering
            cache: Semantic cache for audio content
            config: Audio processing configuration
        """
        self.redis = redis_client
        self.cache = cache
        self.config = config or AudioConfig()
        
        # Initialize VAD if available
        self.vad = None
        if VAD_AVAILABLE:
            try:
                self.vad = webrtcvad.Vad(2)  # Aggressiveness level 0-3
            except Exception as e:
                logger.warning(f"Failed to initialize VAD: {e}")
        
        # Streaming sessions
        self.active_streams: Dict[str, Dict[str, Any]] = {}
        
        # Set up metrics
        self._setup_metrics()
        
        logger.info("Audio processor initialized", 
                   vad_available=VAD_AVAILABLE,
                   librosa_available=LIBROSA_AVAILABLE)
    
    def _setup_metrics(self):
        """Set up Prometheus metrics for audio processing."""
        self.audio_chunks_processed = Counter(
            'audio_chunks_processed_total',
            'Total audio chunks processed',
            ['format', 'quality', 'mode']
        )
        
        self.streaming_sessions = Gauge(
            'audio_streaming_sessions_active',
            'Number of active audio streaming sessions'
        )
        
        self.processing_duration = Histogram(
            'audio_processing_duration_seconds',
            'Time spent processing audio',
            ['operation', 'format'],
            buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0)
        )
        
        self.cache_hit_ratio = Gauge(
            'audio_cache_hit_ratio',
            'Audio cache hit ratio'
        )
        
        self.voice_activity_detected = Counter(
            'voice_activity_detected_total',
            'Voice activity detection events',
            ['result']  # speech, silence, unknown
        )
        
        self.chapter_detections = Counter(
            'chapter_detections_total',
            'Chapter boundary detections',
            ['confidence_level']  # high, medium, low
        )
    
    async def stream_tts_audio(
        self,
        text: str,
        voice_config: Dict[str, Any],
        websocket: WebSocket,
        session_id: str
    ) -> None:
        """
        Stream TTS audio in real-time chunks.
        
        Args:
            text: Text to synthesize
            voice_config: Voice configuration (persona, speed, etc.)
            websocket: WebSocket connection for streaming
            session_id: Unique session identifier
        """
        start_time = time.time()
        
        try:
            # Register streaming session
            self.active_streams[session_id] = {
                "start_time": start_time,
                "text": text,
                "voice_config": voice_config,
                "websocket": websocket,
                "chunks_sent": 0,
                "bytes_sent": 0
            }
            
            self.streaming_sessions.inc()
            
            # Check cache first
            cache_key = self._generate_audio_cache_key(text, voice_config)
            cached_audio = await self._get_cached_audio(cache_key)
            
            if cached_audio:
                # Stream cached audio
                logger.info(f"Streaming cached audio for session {session_id}")
                await self._stream_cached_audio(cached_audio, websocket, session_id)
                self.cache_hit_ratio.set(1.0)  # Cache hit
            else:
                # Generate and stream new audio
                logger.info(f"Generating new TTS audio for session {session_id}")
                audio_data = await self._generate_tts_audio(text, voice_config)
                
                # Cache the generated audio
                await self._cache_audio(cache_key, audio_data)
                
                # Stream the audio
                await self._stream_audio_chunks(audio_data, websocket, session_id)
                self.cache_hit_ratio.set(0.0)  # Cache miss
            
            # Update metrics
            duration = time.time() - start_time
            self.processing_duration.labels(
                operation="tts_streaming",
                format=self.config.format.value
            ).observe(duration)
            
            logger.info(f"TTS streaming completed for session {session_id}",
                       duration=duration,
                       chunks_sent=self.active_streams[session_id]["chunks_sent"])
            
        except WebSocketDisconnect:
            logger.info(f"WebSocket disconnected for session {session_id}")
        except Exception as e:
            logger.error(f"TTS streaming error for session {session_id}: {e}")
            await websocket.send_json({
                "type": "error",
                "message": "Audio streaming failed",
                "error": str(e)
            })
        finally:
            # Cleanup session
            if session_id in self.active_streams:
                del self.active_streams[session_id]
            self.streaming_sessions.dec()
    
    async def process_voice_input(
        self,
        audio_data: bytes,
        session_id: str,
        config: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Process voice input for AI conversation.
        
        Args:
            audio_data: Raw audio data
            session_id: Session identifier
            config: Processing configuration
            
        Returns:
            Processing result with transcription and voice analysis
        """
        start_time = time.time()
        
        try:
            # Voice activity detection
            voice_activity = await self._detect_voice_activity(audio_data)
            
            if not voice_activity.is_speech:
                return {
                    "status": "no_speech",
                    "confidence": voice_activity.confidence,
                    "duration": time.time() - start_time
                }
            
            # Audio preprocessing
            processed_audio = await self._preprocess_voice_audio(audio_data)
            
            # Transcription (integrate with existing transcription service)
            transcription = await self._transcribe_audio(processed_audio, session_id)
            
            # Voice characteristics analysis
            voice_analysis = await self._analyze_voice_characteristics(processed_audio)
            
            # Update metrics
            duration = time.time() - start_time
            self.processing_duration.labels(
                operation="voice_processing",
                format="wav"
            ).observe(duration)
            
            self.voice_activity_detected.labels(result="speech").inc()
            
            return {
                "status": "success",
                "transcription": transcription,
                "voice_activity": voice_activity.__dict__,
                "voice_analysis": voice_analysis,
                "processing_duration": duration
            }
            
        except Exception as e:
            logger.error(f"Voice processing error for session {session_id}: {e}")
            return {
                "status": "error",
                "message": str(e),
                "duration": time.time() - start_time
            }
    
    async def detect_chapters(
        self,
        audio_file_path: Path,
        min_silence_duration: float = 3.0,
        silence_threshold: float = -40.0
    ) -> List[ChapterMarker]:
        """
        Detect chapter boundaries using silence analysis.
        
        Args:
            audio_file_path: Path to audio file
            min_silence_duration: Minimum silence duration for chapter break
            silence_threshold: Silence threshold in dB
            
        Returns:
            List of detected chapter markers
        """
        if not LIBROSA_AVAILABLE:
            logger.warning("librosa not available - chapter detection disabled")
            return []
        
        start_time = time.time()
        chapters = []
        
        try:
            # Load audio file
            audio, sr = librosa.load(str(audio_file_path), sr=None)
            
            # Detect silence segments
            silence_segments = await self._detect_silence_segments(
                audio, sr, min_silence_duration, silence_threshold
            )
            
            # Convert silence segments to chapter markers
            for i, (start, end) in enumerate(silence_segments):
                confidence = self._calculate_chapter_confidence(
                    audio, sr, start, end, silence_threshold
                )
                
                chapter = ChapterMarker(
                    start_time=start,
                    end_time=end,
                    title=f"Chapter {i + 1}",
                    confidence=confidence,
                    silence_duration=end - start
                )
                chapters.append(chapter)
            
            # Update metrics
            duration = time.time() - start_time
            self.processing_duration.labels(
                operation="chapter_detection",
                format="audio"
            ).observe(duration)
            
            for chapter in chapters:
                confidence_level = self._get_confidence_level(chapter.confidence)
                self.chapter_detections.labels(confidence_level=confidence_level).inc()
            
            logger.info(f"Detected {len(chapters)} chapters",
                       file=audio_file_path.name,
                       duration=duration)
            
            return chapters
            
        except Exception as e:
            logger.error(f"Chapter detection failed: {e}")
            return []
    
    async def optimize_for_mobile(
        self,
        audio_data: bytes,
        target_bitrate: int = 64000,  # 64kbps
        target_sample_rate: int = 22050
    ) -> bytes:
        """
        Optimize audio for mobile bandwidth and battery life.
        
        Args:
            audio_data: Original audio data
            target_bitrate: Target bitrate in bps
            target_sample_rate: Target sample rate in Hz
            
        Returns:
            Optimized audio data
        """
        start_time = time.time()
        
        try:
            if not LIBROSA_AVAILABLE:
                logger.warning("librosa not available - returning original audio")
                return audio_data
            
            # Load audio from bytes
            audio_io = io.BytesIO(audio_data)
            audio, sr = librosa.load(audio_io, sr=None)
            
            # Resample if necessary
            if sr != target_sample_rate:
                audio = librosa.resample(audio, orig_sr=sr, target_sr=target_sample_rate)
                sr = target_sample_rate
            
            # Apply compression and normalization
            audio = self._apply_audio_compression(audio)
            audio = self._normalize_audio(audio)
            
            # Convert back to bytes
            output_io = io.BytesIO()
            sf.write(output_io, audio, sr, format='WAV')
            optimized_data = output_io.getvalue()
            
            # Update metrics
            duration = time.time() - start_time
            self.processing_duration.labels(
                operation="mobile_optimization",
                format="wav"
            ).observe(duration)
            
            compression_ratio = len(optimized_data) / len(audio_data)
            logger.info("Audio optimized for mobile",
                       original_size=len(audio_data),
                       optimized_size=len(optimized_data),
                       compression_ratio=compression_ratio)
            
            return optimized_data
            
        except Exception as e:
            logger.error(f"Mobile optimization failed: {e}")
            return audio_data  # Return original on failure
    
    async def _generate_tts_audio(
        self,
        text: str,
        voice_config: Dict[str, Any]
    ) -> bytes:
        """Generate TTS audio using the existing TTS service."""
        # This would integrate with the existing TTS service
        # For now, return placeholder audio data
        
        # TODO: Integrate with actual TTS service
        # tts_response = await self._call_tts_service(text, voice_config)
        # return tts_response['audio_data']
        
        # Placeholder implementation
        duration = len(text) * 0.1  # Rough estimate
        sample_rate = self.config.sample_rate
        samples = int(duration * sample_rate)
        
        # Generate simple audio data (sine wave for testing)
        t = np.linspace(0, duration, samples)
        frequency = 440  # A4 note
        audio = 0.3 * np.sin(2 * np.pi * frequency * t)
        
        # Convert to bytes
        audio_int16 = (audio * 32767).astype(np.int16)
        return audio_int16.tobytes()
    
    async def _stream_audio_chunks(
        self,
        audio_data: bytes,
        websocket: WebSocket,
        session_id: str
    ) -> None:
        """Stream audio data in chunks over WebSocket."""
        chunk_size = self.config.chunk_size * 2  # 2 bytes per sample for int16
        total_chunks = len(audio_data) // chunk_size
        
        for i in range(0, len(audio_data), chunk_size):
            chunk_data = audio_data[i:i + chunk_size]
            
            chunk = AudioChunk(
                data=base64.b64encode(chunk_data).decode(),
                timestamp=time.time(),
                sequence=i // chunk_size,
                format=self.config.format,
                metadata={
                    "session_id": session_id,
                    "chunk_index": i // chunk_size,
                    "total_chunks": total_chunks
                }
            )
            
            await websocket.send_json({
                "type": "audio_chunk",
                "data": chunk.data,
                "sequence": chunk.sequence,
                "timestamp": chunk.timestamp,
                "metadata": chunk.metadata
            })
            
            # Update session stats
            if session_id in self.active_streams:
                self.active_streams[session_id]["chunks_sent"] += 1
                self.active_streams[session_id]["bytes_sent"] += len(chunk_data)
            
            # Small delay to prevent overwhelming the client
            await asyncio.sleep(0.01)
            
            # Update metrics
            self.audio_chunks_processed.labels(
                format=self.config.format.value,
                quality=self.config.quality.value,
                mode="streaming"
            ).inc()
        
        # Send end-of-stream marker
        await websocket.send_json({
            "type": "stream_end",
            "session_id": session_id,
            "total_chunks": total_chunks
        })
    
    async def _detect_voice_activity(
        self,
        audio_data: bytes,
        frame_duration: int = 30  # milliseconds
    ) -> VoiceActivity:
        """Detect voice activity in audio data."""
        if not VAD_AVAILABLE or not self.vad:
            # Fallback: simple energy-based detection
            return await self._simple_voice_detection(audio_data)
        
        try:
            # Convert audio data to the format expected by VAD
            audio_array = np.frombuffer(audio_data, dtype=np.int16)
            sample_rate = self.config.sample_rate
            
            # VAD requires specific sample rates (8000, 16000, 32000, 48000)
            vad_sample_rates = [8000, 16000, 32000, 48000]
            vad_sample_rate = min(vad_sample_rates, key=lambda x: abs(x - sample_rate))
            
            # Resample if necessary
            if LIBROSA_AVAILABLE and sample_rate != vad_sample_rate:
                audio_float = audio_array.astype(np.float32) / 32768.0
                resampled = librosa.resample(audio_float, orig_sr=sample_rate, target_sr=vad_sample_rate)
                audio_array = (resampled * 32767).astype(np.int16)
            
            # Process in frames
            frame_length = int(vad_sample_rate * frame_duration / 1000)
            speech_frames = 0
            total_frames = 0
            
            for i in range(0, len(audio_array) - frame_length, frame_length):
                frame = audio_array[i:i + frame_length].tobytes()
                is_speech = self.vad.is_speech(frame, vad_sample_rate)
                
                if is_speech:
                    speech_frames += 1
                total_frames += 1
            
            # Calculate confidence based on speech ratio
            speech_ratio = speech_frames / total_frames if total_frames > 0 else 0
            is_speech = speech_ratio > 0.3  # Threshold for considering it speech
            
            duration = len(audio_array) / sample_rate
            
            return VoiceActivity(
                is_speech=is_speech,
                confidence=speech_ratio,
                start_time=0.0,
                end_time=duration
            )
            
        except Exception as e:
            logger.warning(f"VAD failed, falling back to simple detection: {e}")
            return await self._simple_voice_detection(audio_data)
    
    async def _simple_voice_detection(self, audio_data: bytes) -> VoiceActivity:
        """Simple energy-based voice detection fallback."""
        audio_array = np.frombuffer(audio_data, dtype=np.int16)
        
        # Calculate RMS energy
        rms_energy = np.sqrt(np.mean(audio_array.astype(np.float32) ** 2))
        
        # Simple threshold-based detection
        threshold = 1000  # Adjust based on testing
        is_speech = rms_energy > threshold
        confidence = min(rms_energy / (threshold * 2), 1.0)
        
        duration = len(audio_array) / self.config.sample_rate
        
        return VoiceActivity(
            is_speech=is_speech,
            confidence=confidence,
            start_time=0.0,
            end_time=duration
        )
    
    async def _detect_silence_segments(
        self,
        audio: np.ndarray,
        sr: int,
        min_duration: float,
        threshold_db: float
    ) -> List[Tuple[float, float]]:
        """Detect silence segments in audio."""
        if not LIBROSA_AVAILABLE:
            return []
        
        # Convert to dB
        audio_db = librosa.amplitude_to_db(np.abs(audio))
        
        # Find segments below threshold
        silence_mask = audio_db < threshold_db
        
        # Find contiguous silence regions
        silence_segments = []
        in_silence = False
        silence_start = 0
        
        for i, is_silent in enumerate(silence_mask):
            time_pos = i / sr
            
            if is_silent and not in_silence:
                # Start of silence
                silence_start = time_pos
                in_silence = True
            elif not is_silent and in_silence:
                # End of silence
                silence_duration = time_pos - silence_start
                if silence_duration >= min_duration:
                    silence_segments.append((silence_start, time_pos))
                in_silence = False
        
        # Handle case where audio ends in silence
        if in_silence:
            silence_duration = len(audio) / sr - silence_start
            if silence_duration >= min_duration:
                silence_segments.append((silence_start, len(audio) / sr))
        
        return silence_segments
    
    def _calculate_chapter_confidence(
        self,
        audio: np.ndarray,
        sr: int,
        start: float,
        end: float,
        threshold_db: float
    ) -> float:
        """Calculate confidence score for chapter boundary detection."""
        # Simple confidence calculation based on silence duration and depth
        silence_duration = end - start
        
        # Get audio segment
        start_sample = int(start * sr)
        end_sample = int(end * sr)
        segment = audio[start_sample:end_sample]
        
        if len(segment) == 0:
            return 0.0
        
        # Calculate average amplitude in dB
        avg_amplitude_db = librosa.amplitude_to_db(np.mean(np.abs(segment)))
        
        # Confidence based on silence duration and depth
        duration_score = min(silence_duration / 10.0, 1.0)  # Max score at 10+ seconds
        depth_score = max(0, (threshold_db - avg_amplitude_db) / 20.0)  # Deeper silence = higher score
        
        return min((duration_score + depth_score) / 2.0, 1.0)
    
    def _get_confidence_level(self, confidence: float) -> str:
        """Convert numerical confidence to level."""
        if confidence >= 0.8:
            return "high"
        elif confidence >= 0.5:
            return "medium"
        else:
            return "low"
    
    def _apply_audio_compression(self, audio: np.ndarray) -> np.ndarray:
        """Apply dynamic range compression."""
        # Simple compression algorithm
        threshold = 0.7
        ratio = 4.0
        
        # Apply compression
        compressed = np.copy(audio)
        mask = np.abs(audio) > threshold
        compressed[mask] = np.sign(audio[mask]) * (
            threshold + (np.abs(audio[mask]) - threshold) / ratio
        )
        
        return compressed
    
    def _normalize_audio(self, audio: np.ndarray) -> np.ndarray:
        """Normalize audio to prevent clipping."""
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            return audio / max_val * 0.95  # Leave some headroom
        return audio
    
    def _generate_audio_cache_key(
        self,
        text: str,
        voice_config: Dict[str, Any]
    ) -> str:
        """Generate cache key for audio content."""
        key_data = {
            "text": text,
            "voice_config": voice_config,
            "audio_config": {
                "sample_rate": self.config.sample_rate,
                "format": self.config.format.value,
                "quality": self.config.quality.value
            }
        }
        key_json = json.dumps(key_data, sort_keys=True)
        return f"audio:{hashlib.sha256(key_json.encode()).hexdigest()[:16]}"
    
    async def _get_cached_audio(self, cache_key: str) -> Optional[bytes]:
        """Get cached audio data."""
        if not self.cache:
            try:
                cached_data = self.redis.get(cache_key)
                if cached_data:
                    return base64.b64decode(cached_data)
            except Exception as e:
                logger.warning(f"Cache retrieval failed: {e}")
        else:
            # Use semantic cache if available
            cached_data = self.cache.get(CacheType.AUDIO_PROCESSING, cache_key)
            if cached_data:
                return cached_data
        
        return None
    
    async def _cache_audio(self, cache_key: str, audio_data: bytes) -> None:
        """Cache audio data."""
        try:
            if not self.cache:
                # Use Redis directly
                encoded_data = base64.b64encode(audio_data).decode()
                self.redis.setex(cache_key, 3600, encoded_data)  # 1 hour TTL
            else:
                # Use semantic cache
                self.cache.set(CacheType.AUDIO_PROCESSING, cache_key, audio_data)
        except Exception as e:
            logger.warning(f"Audio caching failed: {e}")
    
    async def _stream_cached_audio(
        self,
        audio_data: bytes,
        websocket: WebSocket,
        session_id: str
    ) -> None:
        """Stream cached audio data."""
        await self._stream_audio_chunks(audio_data, websocket, session_id)
    
    async def _preprocess_voice_audio(self, audio_data: bytes) -> bytes:
        """Preprocess voice audio for better transcription."""
        if not LIBROSA_AVAILABLE:
            return audio_data
        
        try:
            # Load audio
            audio_io = io.BytesIO(audio_data)
            audio, sr = librosa.load(audio_io, sr=16000)  # Standard rate for voice
            
            # Noise reduction (simple)
            audio = self._simple_noise_reduction(audio)
            
            # Normalize
            audio = self._normalize_audio(audio)
            
            # Convert back to bytes
            output_io = io.BytesIO()
            sf.write(output_io, audio, sr, format='WAV')
            return output_io.getvalue()
            
        except Exception as e:
            logger.warning(f"Voice preprocessing failed: {e}")
            return audio_data
    
    def _simple_noise_reduction(self, audio: np.ndarray) -> np.ndarray:
        """Simple noise reduction using spectral subtraction."""
        if not LIBROSA_AVAILABLE:
            return audio
        
        # Simple high-pass filter to remove low-frequency noise
        from scipy.signal import butter, filtfilt
        
        try:
            # High-pass filter at 80 Hz
            b, a = butter(5, 80, btype='high', fs=16000)
            filtered = filtfilt(b, a, audio)
            return filtered
        except:
            return audio
    
    async def _transcribe_audio(
        self,
        audio_data: bytes,
        session_id: str
    ) -> Dict[str, Any]:
        """Transcribe audio using the existing transcription service."""
        # TODO: Integrate with existing transcription service
        # This is a placeholder implementation
        
        return {
            "text": "Placeholder transcription",
            "confidence": 0.85,
            "language": "en-US",
            "duration": len(audio_data) / (16000 * 2)  # Rough estimate
        }
    
    async def _analyze_voice_characteristics(
        self,
        audio_data: bytes
    ) -> Dict[str, Any]:
        """Analyze voice characteristics for persona adaptation."""
        if not LIBROSA_AVAILABLE:
            return {"available": False}
        
        try:
            audio_io = io.BytesIO(audio_data)
            audio, sr = librosa.load(audio_io, sr=None)
            
            # Basic voice analysis
            tempo, beats = librosa.beat.beat_track(y=audio, sr=sr)
            spectral_centroids = librosa.feature.spectral_centroid(y=audio, sr=sr)
            zero_crossings = librosa.feature.zero_crossing_rate(audio)
            
            return {
                "tempo": float(tempo),
                "spectral_centroid_mean": float(np.mean(spectral_centroids)),
                "zero_crossing_rate_mean": float(np.mean(zero_crossings)),
                "rms_energy": float(np.sqrt(np.mean(audio ** 2))),
                "duration": float(len(audio) / sr)
            }
            
        except Exception as e:
            logger.warning(f"Voice analysis failed: {e}")
            return {"error": str(e)}


# Factory functions and utilities

def create_audio_processor(
    redis_client: redis.Redis,
    cache: Optional[SemanticCache] = None,
    config: Optional[AudioConfig] = None
) -> AudioProcessor:
    """
    Create audio processor with EchoWright defaults.
    
    Args:
        redis_client: Configured Redis client
        cache: Semantic cache instance
        config: Audio processing configuration
        
    Returns:
        Configured AudioProcessor instance
    """
    return AudioProcessor(redis_client, cache, config)


def setup_audio_pipeline(
    app,
    redis_client: redis.Redis,
    cache: Optional[SemanticCache] = None,
    config: Optional[AudioConfig] = None
) -> AudioProcessor:
    """
    Set up audio pipeline for a FastAPI application.
    
    Args:
        app: FastAPI application instance
        redis_client: Configured Redis client
        cache: Semantic cache instance
        config: Audio processing configuration
        
    Returns:
        Configured AudioProcessor instance
    """
    # Create audio processor
    processor = create_audio_processor(redis_client, cache, config)
    
    # Add WebSocket endpoint for audio streaming
    @app.websocket("/ws/audio/stream")
    async def websocket_audio_stream(websocket: WebSocket):
        """WebSocket endpoint for real-time audio streaming."""
        await websocket.accept()
        
        try:
            while True:
                # Wait for streaming request
                data = await websocket.receive_json()
                
                if data["type"] == "start_tts_stream":
                    session_id = data.get("session_id", f"stream_{int(time.time())}")
                    text = data.get("text", "")
                    voice_config = data.get("voice_config", {})
                    
                    await processor.stream_tts_audio(text, voice_config, websocket, session_id)
                
                elif data["type"] == "voice_input":
                    session_id = data.get("session_id", f"voice_{int(time.time())}")
                    audio_data = base64.b64decode(data.get("audio_data", ""))
                    
                    result = await processor.process_voice_input(audio_data, session_id)
                    await websocket.send_json({
                        "type": "voice_processing_result",
                        "result": result
                    })
        
        except WebSocketDisconnect:
            logger.info("Audio streaming WebSocket disconnected")
        except Exception as e:
            logger.error(f"Audio streaming error: {e}")
            await websocket.send_json({
                "type": "error",
                "message": str(e)
            })
    
    # Add REST endpoints
    @app.post("/audio/optimize")
    async def optimize_audio(
        audio_data: bytes,
        target_bitrate: int = 64000,
        target_sample_rate: int = 22050
    ):
        """Optimize audio for mobile devices."""
        optimized = await processor.optimize_for_mobile(
            audio_data, target_bitrate, target_sample_rate
        )
        return {
            "optimized_audio": base64.b64encode(optimized).decode(),
            "original_size": len(audio_data),
            "optimized_size": len(optimized),
            "compression_ratio": len(optimized) / len(audio_data)
        }
    
    @app.post("/audio/detect-chapters")
    async def detect_audio_chapters(
        file_path: str,
        min_silence_duration: float = 3.0,
        silence_threshold: float = -40.0
    ):
        """Detect chapter boundaries in audio file."""
        try:
            audio_path = Path(file_path)
            chapters = await processor.detect_chapters(
                audio_path, min_silence_duration, silence_threshold
            )
            
            return {
                "chapters": [
                    {
                        "start_time": ch.start_time,
                        "end_time": ch.end_time,
                        "title": ch.title,
                        "confidence": ch.confidence,
                        "silence_duration": ch.silence_duration
                    }
                    for ch in chapters
                ]
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @app.get("/audio/pipeline/status")
    async def get_pipeline_status():
        """Get audio pipeline status."""
        return {
            "active_streams": len(processor.active_streams),
            "vad_available": VAD_AVAILABLE,
            "librosa_available": LIBROSA_AVAILABLE,
            "config": {
                "sample_rate": processor.config.sample_rate,
                "channels": processor.config.channels,
                "format": processor.config.format.value,
                "quality": processor.config.quality.value
            }
        }
    
    logger.info("Audio pipeline setup complete")
    return processor