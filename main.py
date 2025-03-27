from reader import read_aloud
from context_manager import ContextManager
from llm_interface import LLMResponder
from config import CHARACTER_NAME, ENABLE_VOICE_INPUT
from transcriber import listen_for_question

context = ContextManager(window_size=2000)
responder = LLMResponder(character=CHARACTER_NAME)

print("Reading book... Say 'question' to interrupt.")

try:
    for chunk in context.read_in_chunks("book.txt"):
        read_aloud(chunk)
        if ENABLE_VOICE_INPUT:
            question = listen_for_question(trigger_word="question")
            if question:
                response = responder.answer(question, context.get_context())
                print(response)
except KeyboardInterrupt:
    print("\nPaused. Ask your question:")
    question = input("> ")
    response = responder.answer(question, context.get_context())
    print(response)
