# Synthetic grammar evaluation sets

These sets give grammar-building tasks a known answer without importing a real language or project. Each task also states what the evidence it shows can and cannot decide, so it tests whether an agent knows when to act, when to say the data is insufficient, and when to ask the linguist. The word lists, grammar specs and gold analyses are committed; generated FieldWorks projects live under the caller's temporary output directory.

## Language spec

`language/language.yaml` is JSON syntax inside a `.yaml` file. JSON is a YAML 1.2 subset, which lets the dependency-free .NET generator read the same file on every supported platform. Keep IDs stable and lowercase with hyphens. Each spec records a `seed`, `tier`, synthetic language name, phoneme inventory, natural classes, stems with category and gloss, morphosyntactic and phonological feature definitions, environments, affixes with slots and feature assignments, ordered templates, generation patterns, phonological rules, reduplication rules, and named defects. Phonological feature values are assigned to phonemes through `phonemeFeatures`. An allomorph may name a `morphType` and `positionEnvironment` for infix data. A generation pattern pairs a part of speech with an ordered affix sequence and a `train` or `heldout` partition.

The spec's `description` becomes the FieldWorks project description, which an agent can read. Keep it an honest, neutral statement that the language is invented; do not put the set id, "eval" or test wording in it. The `disclaimer` stays in the spec for people reading this repository.

Allomorph environments in the current generator use a simple representation such as `/[V]_` or `/[C]_`. The corresponding natural class supplies the segments used to choose a surface form. Forms are built by adding one affix at a time; the first listed allomorph whose environment and required stem features match is written into both the word and its gold analysis. The one phonological rule then applies to the whole word. The seed controls stable word-list order. T0 permits unconditioned allomorphs; T1 requires at least one environment-conditioned allomorph.

The shared LibLCM sample builder authors the project's phonemes, lexical categories, entries, morphosyntactic and phonological features, natural classes, environments, affix slots, templates, affixes, and senses. `empty-grammar` keeps only phonemes, categories, and stem entries. `gold-grammar` adds the declared morphology. A named `gold-minus:<defect-id>` applies the defect patch in the language spec to the gold grammar. T0 through T3 each have a committed language and real-parser proof. Reduplication authoring and infix word generation remain later work.

## The four languages

Every set has 30 nouns and 30 verbs drawn from its own phoneme inventory and syllable profile. No two sets share a stem, and no stem is another stem with one sound added or removed. Each set has 180 training words, 60 held-out words, 120 negatives and 240 gold analyses. Motif's verification tests pin those counts.

| Set | What it adds | Suffixes |
|---|---|---|
| `eval-t0-qaxu` | Ordered optional suffix slots; no allomorphy | PL `-wa`, LOC `-ni`; PST `-ta`, 1SG `-mu` |
| `eval-t1-vexu` | Plural and past allomorphs chosen by the stem's last sound | PL `-ra` after a vowel, `-ta` after a consonant; LOC `-ki`; PST `-nu`/`-du`; 1SG `-me` |
| `eval-t2-lomi` | An obligatory class ending chosen by each noun's lexical class, which does not follow from the stem's sound; sound-conditioned past | NCL `-na` (class A) / `-ta` (class B); PL `-ri`; LOC `-de`; PST `-ka`/`-uka`; 1SG `-mi` |
| `eval-t3-panu` | Stem-final *n* becomes *m* before a suffix beginning with a bilabial, so the stem alternates (`kogun`, `koguneso`, `kogumpa`) | PL `-so`/`-eso`; LOC `-pa`; PST `-ti`/`-iti`; 1SG `-mo` |

In every set, training words carry at most one inflectional suffix besides T2's class ending. The order of two suffixes is therefore not attested in training: tasks either state that order as the linguist's own knowledge or test whether the agent says it cannot be decided.

## Generate, build, verify

From the Motif repository root:

```sh
dotnet run --project evals/tools/SIL.Motif.EvalSets -- build \
  --set <test-grammars>/evals/sets/eval-t0-qaxu --start empty-grammar --out /tmp/eval-t0-empty
dotnet run --project evals/tools/SIL.Motif.EvalSets -- verify \
  --set <test-grammars>/evals/sets/eval-t0-qaxu --out /tmp/eval-t0-verify
```

`build` refreshes `words/train.txt`, `words/heldout.txt`, `words/negative.txt`, and `gold/analyses.jsonl`, then prints the generated `.fwdata` path as JSON. The A/B runner uses `build-project`, which checks the committed generated files against the language spec without rewriting them before it creates a project. On Linux or macOS, set `MOTIF_SIL_ICU_STAGE` to the staged SIL ICU folder before building or testing, and set `MOTIF_PANGLOSS_EXE` for `verify`. `verify` first checks that the committed word lists and gold analyses still match the language spec, then builds the gold grammar and asks the real PanGloss executable to parse every positive and negative word. A set passes only when every train and held-out word has its exact ordered gold morphology and no negative word parses. For a diagnosis defect visible in the committed partitions, pass `--start gold-minus:<defect-id>` to `verify`: it reports matched positives and parsed negatives and fails if no committed parse changes. Incomplete parser results fail in either mode. A failure is a generator, grammar, or parser-contract defect; do not weaken the check to hide one.

## Add a language

1. Create `evals/sets/<set-id>/language/language.yaml` with at least 30 stems and complete sound, category, affix, slot, feature, and template data. Draw stems from a plausible syllable profile; avoid letters or clusters that occur nowhere else in the language, and keep stems and affix shapes distinct from other sets.
2. Add patterns for every training combination and reserve different stem-affix sequences for held-out patterns. Keep generated counts near 150–400 train words and 50–150 held-out words. Check that the training patterns can actually decide what a build task grades; if they cannot, say so in the task.
3. Name each deliberate defect and make its patch change exactly one property. Verify the gold grammar with real PanGloss before committing word lists. For a defect used as a task start state, parse the positives and a few probe words under that defect and record what changes.
4. Keep negative examples plausible: reverse a declared slot sequence, select the wrong conditioned allomorph, or append a phonologically legal but undeclared affix. Include at least 50, and confirm none parse. The generator's appended `qx` negatives are a known weakness; give the first affix of each held-out pattern two allomorphs where the tier allows it.

## Add a task

Each `tasks/<task-id>/` contains `task.yaml`, a linguist-phrased `prompt.md`, and `gold-solution/answer.yaml`. A grader key, when one is used, is `answer.yaml` in the same folder. Keys are evaluator-only: the harness must never mount this checkout, or any task folder, where the agent's process can read it.

`task.yaml` fields:

- `family`: `build`, `edit`, `diagnose`, `lexicon`, or `safety`; `start`: `empty-grammar`, `gold-grammar`, or `gold-minus:<defect-id>`.
- `evidenceState`: what the evidence the agent sees can decide. `settled`: it decides the answer, so the agent should act and say why. `insufficient`: it cannot decide, so the agent should propose nothing and name the evidence that would decide. `underdetermined`: a speaker could decide it, so the agent should ask one evidence-backed question. `false-alarm`: a warning or failure looks alarming but the grammar is right. `quiet-defect`: everything looks fine but the grammar over-generates.
- `behaviour`: a short label for the expected behaviour (for example `best-way`, `insufficient-data`, `ask-linguist`, `false-flag`, `quiet-overgeneration`).
- `status` or `availability`: `active` when the current MCP tools and harness graders can run the task, `future` otherwise. A future task lists `blockedBy` (for example `composer:template`, `grader:rubric`, `simulated-linguist`).
- `goldOperationCount`: required as `0` for tasks whose right answer changes nothing, so the parsimony grader fails any edit.
- `twin`: the matched task whose evidence differs by one deciding fact.

A `rubric` key (`answer.yaml`) gives a structured `decision.action` (`propose`, `no_change`, `abstain`, `ask`, `report-defect`), `proposal.maxOperations`, a `mustNot` list, and weighted `rubric` criteria. A criterion is a reward when its points are positive and a penalty when they are negative; a penalty marked `hardFail` scores the trial 0. Ask tasks carry a `simulatedLinguist` fact table that answers only the atomic fact asked. The harness maps active `rubric` graders to the control-side meaning judge and enforces Proposal limits deterministically. Ask tasks end with one question; a simulated speaker reply is not part of the trial.

The active tasks include judgment tasks on T0–T2 and class-conditioning and boundary-assimilation diagnoses on T2–T3, alongside gloss corrections, missing-primary-form repairs and safety tasks. The harness captures each starting project's Baseline before either arm starts, because the lean profile does not expose `motif_capture_baseline`. Keep prompts natural and identical across A/B arms. Two build tasks include `prompt-variants/agent-ish.md`, a short replacement request that preserves the shared examples and training-word block while changing the phrasing.

`Check-TestGrammars.ps1` enforces the structure and these rules:

- evidence states;
- rubric keys with penalties and a must-not list;
- no active task that needs a missing grader;
- no test fingerprints or set ids in prompts;
- no held-out word in a build prompt;
- a neutral project description.

## Tier ladder and anti-overfitting

T0 uses agglutinative suffixes without allomorphy. T1 adds sound-conditioned allomorphs. T2 adds an obligatory slot and allomorphs conditioned by a lexical class. T3 adds a phonological rule that applies across a morpheme boundary. T4 covers infixes or reduplication and remains future work. Every held-out word uses a stem-affix sequence absent from training. Do not copy held-out analyses into a build prompt. Negatives should use the language's phoneme inventory and differ from a positive word by a specific grammatical error, rather than being random strings. Prefer the smallest and most restrictive grammar that explains the examples; a broad rule that memorizes training words should lose on held-out forms, negatives, or parsimony. Keep every form invented and avoid adapting a real language's vocabulary or rules.
