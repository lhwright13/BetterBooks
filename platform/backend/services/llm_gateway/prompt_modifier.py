import re


def modify_prompt(prompt: str, options: dict | None = None) -> str:
    if not options:
        options = {}

    extras: list[str] = []

    tone = options.get("tone")
    if tone:
        extras.append(f"Use a {tone} tone.")

    length = options.get("length")
    if length:
        extras.append(f"Keep the response {length}.")

    persona = options.get("persona")
    if persona:
        extras.append(f"Respond as the {persona}.")

    filtered_prompt = re.sub(r"[^\w\s.,!?'\"]", '', prompt)

    if not extras:
        return filtered_prompt

    preprompt = " ".join(extras)
    preprompt += " Do not use markdown formatting, asterisks, or special characters in your response. Use plain text only."
    return f"{preprompt}\n\n{filtered_prompt}"
