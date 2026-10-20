# Speaking Questions

The native app contains 600 distinct word/question/answer pairs. The first 120
are preserved in `base-reviewed.json`; 480 additions are written individually
in twenty topic files. There is no random template assembly and no remote
generation or paid API call at runtime.

Each topic row is a JSON tuple in this order:

1. Exact headword from the built-in vocabulary, including its British spelling.
2. One Chinese sense used by the paired answer.
3. An English question with a concrete situation, choice, experience, or viewpoint.
4. A two-or-more-sentence English reference answer using the exact headword.
5. Natural Traditional Chinese expressing the same answer and Chinese sense.

Both practice languages share the question. Chinese practice shows the Chinese
keyword and reference answer; English practice reverses the answer/translation.
Answers illustrate one possible response, not an opinion learners must adopt.

These additions were authored and read through by the coding assistant. They are
not certified by an independent language teacher. Automated checks enforce
completeness, distinct entries, word identity, paired fields, minimum development,
target usage, source consistency, and coverage of all fourteen vocabulary levels;
they do not prove linguistic quality on their own.

Rebuild with `node scripts/build-native-speaking-library.mjs`, then verify with
`node scripts/build-native-speaking-library.mjs --check`. Commit the source files
and generated resource together. Native tests exercise every paired card in both
languages, scoped selection, and random sessions. Release checks compare the
actual signed app's question file with this generated resource.
