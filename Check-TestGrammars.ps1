[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = $PSScriptRoot
$setsRoot = Join-Path $repositoryRoot 'evals/sets'
$errors = [Collections.Generic.List[string]]::new()

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

        if (-not $task.prompt) {
            $errors.Add("${taskPath}: task has no prompt path")
        }
        else {
            $promptPath = [IO.Path]::GetFullPath((Join-Path $taskDirectory.FullName ([string]$task.prompt)))
            $taskPrefix = [IO.Path]::GetFullPath($taskDirectory.FullName) + [IO.Path]::DirectorySeparatorChar
            if (-not $promptPath.StartsWith($taskPrefix, [StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
                $errors.Add("${taskPath}: prompt is missing or outside its task directory: $($task.prompt)")
            }
        }

        $goldAnswer = Join-Path $taskDirectory.FullName 'gold-solution/answer.yaml'
        if (-not (Test-Path -LiteralPath $goldAnswer -PathType Leaf)) {
            $errors.Add("${taskPath}: missing gold-solution/answer.yaml")
        }

        foreach ($grader in @($task.graders)) {
            if ($grader.type -ne 'answer') { continue }
            if (-not $grader.key) {
                $errors.Add("${taskPath}: answer grader has no key")
                continue
            }
            $answerPath = [IO.Path]::GetFullPath((Join-Path $taskDirectory.FullName ([string]$grader.key)))
            $taskPrefix = [IO.Path]::GetFullPath($taskDirectory.FullName) + [IO.Path]::DirectorySeparatorChar
            if (-not $answerPath.StartsWith($taskPrefix, [StringComparison]::OrdinalIgnoreCase) -or
                -not (Test-Path -LiteralPath $answerPath -PathType Leaf)) {
                $errors.Add("${taskPath}: answer key is missing or outside its task directory: $($grader.key)")
            }
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Checked $($sets.Count) sets under $setsRoot."
