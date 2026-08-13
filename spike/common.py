"""Shared normalization. Used identically at index time and query time."""
import unicodedata, re, hashlib

_PUNCT = re.compile(r"[^\w\s]", re.UNICODE)
_WS = re.compile(r"\s+")
_ARTICLES = {"the", "a", "an", "la", "le", "les", "el", "il", "der", "die", "das", "een", "de"}


def fold(s: str) -> str:
    """Lowercase, strip diacritics, drop punctuation, collapse whitespace.

    'Hernán Díaz' -> 'hernan diaz'
    "The Handmaid's Tale" -> 'the handmaids tale'
    'Tomorrow, and Tomorrow, and Tomorrow' -> 'tomorrow and tomorrow and tomorrow'
    """
    if not s:
        return ""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    # apostrophes vanish rather than becoming a break: handmaid's -> handmaids
    s = s.replace("'", "").replace("’", "")
    s = _PUNCT.sub(" ", s)
    return _WS.sub(" ", s).strip()


def strip_article(s: str) -> str:
    """Drop a single leading article. 'the hobbit' -> 'hobbit'"""
    parts = s.split(" ", 1)
    if len(parts) == 2 and parts[0] in _ARTICLES:
        return parts[1]
    return s


def title_key(s: str) -> str:
    """Canonical comparison form for a title: folded, article-less."""
    return strip_article(fold(s))


def tokens(s: str):
    return [t for t in fold(s).split(" ") if t]


def stable_bucket(key: str, mod: int) -> int:
    """Deterministic hash bucket, stable across runs and processes."""
    return int(hashlib.md5(key.encode()).hexdigest()[:8], 16) % mod


def year_of(datestr: str):
    """Pull a 4-digit year out of OL's free-text date fields."""
    if not datestr:
        return None
    m = re.search(r"(1[0-9]{3}|20[0-9]{2})", str(datestr))
    return int(m.group(1)) if m else None


# Title patterns that mark a work as *about* a book rather than being it.
# Used as a measured ranking signal, never as a hard filter.
DERIVATIVE_PATTERNS = [
    "study guide", "sparknotes", "cliffsnotes", "cliffs notes", "spark notes",
    "readings on", "critical essays", "critical interpretations", "modern critical",
    "blooms ", "a summary of", "summary of", "summary and analysis",
    "analysis of", "companion to", "guide to", "notes on", "criticism",
    "teachers guide", "lesson plans", "workbook", "quicklet", "conversations with",
    "approaches to teaching", "casebook", "instructors manual",
]


def looks_derivative(title: str) -> bool:
    t = fold(title)
    return any(p.strip() in t for p in DERIVATIVE_PATTERNS)
