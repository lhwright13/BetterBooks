import subprocess
from character_prompt import create_character_prompt
from config import LLM_MODEL

class LLMResponder:
    def __init__(self, character):
        self.character = character

    def answer(self, question, context):
        prompt = create_character_prompt(self.character, question, context)
        result = subprocess.run([
            "ollama", "run", LLM_MODEL
        ], input=prompt.encode(), capture_output=True)
        return result.stdout.decode()
