# Synthetic grammar evaluation sets

These sets give grammar-building tasks an exact answer without importing a real language or project. The word lists, grammar specs, and gold analyses are committed; generated FieldWorks projects live under the caller’s temporary output directory.

## Language spec

`language/language.yaml` is JSON syntax inside a `.yaml` file. JSON is a YAML 1.2 subset, which lets the dependency-free .NET generator read the same file on every supported platform. Keep IDs stable and lowercase with hyphens. Each spec records a `seed`, `tier`, synthetic language name, phoneme inventory, natural classes, stems with category and gloss, morphosyntactic and phonological feature definitions, environments, affixes with slots and feature assignments, ordered templates, generation patterns, phonological rules, reduplication rules, and named defects. Phonological feature values are assigned to phonemes through `phonemeFeatures`. An allomorph may name a `morphType` and `positionEnvironment` for infix data. A generation pattern pairs a part of speech with an ordered affix sequence and a `train` or `heldout` partition.

Allomorph environments in the current generator use a simple representation such as `/[V]_` or `/[C]_`. The corresponding natural class supplies the segments used to choose a surface form. Forms are built by adding one affix at a time; the selected allomorph is written into both the word and its gold analysis. The seed controls stable word-list order. T0 permits unconditioned allomorphs; T1 requires at least one environment-conditioned allomorph.

The shared LibLCM sample builder authors the project's phonemes, lexical categories, entries, morphosyntactic and phonological features, natural classes, environments, affix slots, templates, affixes, and senses. `empty-grammar` keeps only phonemes, categories, and stem entries. `gold-grammar` adds the declared morphology. A named `gold-minus:<defect-id>` applies the defect patch in the language spec to the gold grammar. T0 through T3 each have a committed language and real-parser proof. Reduplication authoring and infix word generation remain later work.

## Generate, build, verify

From the repository root:

```sh
dotnet run --project evals/tools/SIL.Motif.EvalSets -- build \
  --set evals/sets/eval-t0-qaxu --start empty-grammar --out /tmp/eval-t0-empty
dotnet run --project evals/tools/SIL.Motif.EvalSets -- verify \
  --set evals/sets/eval-t0-qaxu --out /tmp/eval-t0-verify
```

`build` refreshes `words/train.txt`, `words/heldout.txt`, `words/negative.txt`, and `gold/analyses.jsonl`, then prints the generated `.fwdata` path as JSON. The A/B runner uses `build-project`, which checks the committed generated files against the language spec without rewriting them before it creates a project. On Linux or macOS, set `MOTIF_SIL_ICU_STAGE` to the staged SIL ICU folder before building or testing. `verify` first checks that the committed word lists and gold analyses still match the language spec, then builds the gold grammar and asks the configured real PanGloss executable to parse every positive and negative word. A set passes only when every train and held-out word has its exact ordered gold morphology and no negative word parses. A failure is a generator, grammar, or parser-contract defect; do not weaken the check to hide one.

## Add a language

1. Create `evals/sets/<set-id>/language/language.yaml` with at least 30 stems and complete sound, category, affix, slot, feature, and template data.
2. Add patterns for every training combination and reserve different stem-affix sequences for held-out patterns. Keep generated counts near 150–400 train words and 50–150 held-out words.
3. Name each deliberate defect and make its patch change exactly one property. Verify the gold grammar with real PanGloss before committing word lists or changing a task to depend on the new construct.
4. Keep negative examples plausible: reverse a declared slot sequence, select the wrong conditioned allomorph, or append a phonologically legal but undeclared affix. Include at least 50, and confirm none parse.

## Add a task

Each `tasks/<task-id>/` contains `task.yaml`, a linguist-phrased `prompt.md`, and `gold-solution/answer.yaml` when a useful target can be stated. `status` or `availability` is `active` when the current MCP tools can do the work and `future` when the task needs a composer Motif does not have yet; the first A/B run selects active tasks only. Diagnose tasks grade the expected defect category and object. Current lexicon tasks restore a missing primary lexeme form on an existing entry or correct an existing sense gloss. Adding an alternate form or affix allomorph remains future work because the current MCP tools cannot create `AlternateFormsOS` allomorphs. Safety tasks grade both a grounded refusal and the hard-fail `safety` rule against prohibited tool attempts.

Tasks use `build`, `edit`, `diagnose`, `lexicon`, or `safety`, and begin from `empty-grammar`, `gold-grammar`, or one named defect. Current task metadata marks eight tasks active across T0 and T1: two diagnosis tasks, two gloss corrections, two missing-primary-form repairs, and two safety tasks. Grammar construction and grammar-object edits stay in the set as future tasks until MCP can author those objects. For the first default-versus-lean profile A/B, use these eight active tasks and have the harness capture each starting project's Baseline before either arm starts: the lean profile does not expose `motif_capture_baseline`. Keep prompts natural and identical across A/B arms. Two build tasks include `prompt-variants/agent-ish.md`, a short replacement request that preserves the shared examples and training-word block while changing the phrasing.

## Tier ladder and anti-overfitting

T0 uses agglutinative suffixes without allomorphy. T1 adds sound-conditioned allomorphs. T2 adds richer templates, feature combinations, and obligatory slots. T3 adds a phonological rule such as assimilation or harmony. T4 covers infixes or reduplication. T0 through T3 are committed and parser-verified; T4 remains future work. Every held-out word uses a stem-affix sequence absent from training. Do not copy held-out analyses into a build prompt. Negatives should use the language's phoneme inventory and differ from a positive word by a specific grammatical error, rather than being random strings. Prefer the smallest grammar that explains the examples; a broad rule that memorizes training words should lose on held-out forms, negatives, or parsimony. Keep every form invented and avoid adapting a real language's vocabulary or rules.
