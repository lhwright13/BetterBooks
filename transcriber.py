import os
import tempfile
import sounddevice as sd
import numpy as np
import faster_whisper

model = faster_whisper.WhisperModel("base")

def listen_for_question(trigger_word="question", duration=8, fs=16000):
    print("Listening for trigger word...")
    recording = sd.rec(int(duration * fs), samplerate=fs, channels=1)
    sd.wait()
    temp_wav = tempfile.mktemp(suffix=".wav")
    from scipy.io.wavfile import write
    write(temp_wav, fs, np.int16(recording * 32767))
    segments, _ = model.transcribe(temp_wav)
    full_text = " ".join([seg.text for seg in segments])
    if trigger_word in full_text.lower():
        print("Heard trigger. What is your question?")
        recording = sd.rec(int(10 * fs), samplerate=fs, channels=1)
        sd.wait()
        temp_q = tempfile.mktemp(suffix=".wav")
        write(temp_q, fs, np.int16(recording * 32767))
        segments, _ = model.transcribe(temp_q)
        return " ".join([seg.text for seg in segments])
    return None
