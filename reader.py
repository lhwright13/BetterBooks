from TTS.api import TTS
from config import VOICE_NAME

tts = TTS(model_name=VOICE_NAME, progress_bar=False, gpu=True)

def read_aloud(text):
    tts.tts_to_file(text=text, file_path="temp.wav")
    import os
    os.system("afplay temp.wav")
