"""Utility functions for customizing prompts before sending them to the LLM."""

import re
from typing import Any, Dict


def modify_prompt(prompt: str, options: Dict[str, Any] | None = None) -> str:
    """Return a prompt extended with optional style instructions.

    Parameters
    ----------
    prompt:
        The original user prompt.
    options:
        Optional dictionary allowing callers to influence the tone, length,
        persona, etc.  Unknown keys are ignored so additional values can be
        added in the future without breaking callers.
    """

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

    if not extras:
        # Remove emojis and other non-TTS-friendly characters
        return re.sub(r"[^\w\s.,!?'\"]", '', prompt)

    preprompt = " ".join(extras)
    filtered_prompt = re.sub(r"[^\w\s.,!?'\"]", '', prompt)
    return f"{preprompt}\n\n{filtered_prompt}"
