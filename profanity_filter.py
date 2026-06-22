import re

# Common profanities to block. Uses whole-word matching (word boundaries) to
# avoid false positives like "assignment" or "classic".
_BLOCKED_WORDS = [
        "fuck","fucked","fucking","fucker","fucks","shit","shitting","shitter","shits",
        "cunt","cunts","cock","cocks","dick","dicks","pussy","pussies",
        "asshole","assholes","bastard","bastards","bitch","bitches","bitching",
        "wank","wanker","wankers","wanking","twat","twats","bollocks","ass"
        "arse","arsehole","arseholes","prick","pricks","motherfucker","motherfuckers", "woman"
        "whore","whores","girl","girls","lingerie","nude","naked","bikini","panties","slut","sluts"
]

_PATTERN = re.compile(
    r'\b(' + '|'.join(re.escape(w) for w in _BLOCKED_WORDS) + r')\b',
    re.IGNORECASE
)


def contains_profanity(text: str) -> bool:
    """Return True if the text contains blocked words."""
    return bool(_PATTERN.search(text))


def find_profanity(text: str) -> list[str]:
    """Return a list of matched blocked words found in the text."""
    return list({m.group().lower() for m in _PATTERN.finditer(text)})
