[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = $PSScriptRoot
$setsRoot = Join-Path $repositoryRoot 'evals/sets'
$errors = [Collections.Generic.List[string]]::new()

# Evidence states and the grader types the current Motif harness can run. A task whose graders need any other
# type stays `future` until the harness implements it.
$evidenceStates = @('settled', 'insufficient', 'underdetermined', 'false-alarm', 'quiet-defect')
$harnessGraders = @('coverage', 'negatives', 'parsimony', 'proposal', 'answer', 'safety')
$keyedGraders = @('answer', 'rubric', 'proposal')
$rubricActions = @('propose', 'no_change', 'abstain', 'ask', 'report-defect')
# Words that mark a prompt as a test rather than a linguist's request (R3: remove benchmark fingerprints).
$fingerprints = @('gold', 'grader', 'answer key', 'eval', 'held-out', 'heldout', 'benchmark', 'test set', 'synthetic')

function Test-InsideTask([string] $TaskDirectory, [string] $RelativePath) {
    $path = [IO.Path]::GetFullPath((Join-Path $TaskDirectory $RelativePath))
    $prefix = [IO.Path]::GetFullPath($TaskDirectory) + [IO.Path]::DirectorySeparatorChar
    return $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $path -PathType Leaf)
}

if (-not (Test-Path -LiteralPath $setsRoot -PathType Container)) {
    throw "Set directory not found: $setsRoot"
}

$sets = @(Get-ChildItem -LiteralPath $setsRoot -Directory)
if ($sets.Count -eq 0) { $errors.Add("No sets found under $setsRoot") }

foreach ($set in $sets) {
    $setRoot = $set.FullName
    foreach ($relativePath in @(
            'LICENSES',
            'language/language.yaml',
            'words/train.txt',
            'words/heldout.txt',
            'words/negative.txt',
            'gold/analyses.jsonl'
        )) {
        if (-not (Test-Path -LiteralPath (Join-Path $setRoot $relativePath) -PathType Leaf)) {
            $errors.Add("$($set.Name): missing $relativePath")
        }
    }

    $heldout = @()
    $heldoutPath = Join-Path $setRoot 'words/heldout.txt'
    if (Test-Path -LiteralPath $heldoutPath -PathType Leaf) {
        $heldout = @(Get-Content -LiteralPath $heldoutPath | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    # The spec's description becomes the project description an agent can read, so it must not name the set.
    $languagePath = Join-Path $setRoot 'language/language.yaml'
    if (Test-Path -LiteralPath $languagePath -PathType Leaf) {
        try {
            $language = Get-Content -LiteralPath $languagePath -Raw | ConvertFrom-Json -AsHashtable
            $description = [string]$language['description']
            if ($description -match '(?i)\beval\b|eval-t\d|synthetic example' -or $description.Contains($set.Name)) {
                $errors.Add("$($set.Name): language description is copied into the project and must not name the set or say 'eval'")
            }
        }
        catch { $errors.Add("${languagePath} is not valid JSON-compatible YAML: $($_.Exception.Message)") }
    }

    $tasksRoot = Join-Path $setRoot 'tasks'
    if (-not (Test-Path -LiteralPath $tasksRoot -PathType Container)) { continue }
    foreach ($taskDirectory in Get-ChildItem -LiteralPath $tasksRoot -Directory) {
        $taskPath = Join-Path $taskDirectory.FullName 'task.yaml'
        if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
            $errors.Add("$($taskDirectory.FullName): missing task.yaml")
            continue
        }

        try { $task = Get-Content -LiteralPath $taskPath -Raw | ConvertFrom-Json -AsHashtable }
        catch {
            $errors.Add("$taskPath is not valid JSON-compatible YAML: $($_.Exception.Message)")
            continue
        }

        if (-not $task.Contains('evidenceState') -or $task.evidenceState -notin $evidenceStates) {
            $errors.Add("${taskPath}: evidenceState must be one of $($evidenceStates -join ', ')")
        }
        if (-not $task.Contains('behaviour') -or [string]::IsNullOrWhiteSpace([string]$task.behaviour)) {
            $errors.Add("${taskPath}: task has no behaviour")
        }
        if ($task.Contains('set') -and $task.set -ne $set.Name) {
            $errors.Add("${taskPath}: set '$($task.set)' does not match its directory '$($set.Name)'")
        }

        if (-not $task.prompt) {
            $errors.Add("${taskPath}: task has no prompt path")
        }
        elseif (-not (Test-InsideTask $taskDirectory.FullName ([string]$task.prompt))) {
            $errors.Add("${taskPath}: prompt is missing or outside its task directory: $($task.prompt)")
        }
        else {
            $promptFiles = @(Join-Path $taskDirectory.FullName ([string]$task.prompt))
            $variants = Join-Path $taskDirectory.FullName 'prompt-variants'
            if (Test-Path -LiteralPath $variants -PathType Container) {
                $promptFiles += @(Get-ChildItem -LiteralPath $variants -File | ForEach-Object { $_.FullName })
            }
            foreach ($promptFile in $promptFiles) {
                $text = Get-Content -LiteralPath $promptFile -Raw
                foreach ($fingerprint in $fingerprints) {
                    if ($text -match ('(?i)\b' + [regex]::Escape($fingerprint) + '\b')) {
                        $errors.Add("${promptFile}: prompt contains the test fingerprint '$fingerprint'")
                    }
                }
                if ($text.Contains($set.Name)) { $errors.Add("${promptFile}: prompt names its set") }
                if ($task.family -eq 'build') {
                    $tokens = [Collections.Generic.HashSet[string]]::new([string[]]@([regex]::Matches($text, '\p{L}+') | ForEach-Object { $_.Value }))
                    foreach ($word in $heldout) {
                        if ($tokens.Contains($word)) { $errors.Add("${promptFile}: build prompt quotes held-out word '$word'") }
                    }
                }
            }
        }

        $goldAnswer = Join-Path $taskDirectory.FullName 'gold-solution/answer.yaml'
        if (-not (Test-Path -LiteralPath $goldAnswer -PathType Leaf)) {
            $errors.Add("${taskPath}: missing gold-solution/answer.yaml")
        }

        $graderTypes = @($task.graders | ForEach-Object { [string]$_.type })
        $unsupported = @($graderTypes | Where-Object { $_ -notin $harnessGraders })
        $isFuture = ($task.Contains('status') -and $task.status -eq 'future') -or
            ($task.Contains('availability') -and $task.availability -eq 'future')
        if ($unsupported.Count -gt 0 -and -not $isFuture) {
            $errors.Add("${taskPath}: active task uses grader(s) the harness lacks: $($unsupported -join ', ')")
        }
        if ($isFuture -and (-not $task.Contains('blockedBy') -or @($task.blockedBy).Count -eq 0)) {
            $errors.Add("${taskPath}: future task must say what it is blocked by")
        }

        foreach ($grader in @($task.graders)) {
            if ($grader.type -notin $keyedGraders) { continue }
            if ($grader.type -eq 'proposal' -and -not $grader.Contains('key')) { $grader.key = 'answer.yaml' }
            if (-not $grader.Contains('key') -or -not $grader.key) {
                $errors.Add("${taskPath}: $($grader.type) grader has no key")
                continue
            }
            if (-not (Test-InsideTask $taskDirectory.FullName ([string]$grader.key))) {
                $errors.Add("${taskPath}: answer key is missing or outside its task directory: $($grader.key)")
                continue
            }
            if ($grader.type -ne 'rubric') { continue }

            $keyPath = Join-Path $taskDirectory.FullName ([string]$grader.key)
            try { $key = Get-Content -LiteralPath $keyPath -Raw | ConvertFrom-Json -AsHashtable }
            catch {
                $errors.Add("${keyPath} is not valid JSON-compatible YAML: $($_.Exception.Message)")
                continue
            }
            if (-not $key.Contains('decision') -or $key.decision.action -notin $rubricActions) {
                $errors.Add("${keyPath}: rubric key needs decision.action in $($rubricActions -join ', ')")
            }
            if ($key.Contains('evidenceState') -and $task.Contains('evidenceState') -and $key.evidenceState -ne $task.evidenceState) {
                $errors.Add("${keyPath}: evidenceState differs from task.yaml")
            }
            if (-not $key.Contains('mustNot') -or @($key.mustNot).Count -eq 0) {
                $errors.Add("${keyPath}: rubric key must list what must not be done")
            }
            $criteria = if ($key.Contains('rubric')) { @($key.rubric) } else { @() }
            if (@($criteria | Where-Object { $_.points -gt 0 }).Count -eq 0 -or
                @($criteria | Where-Object { $_.points -lt 0 }).Count -eq 0) {
                $errors.Add("${keyPath}: rubric needs at least one reward and one penalty criterion")
            }
            if ($key.decision.action -in @('no_change', 'abstain', 'ask') -and
                (-not $task.Contains('goldOperationCount') -or [int]$task.goldOperationCount -ne 0)) {
                $errors.Add("${taskPath}: a $($key.decision.action) task must declare goldOperationCount 0")
            }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ -ErrorAction Continue }
    exit 1
}

Write-Host "Checked $($sets.Count) sets under $setsRoot."
