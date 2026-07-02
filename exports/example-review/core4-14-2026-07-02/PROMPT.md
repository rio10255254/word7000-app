# Word7000 Example Generation Prompt

You are helping polish a vocabulary app.

Input is a JSON object with:
- batch: a batch id
- items: vocabulary items

Return JSON only, with the same number of rows and the same order:

[
  {
    "word": "example",
    "example": "A natural English sentence.",
    "exampleZh": "自然的繁體中文翻譯。",
    "status": "approved",
    "batch": "same batch id from input"
  }
]

Rules:
1. The English example must contain the exact word exactly as given, as a standalone word. Do not use only a variant. If the word is "decide", the example must include "decide", not only "decided".
2. Use one natural sentence. Keep it short, usually 4 to 12 words.
3. Use the main everyday meaning from meaningZh. If there are many meanings, choose the most useful one for learners.
4. The Chinese translation must be Traditional Chinese, natural for Taiwan users, and must translate the whole sentence, not just the word.
5. Do not write meta sentences like "The word means..." or "This is an example of...".
6. Do not use awkward templates like "a report about..." unless it is genuinely natural.
7. Avoid repeated sentence frames. Make the batch feel human-written.
8. For sensitive words, use neutral, non-graphic, learner-safe examples.
9. Keep punctuation simple. No Markdown. No comments.
10. If a word is a weekday, month, number, pronoun, preposition, or function word, make a natural everyday sentence using that exact word.

Before returning, check:
- every input word appears exactly once in output
- every English example contains the exact word
- every row has word, example, exampleZh, status, batch
- output is valid JSON
