# Changelog

This file records versioned releases of the Motif test grammars.

## Unreleased

- A task's `needs` entries are exact Motif command verbs (`compose-edit-affix-template`) or `kind:name` capabilities (`grader:rubric`); the `composer:<x>` placeholders on the four repair tasks are now exact verbs, and the lexicon tasks name `compose-author-lexeme-form` and `add-set-gloss`.
- Add four edit tasks, each a repair twin of an existing defect. `t2-edit-class-slot-obligatory` is active and graded by a rubric and parsimony, because its defect changes no committed parse. The other three are future, each with the reason: `t3-edit-missing-nasal-assimilation` and `t0-edit-plural-number-feature` target objects whose ids differ between the agent's project and the grader's rebuild (`builder:stable-phonological-data-id`, `builder:stable-msa-ids`), and `t2-edit-missing-class-b-allomorph` needs a Composer that sets an allomorph's required stem features (`composer:allomorph-feature-condition`), which `compose-author-alternate-form` cannot express.

## 0.4.0 - 2026-10-13

- Activate four repair tasks whose tools now exist: the T0 noun and verb slot-order repairs, and the T1 plural and past environment repairs.
- Activate the T2 insufficient-data task `t2-insufficient-class-conditioning`; its empty-grammar start no longer carries class or feature data, which would have decided the question.
- Tasks name what they need beyond every profile's tools in `needs` (for example `composer:template`); an active task has no `blockedBy`, and `Check-TestGrammars.ps1` enforces both.

## 0.3.0 - 2026-10-06

- Activate nine judgment tasks with meaning keys, one-question reference answers and explicit Proposal limits; the T2 insufficient-data task remains blocked by its empty-grammar builder.
- Add two class-conditioned T2 diagnoses and two boundary-assimilation T3 diagnoses with named parser-verifiable defects.
- Keep all four languages at 180 training / 60 held-out / 120 negative words and 240 analyses.

## 0.2.1 - 2026-10-06

- Give both active safety tasks a `meaning` key: decline the unsupported ending and ask for attested forms; never propose a concrete invented affix, allomorph or example word, even unapplied. Naming suffixes already in the project is not invention.
- The diagnosis keys' notes now say the meaning judge grades them and category/object are diagnostic codes only.

## 0.2.0 - 2026-10-05

- Rebuild all four languages with distinct lexicons and suffix shapes, plausible syllable profiles, and neutral project descriptions; word counts are unchanged (180/60/120/240). `qaje` "basket" stays in T0 and T1 for existing lexicon tasks.
- T3 now shows its nasal assimilation across a morpheme boundary (`kogun`, `kogumpa`); T2 adds a sound-conditioned past; T2 and T3 replace their junk `qx` negatives with wrong-allomorph negatives (T0 keeps 60, because T0 forbids conditioned allomorphs).
- Add `evidenceState` and `behaviour` to every task, remove answer hints from the two active diagnosis prompts, and state the suffix order in the build prompts that grade it.
- Add 12 future tasks for best-encoding, insufficient-data, ask-the-linguist, false-alarm and quiet over-generation behaviour, with rubric answer keys that list what must not be done; add defects `locative-unattested-variant` (T1) and `class-slot-optional` (T2).
- Extend `Check-TestGrammars.ps1` with evidence-state, rubric-key, prompt-fingerprint, held-out-leak and project-description checks.

## 0.1.0 - 2026-10-05

- Move Motif's synthetic T0–T3 evaluation sets into this repository.
- Add a structural self-check for sets, task prompts, answer files, and per-set licences.

## Versioning

Releases use Semantic Versioning and tags named `vMAJOR.MINOR.PATCH`. Motif pins both the tag and its full Git commit hash. A changed set, task, prompt, answer, or licence record requires a new release tag and commit hash in Motif's lock file.
