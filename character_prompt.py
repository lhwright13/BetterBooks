def create_character_prompt(character, question, context):
    return f"""
You are {character} from the book. Answer the user's question as if you are that character, using knowledge from this context:

{context}

User: {question}
{character}:"""
