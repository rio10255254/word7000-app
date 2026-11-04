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

## Everyday scenarios

`scenarios.json` holds the role-plays the speaking path is built from: ten
everyday scenarios (restaurant, café and drink shop, convenience store,
department store, directions and transport, doctor and pharmacy, hotel,
making friends, work, booking by phone), two stages each, five turns a stage.
Each turn has who speaks to the learner (`role`), what they say (`partner`),
a short model reply to say after it (`reply`), the useful chunk in that reply
(`key`) and what to say in one's own words (`task`), each in Traditional
Chinese (Taiwan usage) and English. Learners of English practise the English
with the Chinese as translation, and learners of Chinese the reverse.

They were written by the coding assistant for this app and are not yet
reviewed by a teacher. Rebuild the app's copy with
`node scripts/build-speaking-scenarios.mjs` (it checks counts, punctuation,
lengths, that each key is part of its reply, and duplicates); CI runs it with
`--check`.
