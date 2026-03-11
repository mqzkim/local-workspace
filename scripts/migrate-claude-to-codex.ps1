[CmdletBinding()]
param(
  [switch]$Clean = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Workspace = (Resolve-Path ".").Path
$SourceRoot = Join-Path $Workspace ".claude"
$TargetRoot = Join-Path $Workspace ".codex"
$TargetSkillsRoot = Join-Path $TargetRoot "skills"
$MigrationDate = Get-Date -Format "yyyy-MM-dd"
$MigrationTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"

if (-not (Test-Path $SourceRoot)) {
  throw "Source folder not found: $SourceRoot"
}

function Ensure-Directory {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function To-SkillSlug {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) {
    return "skill"
  }
  $slug = $Value.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
  $slug = $slug.Trim("-")
  if ([string]::IsNullOrWhiteSpace($slug)) {
    $slug = "skill"
  }
  if ($slug.Length -gt 63) {
    $slug = $slug.Substring(0, 63).TrimEnd("-")
  }
  if ([string]::IsNullOrWhiteSpace($slug)) {
    $slug = "skill"
  }
  return $slug
}

function Escape-YamlDoubleQuoted {
  param([string]$Value)
  if ($null -eq $Value) {
    return ""
  }
  return ($Value -replace "\\", "\\\\" -replace '"', '\"')
}

function Parse-Frontmatter {
  param([string]$Content)

  $metadata = @{}
  $body = $Content
  $hasFrontmatter = $false

  $match = [regex]::Match(
    $Content,
    "\A---\r?\n(?<fm>.*?)\r?\n---\r?\n?(?<body>[\s\S]*)\z",
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  if ($match.Success) {
    $hasFrontmatter = $true
    $frontmatter = $match.Groups["fm"].Value
    $body = $match.Groups["body"].Value

    foreach ($line in ($frontmatter -split "\r?\n")) {
      if ($line -match "^\s*([A-Za-z0-9_-]+)\s*:\s*(.*)\s*$") {
        $key = $Matches[1].ToLowerInvariant()
        $value = $Matches[2].Trim()

        if (
          (($value.StartsWith('"')) -and ($value.EndsWith('"')) -and ($value.Length -ge 2)) -or
          (($value.StartsWith("'")) -and ($value.EndsWith("'")) -and ($value.Length -ge 2))
        ) {
          $value = $value.Substring(1, $value.Length - 2)
        }

        $metadata[$key] = $value
      }
    }
  }

  return [pscustomobject]@{
    HasFrontmatter = $hasFrontmatter
    Metadata = $metadata
    Body = $body
  }
}

function Get-FirstHeading {
  param([string]$Body)
  foreach ($line in ($Body -split "\r?\n")) {
    if ($line -match "^\s{0,3}#{1,6}\s+(.+?)\s*$") {
      return $Matches[1].Trim()
    }
  }
  return ""
}

function Get-LeadTextLine {
  param([string]$Body)
  foreach ($line in ($Body -split "\r?\n")) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
      continue
    }
    if ($trimmed.StartsWith("#")) {
      continue
    }
    if ($trimmed.StartsWith(">")) {
      continue
    }
    if ($trimmed.StartsWith("-") -or $trimmed.StartsWith("*")) {
      continue
    }
    return $trimmed
  }
  return ""
}

function Normalize-Description {
  param(
    [string]$Text,
    [string]$Fallback
  )

  $candidate = $Text
  if ([string]::IsNullOrWhiteSpace($candidate)) {
    $candidate = $Fallback
  }
  $candidate = ($candidate -replace "\s+", " ").Trim()
  if ([string]::IsNullOrWhiteSpace($candidate)) {
    $candidate = $Fallback
  }
  return $candidate
}

function Build-SkillDocument {
  param(
    [string]$Name,
    [string]$Description,
    [string]$Body,
    [hashtable]$Metadata,
    [string]$SourcePath,
    [string]$CategoryNote
  )

  $escapedDescription = Escape-YamlDoubleQuoted $Description
  $builder = [System.Text.StringBuilder]::new()

  [void]$builder.AppendLine("---")
  [void]$builder.AppendLine("name: $Name")
  [void]$builder.AppendLine("description: ""$escapedDescription""")
  [void]$builder.AppendLine("---")
  [void]$builder.AppendLine()
  [void]$builder.AppendLine("> Migrated from `"$SourcePath`" on $MigrationDate.")
  if (-not [string]::IsNullOrWhiteSpace($CategoryNote)) {
    [void]$builder.AppendLine("> $CategoryNote")
  }

  $metadataLines = @()
  foreach ($key in ($Metadata.Keys | Sort-Object)) {
    if ($key -in @("name", "description")) {
      continue
    }
    $value = $Metadata[$key]
    if ([string]::IsNullOrWhiteSpace($value)) {
      continue
    }
    $safeValue = ($value -replace "\r?\n", " ").Trim()
    $metadataLines += "- **$key**: `"$safeValue`""
  }

  if ($metadataLines.Count -gt 0) {
    [void]$builder.AppendLine()
    [void]$builder.AppendLine("## Migrated Metadata")
    foreach ($line in $metadataLines) {
      [void]$builder.AppendLine($line)
    }
  }

  [void]$builder.AppendLine()
  [void]$builder.AppendLine("## Source Content")
  [void]$builder.AppendLine()

  $trimmedBody = $Body.Trim()
  if ([string]::IsNullOrWhiteSpace($trimmedBody)) {
    [void]$builder.AppendLine("_No content found in source file._")
  } else {
    [void]$builder.AppendLine($trimmedBody)
  }

  return $builder.ToString()
}

function Write-Skill {
  param(
    [string]$TargetDir,
    [string]$SkillName,
    [string]$Description,
    [string]$Body,
    [hashtable]$Metadata,
    [string]$SourcePath,
    [string]$CategoryNote
  )

  Ensure-Directory $TargetDir
  $document = Build-SkillDocument -Name $SkillName -Description $Description -Body $Body -Metadata $Metadata -SourcePath $SourcePath -CategoryNote $CategoryNote
  Set-Content -Path (Join-Path $TargetDir "SKILL.md") -Value $document -Encoding utf8
}

$usedSkillNames = @{}
function Get-UniqueSkillName {
  param([string]$BaseName)
  $slug = To-SkillSlug $BaseName
  if (-not $usedSkillNames.ContainsKey($slug)) {
    $usedSkillNames[$slug] = 1
    return $slug
  }

  $index = [int]$usedSkillNames[$slug]
  while ($usedSkillNames.ContainsKey("$slug-$index")) {
    $index += 1
  }
  $uniqueName = "$slug-$index"
  $usedSkillNames[$slug] = $index + 1
  $usedSkillNames[$uniqueName] = 1
  return $uniqueName
}

$mappings = New-Object System.Collections.Generic.List[object]
function Add-Mapping {
  param(
    [string]$Category,
    [string]$Source,
    [string]$SkillName,
    [string]$TargetDir
  )
  $mappings.Add([pscustomobject]@{
    Category = $Category
    Source = $Source
    SkillName = $SkillName
    Target = (Join-Path $TargetDir "SKILL.md")
  }) | Out-Null
}

if ($Clean -and (Test-Path $TargetSkillsRoot)) {
  Remove-Item -Path $TargetSkillsRoot -Recurse -Force
}

Ensure-Directory $TargetRoot
Ensure-Directory $TargetSkillsRoot

$countDirectorySkills = 0
$countFlatSkills = 0
$countAgents = 0
$countCommands = 0
$countRules = 0
$countOutputStyles = 0

$skillsSource = Join-Path $SourceRoot "skills"
if (Test-Path $skillsSource) {
  $directorySkills = Get-ChildItem -Path $skillsSource -Directory | Sort-Object Name
  foreach ($dir in $directorySkills) {
    $skillFile = Join-Path $dir.FullName "SKILL.md"
    if (-not (Test-Path $skillFile)) {
      continue
    }

    $parsed = Parse-Frontmatter -Content (Get-Content -Raw -Path $skillFile)
    $rawName = if ($parsed.Metadata.ContainsKey("name")) { $parsed.Metadata["name"] } else { $dir.Name }
    $skillName = Get-UniqueSkillName $rawName
    $rawDescription = if ($parsed.Metadata.ContainsKey("description")) { $parsed.Metadata["description"] } else { "" }
    $fallbackDescription = "Migrated skill from .claude/skills/$($dir.Name)."
    $description = Normalize-Description -Text $rawDescription -Fallback $fallbackDescription
    $targetDir = Join-Path $TargetSkillsRoot $skillName

    if (Test-Path $targetDir) {
      Remove-Item -Path $targetDir -Recurse -Force
    }
    Ensure-Directory $targetDir
    Copy-Item -Path (Join-Path $dir.FullName "*") -Destination $targetDir -Recurse -Force

    Write-Skill -TargetDir $targetDir -SkillName $skillName -Description $description -Body $parsed.Body -Metadata $parsed.Metadata -SourcePath ".claude/skills/$($dir.Name)/SKILL.md" -CategoryNote "Migrated from a Claude directory-style skill."
    Add-Mapping -Category "skill-directory" -Source ".claude/skills/$($dir.Name)/SKILL.md" -SkillName $skillName -TargetDir $targetDir
    $countDirectorySkills += 1
  }

  $flatSkills = Get-ChildItem -Path $skillsSource -File -Filter "*.md" | Sort-Object Name
  foreach ($file in $flatSkills) {
    $parsed = Parse-Frontmatter -Content (Get-Content -Raw -Path $file.FullName)
    $rawName = if ($parsed.Metadata.ContainsKey("name")) { $parsed.Metadata["name"] } else { [System.IO.Path]::GetFileNameWithoutExtension($file.Name) }
    $skillName = Get-UniqueSkillName $rawName
    $heading = Get-FirstHeading -Body $parsed.Body
    $leadText = Get-LeadTextLine -Body $parsed.Body
    $rawDescription = if ($parsed.Metadata.ContainsKey("description")) { $parsed.Metadata["description"] } elseif (-not [string]::IsNullOrWhiteSpace($leadText)) { $leadText } else { $heading }
    $fallbackDescription = "Migrated domain guidance from .claude/skills/$($file.Name)."
    $description = Normalize-Description -Text $rawDescription -Fallback $fallbackDescription
    $targetDir = Join-Path $TargetSkillsRoot $skillName

    Write-Skill -TargetDir $targetDir -SkillName $skillName -Description $description -Body $parsed.Body -Metadata $parsed.Metadata -SourcePath ".claude/skills/$($file.Name)" -CategoryNote "Migrated from a Claude flat-style skill."
    Add-Mapping -Category "skill-flat" -Source ".claude/skills/$($file.Name)" -SkillName $skillName -TargetDir $targetDir
    $countFlatSkills += 1
  }
}

$agentsSource = Join-Path $SourceRoot "agents"
if (Test-Path $agentsSource) {
  $agentFiles = Get-ChildItem -Path $agentsSource -File -Filter "*.md" | Sort-Object Name
  foreach ($file in $agentFiles) {
    $parsed = Parse-Frontmatter -Content (Get-Content -Raw -Path $file.FullName)
    $rawAgentName = if ($parsed.Metadata.ContainsKey("name")) { $parsed.Metadata["name"] } else { [System.IO.Path]::GetFileNameWithoutExtension($file.Name) }
    $skillName = Get-UniqueSkillName ("team-agent-" + (To-SkillSlug $rawAgentName))
    $agentDescription = if ($parsed.Metadata.ContainsKey("description")) { $parsed.Metadata["description"] } else { "Team agent prompt profile." }
    $description = Normalize-Description -Text "Team-agent profile migrated from .claude/agents/$($file.Name). Use for tasks aligned with this specialist role: $agentDescription" -Fallback "Team-agent profile migrated from .claude/agents/$($file.Name)."
    $targetDir = Join-Path $TargetSkillsRoot $skillName

    $bodyPrefix = @"
# Team Agent Profile: $rawAgentName

Use this skill when a task should follow this specialist persona.
Interpret the original instructions as role guidance for Codex execution.

"@
    $body = $bodyPrefix + ($parsed.Body.Trim())

    Write-Skill -TargetDir $targetDir -SkillName $skillName -Description $description -Body $body -Metadata $parsed.Metadata -SourcePath ".claude/agents/$($file.Name)" -CategoryNote "Migrated from a Claude team-agent definition."
    Add-Mapping -Category "agent" -Source ".claude/agents/$($file.Name)" -SkillName $skillName -TargetDir $targetDir
    $countAgents += 1
  }
}

$commandsSource = Join-Path $SourceRoot "commands"
if (Test-Path $commandsSource) {
  $commandFiles = Get-ChildItem -Path $commandsSource -File -Filter "*.md" | Sort-Object Name
  foreach ($file in $commandFiles) {
    $parsed = Parse-Frontmatter -Content (Get-Content -Raw -Path $file.FullName)
    $rawCommandName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    if ($parsed.Metadata.ContainsKey("name")) {
      $rawCommandName = $parsed.Metadata["name"]
    }
    $commandSlug = To-SkillSlug $rawCommandName
    $skillName = Get-UniqueSkillName ("command-$commandSlug")
    $heading = Get-FirstHeading -Body $parsed.Body
    $commandDescription = if ($parsed.Metadata.ContainsKey("description")) { $parsed.Metadata["description"] } else { $heading }
    $description = Normalize-Description -Text "Compatibility wrapper for former Claude command /$commandSlug. $commandDescription" -Fallback "Compatibility wrapper for former Claude command /$commandSlug."
    $targetDir = Join-Path $TargetSkillsRoot $skillName

    $bodyPrefix = @"
# Command Compatibility: /$commandSlug

Use this skill when the user requests the old Claude command `/$commandSlug` or an equivalent workflow.
Map natural-language user input to the former command arguments (`$ARGUMENTS`) as needed.

"@
    $body = $bodyPrefix + ($parsed.Body.Trim())

    Write-Skill -TargetDir $targetDir -SkillName $skillName -Description $description -Body $body -Metadata $parsed.Metadata -SourcePath ".claude/commands/$($file.Name)" -CategoryNote "Migrated from a Claude slash-command definition."
    Add-Mapping -Category "command" -Source ".claude/commands/$($file.Name)" -SkillName $skillName -TargetDir $targetDir
    $countCommands += 1
  }
}

$rulesSource = Join-Path $SourceRoot "rules"
if (Test-Path $rulesSource) {
  $ruleFiles = Get-ChildItem -Path $rulesSource -File -Filter "*.md" | Sort-Object Name
  foreach ($file in $ruleFiles) {
    $parsed = Parse-Frontmatter -Content (Get-Content -Raw -Path $file.FullName)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $skillName = Get-UniqueSkillName ("rule-$baseName")
    $heading = Get-FirstHeading -Body $parsed.Body
    $description = Normalize-Description -Text $heading -Fallback "Workspace rule migrated from .claude/rules/$($file.Name)."
    $description = Normalize-Description -Text "Rule skill migrated from .claude/rules/$($file.Name). $description" -Fallback "Rule skill migrated from .claude/rules/$($file.Name)."
    $targetDir = Join-Path $TargetSkillsRoot $skillName

    $bodyPrefix = @"
# Workspace Rule: $baseName

Apply this rule proactively when relevant to the current task.

"@
    $body = $bodyPrefix + ($parsed.Body.Trim())

    Write-Skill -TargetDir $targetDir -SkillName $skillName -Description $description -Body $body -Metadata $parsed.Metadata -SourcePath ".claude/rules/$($file.Name)" -CategoryNote "Migrated from a Claude global rule."
    Add-Mapping -Category "rule" -Source ".claude/rules/$($file.Name)" -SkillName $skillName -TargetDir $targetDir
    $countRules += 1
  }
}

$stylesSource = Join-Path $SourceRoot "output-styles"
if (Test-Path $stylesSource) {
  $styleFiles = Get-ChildItem -Path $stylesSource -File -Filter "*.md" | Sort-Object Name
  foreach ($file in $styleFiles) {
    $parsed = Parse-Frontmatter -Content (Get-Content -Raw -Path $file.FullName)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $skillName = Get-UniqueSkillName ("output-style-$baseName")
    $styleDescription = if ($parsed.Metadata.ContainsKey("description")) { $parsed.Metadata["description"] } else { "" }
    $description = Normalize-Description -Text "Output style preset migrated from .claude/output-styles/$($file.Name). $styleDescription" -Fallback "Output style preset migrated from .claude/output-styles/$($file.Name)."
    $targetDir = Join-Path $TargetSkillsRoot $skillName

    $bodyPrefix = @"
# Output Style Profile: $baseName

Use this style guide whenever the user asks for this response style.

"@
    $body = $bodyPrefix + ($parsed.Body.Trim())

    Write-Skill -TargetDir $targetDir -SkillName $skillName -Description $description -Body $body -Metadata $parsed.Metadata -SourcePath ".claude/output-styles/$($file.Name)" -CategoryNote "Migrated from a Claude output-style profile."
    Add-Mapping -Category "output-style" -Source ".claude/output-styles/$($file.Name)" -SkillName $skillName -TargetDir $targetDir
    $countOutputStyles += 1
  }
}

$reportPath = Join-Path $TargetRoot "MIGRATION_REPORT.md"
$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add("# Claude to Codex Migration Report") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("- Generated: $MigrationTimestamp") | Out-Null
$reportLines.Add("- Source root: .claude/") | Out-Null
$reportLines.Add("- Target root: .codex/skills/") | Out-Null
$reportLines.Add("- Deduplication policy: migrated workspace-local assets from .claude/{skills,agents,commands,rules,output-styles}; skipped .claude/hub/shared/* mirrors to avoid duplicates.") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("## Counts") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("- Directory skills: $countDirectorySkills") | Out-Null
$reportLines.Add("- Flat skills: $countFlatSkills") | Out-Null
$reportLines.Add("- Team agents migrated as skills: $countAgents") | Out-Null
$reportLines.Add("- Commands migrated as skills: $countCommands") | Out-Null
$reportLines.Add("- Rules migrated as skills: $countRules") | Out-Null
$reportLines.Add("- Output styles migrated as skills: $countOutputStyles") | Out-Null
$reportLines.Add("- Total generated Codex skills: $($mappings.Count)") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("## Mapping") | Out-Null
$reportLines.Add("") | Out-Null
$reportLines.Add("| Category | Source | Codex Skill | Target |") | Out-Null
$reportLines.Add("| --- | --- | --- | --- |") | Out-Null
foreach ($mapping in ($mappings | Sort-Object Category, SkillName)) {
  $reportLines.Add("| $($mapping.Category) | $($mapping.Source) | $($mapping.SkillName) | $($mapping.Target) |") | Out-Null
}

Set-Content -Path $reportPath -Value ($reportLines -join "`r`n") -Encoding utf8

Write-Output "Migration complete."
Write-Output "Generated skills: $($mappings.Count)"
Write-Output "Report: $reportPath"
