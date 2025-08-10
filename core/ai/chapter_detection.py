"""
Intelligent Chapter Detection System using AI

This module provides AI-powered chapter detection for audiobooks by analyzing:
1. Transcript content and semantic transitions
2. Speaker changes and silence patterns
3. Audio features like volume changes and music
4. LLM-based content analysis for chapter boundaries

The system identifies natural chapter breaks and generates metadata.
"""

import os
import re
import json
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass
from pathlib import Path

import librosa
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.cluster import KMeans

# Import our LLM service
import aiohttp
import asyncio


@dataclass
class ChapterCandidate:
    """Represents a potential chapter boundary."""
    timestamp: float  # Start time in seconds
    confidence: float  # Confidence score 0-1
    reason: str  # Why this was identified as a chapter boundary
    title_suggestion: str  # AI-suggested chapter title
    content_preview: str  # Preview of chapter content
    audio_features: Dict[str, float]  # Audio analysis features
    

@dataclass
class DetectedChapter:
    """Represents a detected chapter with metadata."""
    chapter_number: int
    title: str
    start_time: float
    end_time: float
    duration: float
    confidence: float
    summary: str
    key_topics: List[str]
    word_count: int
    speaker_changes: int


class ChapterDetectionEngine:
    """AI-powered chapter detection system."""
    
    def __init__(self, llm_gateway_url: str = "http://llm_gateway:8000"):
        self.llm_gateway_url = llm_gateway_url
        self.min_chapter_duration = 300  # 5 minutes minimum
        self.max_chapter_duration = 3600  # 60 minutes maximum
        self.silence_threshold = -40  # dB threshold for silence detection
        
    async def detect_chapters(
        self, 
        audio_file_path: str, 
        transcript_segments: List[Dict[str, Any]],
        audio_data: Optional[np.ndarray] = None
    ) -> List[DetectedChapter]:
        """
        Main method to detect chapters using multiple AI techniques.
        
        Args:
            audio_file_path: Path to audio file
            transcript_segments: List of transcript segments with timestamps
            audio_data: Optional pre-loaded audio data
            
        Returns:
            List of detected chapters with metadata
        """
        print(f"🔍 Starting intelligent chapter detection for {audio_file_path}")
        
        # Load audio if not provided
        if audio_data is None:
            audio_data, sr = librosa.load(audio_file_path, sr=22050)
        else:
            sr = 22050
            
        # Step 1: Analyze transcript for semantic boundaries
        semantic_boundaries = await self._detect_semantic_boundaries(transcript_segments)
        
        # Step 2: Detect audio features (silence, music, speaker changes)
        audio_boundaries = self._detect_audio_boundaries(audio_data, sr, transcript_segments)
        
        # Step 3: Combine and score all candidate boundaries
        all_candidates = self._combine_boundary_candidates(
            semantic_boundaries, 
            audio_boundaries,
            transcript_segments
        )
        
        # Step 4: Select final chapter boundaries using AI scoring
        final_chapters = await self._select_final_chapters(
            all_candidates, 
            transcript_segments,
            len(audio_data) / sr
        )
        
        # Step 5: Generate chapter metadata
        enriched_chapters = await self._enrich_chapter_metadata(final_chapters, transcript_segments)
        
        print(f"✅ Detected {len(enriched_chapters)} chapters with AI analysis")
        return enriched_chapters

    async def _detect_semantic_boundaries(self, transcript_segments: List[Dict[str, Any]]) -> List[ChapterCandidate]:
        """Detect chapter boundaries based on semantic content analysis."""
        print("🧠 Analyzing semantic content for chapter boundaries...")
        
        if len(transcript_segments) < 10:
            return []
            
        # Combine segments into larger chunks for analysis
        chunks = []
        chunk_timestamps = []
        current_chunk = ""
        current_start = 0
        
        for i, segment in enumerate(transcript_segments):
            current_chunk += segment['text'] + " "
            
            # Create chunks of ~500 words or 2-3 minutes
            if (len(current_chunk.split()) >= 500 or 
                segment['end'] - current_start >= 180 or
                i == len(transcript_segments) - 1):
                
                chunks.append(current_chunk.strip())
                chunk_timestamps.append((current_start, segment['end']))
                current_chunk = ""
                current_start = segment['end'] if i < len(transcript_segments) - 1 else segment['end']
        
        if len(chunks) < 3:
            return []
            
        # Use TF-IDF to analyze content similarity
        vectorizer = TfidfVectorizer(max_features=1000, stop_words='english')
        chunk_vectors = vectorizer.fit_transform(chunks)
        
        # Calculate similarity between adjacent chunks
        boundaries = []
        for i in range(len(chunks) - 1):
            similarity = cosine_similarity(
                chunk_vectors[i:i+1], 
                chunk_vectors[i+1:i+2]
            )[0][0]
            
            # Low similarity indicates topic change (potential chapter boundary)
            if similarity < 0.3:  # Threshold for topic change
                timestamp = chunk_timestamps[i][1]  # End of current chunk
                
                # Use LLM to analyze if this is a good chapter boundary
                boundary_context = chunks[i][-200:] + " " + chunks[i+1][:200]
                is_boundary, title_suggestion = await self._llm_analyze_boundary(boundary_context)
                
                if is_boundary:
                    boundaries.append(ChapterCandidate(
                        timestamp=timestamp,
                        confidence=1.0 - similarity,  # Lower similarity = higher confidence
                        reason=f"Semantic topic change detected (similarity: {similarity:.2f})",
                        title_suggestion=title_suggestion,
                        content_preview=chunks[i+1][:200],
                        audio_features={}
                    ))
        
        print(f"🧠 Found {len(boundaries)} semantic boundaries")
        return boundaries

    def _detect_audio_boundaries(
        self, 
        audio_data: np.ndarray, 
        sr: int,
        transcript_segments: List[Dict[str, Any]]
    ) -> List[ChapterCandidate]:
        """Detect chapter boundaries based on audio features."""
        print("🔊 Analyzing audio features for chapter boundaries...")
        
        boundaries = []
        
        # 1. Detect long silence periods
        silence_boundaries = self._detect_silence_boundaries(audio_data, sr)
        
        # 2. Detect RMS energy changes (volume changes)
        energy_boundaries = self._detect_energy_boundaries(audio_data, sr)
        
        # 3. Detect spectral changes (music/speech transitions)
        spectral_boundaries = self._detect_spectral_boundaries(audio_data, sr)
        
        # Combine audio features
        all_audio_boundaries = silence_boundaries + energy_boundaries + spectral_boundaries
        
        # Filter and score boundaries
        for boundary in all_audio_boundaries:
            # Only consider boundaries that align reasonably with transcript
            aligned_segment = self._find_nearest_transcript_segment(
                boundary.timestamp, transcript_segments
            )
            
            if aligned_segment:
                boundaries.append(boundary)
        
        print(f"🔊 Found {len(boundaries)} audio-based boundaries")
        return boundaries

    def _detect_silence_boundaries(self, audio_data: np.ndarray, sr: int) -> List[ChapterCandidate]:
        """Detect long silence periods that might indicate chapter breaks."""
        # Calculate RMS energy
        hop_length = 512
        frame_length = 2048
        rms = librosa.feature.rms(
            y=audio_data, 
            frame_length=frame_length, 
            hop_length=hop_length
        )[0]
        
        # Convert to dB
        rms_db = librosa.amplitude_to_db(rms, ref=np.max)
        
        # Find silence regions
        silence_frames = rms_db < self.silence_threshold
        silence_times = librosa.frames_to_time(
            np.where(silence_frames)[0], 
            sr=sr, 
            hop_length=hop_length
        )
        
        # Group consecutive silence frames
        boundaries = []
        if len(silence_times) > 0:
            silence_groups = []
            current_group = [silence_times[0]]
            
            for time in silence_times[1:]:
                if time - current_group[-1] < 0.5:  # Group silences within 0.5s
                    current_group.append(time)
                else:
                    if len(current_group) > 10:  # At least ~5 seconds of silence
                        silence_groups.append(current_group)
                    current_group = [time]
            
            # Add the last group
            if len(current_group) > 10:
                silence_groups.append(current_group)
            
            # Create boundaries for long silence periods
            for group in silence_groups:
                if len(group) > 20:  # ~10 seconds of silence
                    boundaries.append(ChapterCandidate(
                        timestamp=group[0],
                        confidence=min(0.8, len(group) / 40),  # More silence = higher confidence
                        reason=f"Extended silence period detected ({len(group) * 0.5:.1f}s)",
                        title_suggestion="",
                        content_preview="",
                        audio_features={"silence_duration": len(group) * 0.5}
                    ))
        
        return boundaries

    def _detect_energy_boundaries(self, audio_data: np.ndarray, sr: int) -> List[ChapterCandidate]:
        """Detect significant energy/volume changes."""
        # Calculate RMS energy over larger windows
        hop_length = sr // 10  # 0.1 second hops
        frame_length = sr // 2  # 0.5 second frames
        
        rms = librosa.feature.rms(
            y=audio_data, 
            frame_length=frame_length, 
            hop_length=hop_length
        )[0]
        
        # Find significant energy changes
        rms_diff = np.abs(np.diff(rms))
        energy_changes = np.where(rms_diff > np.std(rms_diff) * 2)[0]
        
        boundaries = []
        for change_idx in energy_changes:
            timestamp = librosa.frames_to_time(
                change_idx, 
                sr=sr, 
                hop_length=hop_length
            )
            
            # Skip changes too close to start/end
            if timestamp > 30 and timestamp < len(audio_data) / sr - 30:
                boundaries.append(ChapterCandidate(
                    timestamp=timestamp,
                    confidence=0.4,  # Lower confidence for energy changes alone
                    reason="Significant audio energy change detected",
                    title_suggestion="",
                    content_preview="",
                    audio_features={
                        "energy_change": float(rms_diff[change_idx]),
                        "pre_energy": float(rms[change_idx]),
                        "post_energy": float(rms[change_idx + 1])
                    }
                ))
        
        return boundaries

    def _detect_spectral_boundaries(self, audio_data: np.ndarray, sr: int) -> List[ChapterCandidate]:
        """Detect spectral changes that might indicate music/speech transitions."""
        # Calculate spectral features
        hop_length = sr // 10
        spectral_centroids = librosa.feature.spectral_centroid(
            y=audio_data, 
            sr=sr, 
            hop_length=hop_length
        )[0]
        
        spectral_rolloff = librosa.feature.spectral_rolloff(
            y=audio_data, 
            sr=sr, 
            hop_length=hop_length
        )[0]
        
        # Find significant spectral changes
        centroid_diff = np.abs(np.diff(spectral_centroids))
        rolloff_diff = np.abs(np.diff(spectral_rolloff))
        
        # Combined spectral change score
        spectral_change = (centroid_diff / np.max(centroid_diff) + 
                          rolloff_diff / np.max(rolloff_diff)) / 2
        
        change_points = np.where(spectral_change > np.std(spectral_change) * 2.5)[0]
        
        boundaries = []
        for point in change_points:
            timestamp = librosa.frames_to_time(point, sr=sr, hop_length=hop_length)
            
            if timestamp > 30 and timestamp < len(audio_data) / sr - 30:
                boundaries.append(ChapterCandidate(
                    timestamp=timestamp,
                    confidence=0.5,
                    reason="Spectral characteristics change (possible music/speech transition)",
                    title_suggestion="",
                    content_preview="",
                    audio_features={
                        "spectral_change": float(spectral_change[point]),
                        "centroid": float(spectral_centroids[point]),
                        "rolloff": float(spectral_rolloff[point])
                    }
                ))
        
        return boundaries

    def _combine_boundary_candidates(
        self, 
        semantic_boundaries: List[ChapterCandidate],
        audio_boundaries: List[ChapterCandidate],
        transcript_segments: List[Dict[str, Any]]
    ) -> List[ChapterCandidate]:
        """Combine and score all boundary candidates."""
        print("🔗 Combining and scoring boundary candidates...")
        
        all_candidates = semantic_boundaries + audio_boundaries
        
        # Remove duplicates (boundaries within 30 seconds of each other)
        unique_candidates = []
        for candidate in sorted(all_candidates, key=lambda x: x.timestamp):
            # Check if this candidate is too close to an existing one
            too_close = False
            for existing in unique_candidates:
                if abs(candidate.timestamp - existing.timestamp) < 30:
                    # Keep the one with higher confidence
                    if candidate.confidence > existing.confidence:
                        unique_candidates.remove(existing)
                        break
                    else:
                        too_close = True
                        break
            
            if not too_close:
                unique_candidates.append(candidate)
        
        # Boost confidence for candidates with multiple supporting features
        enhanced_candidates = []
        for candidate in unique_candidates:
            enhanced_confidence = candidate.confidence
            
            # Boost confidence if multiple nearby candidates
            nearby_count = sum(1 for c in unique_candidates 
                             if c != candidate and abs(c.timestamp - candidate.timestamp) < 60)
            
            enhanced_confidence += nearby_count * 0.1
            enhanced_confidence = min(1.0, enhanced_confidence)
            
            enhanced_candidates.append(ChapterCandidate(
                timestamp=candidate.timestamp,
                confidence=enhanced_confidence,
                reason=candidate.reason,
                title_suggestion=candidate.title_suggestion,
                content_preview=candidate.content_preview,
                audio_features=candidate.audio_features
            ))
        
        print(f"🔗 Combined into {len(enhanced_candidates)} unique candidates")
        return sorted(enhanced_candidates, key=lambda x: x.timestamp)

    async def _select_final_chapters(
        self,
        candidates: List[ChapterCandidate],
        transcript_segments: List[Dict[str, Any]],
        total_duration: float
    ) -> List[DetectedChapter]:
        """Select final chapter boundaries using AI scoring."""
        print("🎯 Selecting final chapter boundaries...")
        
        # Filter candidates by minimum duration requirements
        filtered_candidates = []
        
        # Always include start
        filtered_candidates.append(ChapterCandidate(
            timestamp=0,
            confidence=1.0,
            reason="Book start",
            title_suggestion="Chapter 1",
            content_preview="",
            audio_features={}
        ))
        
        for i, candidate in enumerate(candidates):
            # Check minimum duration from previous chapter
            if filtered_candidates:
                prev_timestamp = filtered_candidates[-1].timestamp
                if candidate.timestamp - prev_timestamp < self.min_chapter_duration:
                    continue
            
            # Check if next candidate is too close
            skip = False
            for j in range(i + 1, len(candidates)):
                if (candidates[j].timestamp - candidate.timestamp < self.min_chapter_duration and
                    candidates[j].confidence > candidate.confidence):
                    skip = True
                    break
            
            if not skip:
                filtered_candidates.append(candidate)
        
        # Convert to chapters
        chapters = []
        for i in range(len(filtered_candidates)):
            start_time = filtered_candidates[i].timestamp
            end_time = (filtered_candidates[i + 1].timestamp 
                       if i + 1 < len(filtered_candidates) 
                       else total_duration)
            
            # Skip if chapter would be too short
            if end_time - start_time < self.min_chapter_duration:
                continue
                
            chapters.append(DetectedChapter(
                chapter_number=len(chapters) + 1,
                title=filtered_candidates[i].title_suggestion or f"Chapter {len(chapters) + 1}",
                start_time=start_time,
                end_time=end_time,
                duration=end_time - start_time,
                confidence=filtered_candidates[i].confidence,
                summary="",
                key_topics=[],
                word_count=0,
                speaker_changes=0
            ))
        
        print(f"🎯 Selected {len(chapters)} final chapters")
        return chapters

    async def _enrich_chapter_metadata(
        self,
        chapters: List[DetectedChapter],
        transcript_segments: List[Dict[str, Any]]
    ) -> List[DetectedChapter]:
        """Enrich chapters with AI-generated metadata."""
        print("✨ Enriching chapters with AI-generated metadata...")
        
        enriched_chapters = []
        
        for chapter in chapters:
            # Get transcript for this chapter
            chapter_text = self._extract_chapter_text(
                transcript_segments, 
                chapter.start_time, 
                chapter.end_time
            )
            
            # Generate AI metadata
            title, summary, topics = await self._generate_chapter_metadata(chapter_text)
            
            # Count words and speaker changes
            word_count = len(chapter_text.split())
            speaker_changes = self._count_speaker_changes(
                transcript_segments, 
                chapter.start_time, 
                chapter.end_time
            )
            
            enriched_chapter = DetectedChapter(
                chapter_number=chapter.chapter_number,
                title=title,
                start_time=chapter.start_time,
                end_time=chapter.end_time,
                duration=chapter.duration,
                confidence=chapter.confidence,
                summary=summary,
                key_topics=topics,
                word_count=word_count,
                speaker_changes=speaker_changes
            )
            
            enriched_chapters.append(enriched_chapter)
        
        print("✨ Chapter metadata enrichment complete")
        return enriched_chapters

    async def _llm_analyze_boundary(self, context: str) -> Tuple[bool, str]:
        """Use LLM to analyze if a text boundary represents a chapter break."""
        try:
            prompt = f"""Analyze this text transition to determine if it represents a natural chapter boundary in an audiobook.

Text transition:
{context}

Consider:
1. Does this represent a significant topic or scene change?
2. Is there a natural narrative break?
3. Does it feel like a chapter ending/beginning?
4. What would be an appropriate chapter title for the new section?

Respond with JSON format:
{{
    "is_chapter_boundary": true/false,
    "confidence": 0.0-1.0,
    "title_suggestion": "suggested chapter title",
    "reasoning": "why this is/isn't a chapter boundary"
}}"""

            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.llm_gateway_url}/complete",
                    json={
                        "prompt": prompt,
                        "max_tokens": 200,
                        "temperature": 0.3
                    },
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        
                        # Try to parse JSON from response
                        try:
                            import json
                            analysis = json.loads(result.get("response", "{}"))
                            return (
                                analysis.get("is_chapter_boundary", False),
                                analysis.get("title_suggestion", "")
                            )
                        except:
                            # Fallback: look for keywords in response
                            response_text = result.get("response", "").lower()
                            is_boundary = any(word in response_text 
                                            for word in ["yes", "true", "chapter", "boundary"])
                            return is_boundary, "Chapter"
        except Exception as e:
            print(f"LLM boundary analysis failed: {e}")
            
        return False, ""

    async def _generate_chapter_metadata(self, chapter_text: str) -> Tuple[str, str, List[str]]:
        """Generate title, summary, and topics for a chapter using LLM."""
        if len(chapter_text.strip()) < 100:
            return "Chapter", "Brief chapter content", []
            
        try:
            # Truncate very long chapters for LLM analysis
            analysis_text = chapter_text[:2000] if len(chapter_text) > 2000 else chapter_text
            
            prompt = f"""Analyze this audiobook chapter content and provide metadata:

Chapter text:
{analysis_text}

Please provide:
1. A compelling chapter title (5-8 words max)
2. A 2-3 sentence summary
3. 3-5 key topics/themes

Respond in JSON format:
{{
    "title": "chapter title",
    "summary": "chapter summary",
    "topics": ["topic1", "topic2", "topic3"]
}}"""

            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.llm_gateway_url}/complete",
                    json={
                        "prompt": prompt,
                        "max_tokens": 300,
                        "temperature": 0.4
                    },
                    timeout=aiohttp.ClientTimeout(total=15)
                ) as response:
                    if response.status == 200:
                        result = await response.json()
                        
                        try:
                            import json
                            metadata = json.loads(result.get("response", "{}"))
                            return (
                                metadata.get("title", f"Chapter {chapter_text[:20]}..."),
                                metadata.get("summary", "Chapter content summary"),
                                metadata.get("topics", [])
                            )
                        except:
                            # Fallback: generate basic metadata
                            words = chapter_text.split()
                            title = f"Chapter: {' '.join(words[:4])}"
                            summary = f"This chapter contains {len(words)} words of content."
                            return title, summary, []
        except Exception as e:
            print(f"Chapter metadata generation failed: {e}")
        
        # Fallback metadata
        return "Chapter", "Chapter content", []

    def _extract_chapter_text(
        self, 
        transcript_segments: List[Dict[str, Any]], 
        start_time: float, 
        end_time: float
    ) -> str:
        """Extract transcript text for a specific time range."""
        chapter_segments = [
            segment for segment in transcript_segments
            if (segment['start'] >= start_time and segment['end'] <= end_time) or
               (segment['start'] < end_time and segment['end'] > start_time)
        ]
        
        return " ".join(segment['text'] for segment in chapter_segments)

    def _count_speaker_changes(
        self,
        transcript_segments: List[Dict[str, Any]],
        start_time: float,
        end_time: float
    ) -> int:
        """Count speaker changes in a chapter (placeholder - would need speaker detection)."""
        # This is a placeholder - real implementation would need speaker diarization
        # For now, estimate based on segment breaks and pauses
        chapter_segments = [
            segment for segment in transcript_segments
            if segment['start'] >= start_time and segment['end'] <= end_time
        ]
        
        speaker_changes = 0
        for i in range(1, len(chapter_segments)):
            # Estimate speaker change based on significant pause
            pause_duration = chapter_segments[i]['start'] - chapter_segments[i-1]['end']
            if pause_duration > 2.0:  # 2+ second pause might indicate speaker change
                speaker_changes += 1
                
        return speaker_changes

    def _find_nearest_transcript_segment(
        self,
        timestamp: float,
        transcript_segments: List[Dict[str, Any]]
    ) -> Optional[Dict[str, Any]]:
        """Find the transcript segment closest to a given timestamp."""
        if not transcript_segments:
            return None
            
        closest_segment = min(
            transcript_segments,
            key=lambda seg: min(
                abs(seg['start'] - timestamp),
                abs(seg['end'] - timestamp)
            )
        )
        
        return closest_segment


# Utility functions for integration
async def detect_chapters_for_audiobook(
    audio_file_path: str,
    transcript_segments: List[Dict[str, Any]],
    output_path: Optional[str] = None
) -> List[DetectedChapter]:
    """
    Convenience function to detect chapters for an audiobook.
    
    Args:
        audio_file_path: Path to the audio file
        transcript_segments: Transcript segments with timing
        output_path: Optional path to save chapter metadata JSON
        
    Returns:
        List of detected chapters
    """
    detector = ChapterDetectionEngine()
    chapters = await detector.detect_chapters(audio_file_path, transcript_segments)
    
    if output_path:
        # Save chapter metadata
        chapter_data = []
        for chapter in chapters:
            chapter_data.append({
                "chapter_number": chapter.chapter_number,
                "title": chapter.title,
                "start_time": chapter.start_time,
                "end_time": chapter.end_time,
                "duration": chapter.duration,
                "confidence": chapter.confidence,
                "summary": chapter.summary,
                "key_topics": chapter.key_topics,
                "word_count": chapter.word_count,
                "speaker_changes": chapter.speaker_changes
            })
        
        with open(output_path, 'w') as f:
            json.dump({
                "audiobook_file": audio_file_path,
                "detection_timestamp": datetime.now().isoformat(),
                "total_chapters": len(chapters),
                "chapters": chapter_data
            }, f, indent=2)
    
    return chapters


def format_chapters_for_display(chapters: List[DetectedChapter]) -> str:
    """Format detected chapters for human-readable display."""
    output = "📚 Detected Audiobook Chapters\n"
    output += "=" * 50 + "\n\n"
    
    for chapter in chapters:
        duration_mins = int(chapter.duration // 60)
        duration_secs = int(chapter.duration % 60)
        start_mins = int(chapter.start_time // 60)
        start_secs = int(chapter.start_time % 60)
        
        output += f"Chapter {chapter.chapter_number}: {chapter.title}\n"
        output += f"  ⏱️  Start: {start_mins:02d}:{start_secs:02d} | Duration: {duration_mins:02d}:{duration_secs:02d}\n"
        output += f"  📊 Confidence: {chapter.confidence:.2f} | Words: {chapter.word_count:,}\n"
        output += f"  📝 {chapter.summary}\n"
        
        if chapter.key_topics:
            output += f"  🏷️  Topics: {', '.join(chapter.key_topics[:3])}\n"
        
        output += "\n"
    
    return output