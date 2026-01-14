#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for AI Handler utility modules.

.DESCRIPTION
    Comprehensive test suite for:
    - AIUtil-JsonIO.psm1: JSON file I/O operations
    - AIUtil-Health.psm1: System and provider health checks
    - AIUtil-Validation.psm1: Prompt and code validation

.NOTES
    Pester Version: 5.x
    Author: HYDRA System
    Created: 2026-01-13
#>

BeforeAll {
    # Get paths
    $script:ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script:UtilsPath = Join-Path $script:ModuleRoot "ai-handler\utils"

    # Import modules under test
    $jsonIOPath = Join-Path $script:UtilsPath "AIUtil-JsonIO.psm1"
    $healthPath = Join-Path $script:UtilsPath "AIUtil-Health.psm1"
    $validationPath = Join-Path $script:UtilsPath "AIUtil-Validation.psm1"

    if (Test-Path $jsonIOPath) {
        Import-Module $jsonIOPath -Force -ErrorAction Stop
    }
    if (Test-Path $healthPath) {
        Import-Module $healthPath -Force -ErrorAction Stop
    }
    if (Test-Path $validationPath) {
        Import-Module $validationPath -Force -ErrorAction Stop
    }

    # Create temp directory for file tests
    $script:TestTempDir = Join-Path $env:TEMP "AIHandler-Tests-$(Get-Random)"
    New-Item -Path $script:TestTempDir -ItemType Directory -Force | Out-Null
}

AfterAll {
    # Clean up temp directory
    if ($script:TestTempDir -and (Test-Path $script:TestTempDir)) {
        Remove-Item -Path $script:TestTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Remove imported modules
    Remove-Module AIUtil-JsonIO -ErrorAction SilentlyContinue
    Remove-Module AIUtil-Health -ErrorAction SilentlyContinue
    Remove-Module AIUtil-Validation -ErrorAction SilentlyContinue
}

#region AIUtil-JsonIO Tests

Describe "AIUtil-JsonIO.psm1" -Tag "JsonIO", "Utils" {

    Context "Read-JsonFile" {

        It "Should read and parse an existing JSON file" {
            # Arrange
            $testFile = Join-Path $script:TestTempDir "test-read.json"
            $testData = @{ name = "test"; value = 123; nested = @{ key = "value" } }
            $testData | ConvertTo-Json -Depth 5 | Out-File -FilePath $testFile -Encoding UTF8

            # Act
            $result = Read-JsonFile -Path $testFile

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.name | Should -Be "test"
            $result.value | Should -Be 123
            $result.nested.key | Should -Be "value"
        }

        It "Should return default value when file does not exist" {
            # Arrange
            $nonExistentPath = Join-Path $script:TestTempDir "non-existent-$(Get-Random).json"
            $defaultValue = @{ default = $true }

            # Act
            $result = Read-JsonFile -Path $nonExistentPath -Default $defaultValue

            # Assert
            $result.default | Should -Be $true
        }

        It "Should return empty hashtable as default when file missing and no default specified" {
            # Arrange
            $nonExistentPath = Join-Path $script:TestTempDir "missing-$(Get-Random).json"

            # Act
            $result = Read-JsonFile -Path $nonExistentPath

            # Assert
            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }

        It "Should return default value for empty file" {
            # Arrange
            $emptyFile = Join-Path $script:TestTempDir "empty.json"
            "" | Out-File -FilePath $emptyFile -Encoding UTF8
            $defaultValue = @{ isEmpty = $true }

            # Act
            $result = Read-JsonFile -Path $emptyFile -Default $defaultValue

            # Assert
            $result.isEmpty | Should -Be $true
        }

        It "Should return default value for invalid JSON" {
            # Arrange
            $invalidFile = Join-Path $script:TestTempDir "invalid.json"
            "{ invalid json content" | Out-File -FilePath $invalidFile -Encoding UTF8
            $defaultValue = @{ fallback = $true }

            # Act
            $result = Read-JsonFile -Path $invalidFile -Default $defaultValue

            # Assert
            $result.fallback | Should -Be $true
        }
    }

    Context "Write-JsonFile" {

        It "Should create a new JSON file" {
            # Arrange
            $testFile = Join-Path $script:TestTempDir "test-write-$(Get-Random).json"
            $testData = @{ created = $true; timestamp = (Get-Date).ToString() }

            # Act
            $result = Write-JsonFile -Path $testFile -Data $testData

            # Assert
            $result | Should -Be $true
            Test-Path $testFile | Should -Be $true

            # Verify content
            $content = Get-Content -Path $testFile -Raw | ConvertFrom-Json
            $content.created | Should -Be $true
        }

        It "Should overwrite an existing file" {
            # Arrange
            $testFile = Join-Path $script:TestTempDir "test-overwrite.json"
            @{ original = $true } | ConvertTo-Json | Out-File -FilePath $testFile -Encoding UTF8
            $newData = @{ updated = $true; version = 2 }

            # Act
            $result = Write-JsonFile -Path $testFile -Data $newData

            # Assert
            $result | Should -Be $true
            $content = Get-Content -Path $testFile -Raw | ConvertFrom-Json
            $content.updated | Should -Be $true
            $content.version | Should -Be 2
            $content.PSObject.Properties.Name | Should -Not -Contain "original"
        }

        It "Should create parent directories if they do not exist" {
            # Arrange
            $nestedPath = Join-Path $script:TestTempDir "nested\dir\structure\test.json"
            $testData = @{ nested = $true }

            # Act
            $result = Write-JsonFile -Path $nestedPath -Data $testData

            # Assert
            $result | Should -Be $true
            Test-Path $nestedPath | Should -Be $true
        }

        It "Should handle null data by writing empty object" {
            # Arrange
            $testFile = Join-Path $script:TestTempDir "test-null-$(Get-Random).json"

            # Act
            $result = Write-JsonFile -Path $testFile -Data $null

            # Assert
            $result | Should -Be $true
            Test-Path $testFile | Should -Be $true
        }

        It "Should respect Depth parameter for nested objects" {
            # Arrange
            $testFile = Join-Path $script:TestTempDir "test-depth.json"
            $deepData = @{
                level1 = @{
                    level2 = @{
                        level3 = @{
                            level4 = @{
                                value = "deep"
                            }
                        }
                    }
                }
            }

            # Act
            $result = Write-JsonFile -Path $testFile -Data $deepData -Depth 10

            # Assert
            $result | Should -Be $true
            $content = Get-Content -Path $testFile -Raw | ConvertFrom-Json
            $content.level1.level2.level3.level4.value | Should -Be "deep"
        }
    }

    Context "ConvertTo-Hashtable" {

        It "Should convert PSCustomObject to hashtable" {
            # Arrange
            $json = '{"name": "test", "value": 123}' | ConvertFrom-Json

            # Act
            $result = ConvertTo-Hashtable -InputObject $json

            # Assert
            $result | Should -BeOfType [hashtable]
            $result.name | Should -Be "test"
            $result.value | Should -Be 123
        }

        It "Should convert nested PSObjects recursively" {
            # Arrange
            $json = '{"outer": {"inner": {"deep": "value"}}}' | ConvertFrom-Json

            # Act
            $result = ConvertTo-Hashtable -InputObject $json

            # Assert
            $result | Should -BeOfType [hashtable]
            $result.outer | Should -BeOfType [hashtable]
            $result.outer.inner | Should -BeOfType [hashtable]
            $result.outer.inner.deep | Should -Be "value"
        }

        It "Should handle arrays in JSON" {
            # Arrange
            $json = '{"items": [1, 2, 3], "objects": [{"a": 1}, {"b": 2}]}' | ConvertFrom-Json

            # Act
            $result = ConvertTo-Hashtable -InputObject $json

            # Assert
            $result.items | Should -HaveCount 3
            $result.items[0] | Should -Be 1
            $result.objects | Should -HaveCount 2
            $result.objects[0].a | Should -Be 1
        }

        It "Should return null for null input" {
            # Act
            $result = ConvertTo-Hashtable -InputObject $null

            # Assert
            $result | Should -BeNullOrEmpty
        }

        It "Should return primitives unchanged" {
            # Act & Assert
            ConvertTo-Hashtable -InputObject "string" | Should -Be "string"
            ConvertTo-Hashtable -InputObject 42 | Should -Be 42
            ConvertTo-Hashtable -InputObject $true | Should -Be $true
        }

        It "Should handle existing hashtables" {
            # Arrange
            $hashtable = @{ key = "value"; nested = @{ inner = "data" } }

            # Act
            $result = ConvertTo-Hashtable -InputObject $hashtable

            # Assert
            $result | Should -BeOfType [hashtable]
            $result.key | Should -Be "value"
            $result.nested.inner | Should -Be "data"
        }
    }
}

#endregion

#region AIUtil-Health Tests

Describe "AIUtil-Health.psm1" -Tag "Health", "Utils" {

    BeforeAll {
        # Clear cache before tests
        if (Get-Command Clear-HealthCache -ErrorAction SilentlyContinue) {
            Clear-HealthCache
        }
    }

    Context "Test-OllamaAvailable" {

        It "Should return a boolean Available property" {
            # Act
            $result = Test-OllamaAvailable -NoCache

            # Assert
            $result | Should -BeOfType [hashtable]
            $result.Available | Should -BeOfType [bool]
        }

        It "Should return expected structure with Port and ResponseTimeMs" {
            # Act
            $result = Test-OllamaAvailable -NoCache

            # Assert
            $result.Keys | Should -Contain "Available"
            $result.Keys | Should -Contain "Port"
            $result.Keys | Should -Contain "ResponseTimeMs"
            $result.Port | Should -BeOfType [int]
            $result.ResponseTimeMs | Should -BeGreaterOrEqual 0
        }

        It "Should use default port 11434" {
            # Act
            $result = Test-OllamaAvailable -NoCache

            # Assert
            $result.Port | Should -Be 11434
        }

        It "Should accept custom port parameter" {
            # Act
            $result = Test-OllamaAvailable -Port 12345 -NoCache -TimeoutMs 500

            # Assert
            $result.Port | Should -Be 12345
        }

        It "Should return Cached flag indicating cache status" {
            # Act - First call
            $result1 = Test-OllamaAvailable -NoCache
            # Second call - should be cached
            $result2 = Test-OllamaAvailable

            # Assert
            $result1.Cached | Should -Be $false
            $result2.Cached | Should -Be $true
        }

        It "Should bypass cache when NoCache is specified" {
            # Act
            $result = Test-OllamaAvailable -NoCache

            # Assert
            $result.Cached | Should -Be $false
        }
    }

    Context "Get-SystemMetrics" {

        It "Should return expected structure with CPU and Memory metrics" {
            # Act
            $result = Get-SystemMetrics -NoCache

            # Assert
            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain "CpuPercent"
            $result.Keys | Should -Contain "MemoryPercent"
            $result.Keys | Should -Contain "Recommendation"
            $result.Keys | Should -Contain "Timestamp"
        }

        It "Should return CpuPercent between 0 and 100" {
            # Act
            $result = Get-SystemMetrics -NoCache

            # Assert
            $result.CpuPercent | Should -BeGreaterOrEqual 0
            $result.CpuPercent | Should -BeLessOrEqual 100
        }

        It "Should return MemoryPercent between 0 and 100" {
            # Act
            $result = Get-SystemMetrics -NoCache

            # Assert
            $result.MemoryPercent | Should -BeGreaterOrEqual 0
            $result.MemoryPercent | Should -BeLessOrEqual 100
        }

        It "Should return valid Recommendation value" {
            # Act
            $result = Get-SystemMetrics -NoCache

            # Assert
            $result.Recommendation | Should -BeIn @("local", "hybrid", "cloud")
        }

        It "Should return MemoryAvailableGB and MemoryTotalGB" {
            # Act
            $result = Get-SystemMetrics -NoCache

            # Assert
            $result.MemoryAvailableGB | Should -BeGreaterThan 0
            $result.MemoryTotalGB | Should -BeGreaterThan 0
            $result.MemoryTotalGB | Should -BeGreaterOrEqual $result.MemoryAvailableGB
        }

        It "Should cache results" {
            # Act
            $result1 = Get-SystemMetrics -NoCache
            $result2 = Get-SystemMetrics

            # Assert
            $result1.Cached | Should -Be $false
            $result2.Cached | Should -Be $true
        }
    }

    Context "Test-ApiKeyPresent" {

        BeforeAll {
            # Store original env var if exists
            $script:OriginalAnthropicKey = $env:ANTHROPIC_API_KEY
            $script:OriginalTestKey = $env:TEST_API_KEY_FOR_PESTER
        }

        AfterAll {
            # Restore original env vars
            if ($script:OriginalAnthropicKey) {
                $env:ANTHROPIC_API_KEY = $script:OriginalAnthropicKey
            }
            if ($null -ne $script:OriginalTestKey) {
                $env:TEST_API_KEY_FOR_PESTER = $script:OriginalTestKey
            } else {
                Remove-Item Env:\TEST_API_KEY_FOR_PESTER -ErrorAction SilentlyContinue
            }
        }

        It "Should return Present=true when env var is set" {
            # Arrange
            $env:TEST_API_KEY_FOR_PESTER = "test-key-12345"

            # Act
            $result = Test-ApiKeyPresent -EnvVarName "TEST_API_KEY_FOR_PESTER"

            # Assert
            $result.Present | Should -Be $true
            $result.EnvVar | Should -Be "TEST_API_KEY_FOR_PESTER"
        }

        It "Should return Present=false when env var is not set" {
            # Arrange
            Remove-Item Env:\NONEXISTENT_KEY_PESTER_TEST -ErrorAction SilentlyContinue

            # Act
            $result = Test-ApiKeyPresent -EnvVarName "NONEXISTENT_KEY_PESTER_TEST"

            # Assert
            $result.Present | Should -Be $false
        }

        It "Should return correct EnvVar name for anthropic provider" {
            # Act
            $result = Test-ApiKeyPresent -Provider "anthropic"

            # Assert
            $result.EnvVar | Should -Be "ANTHROPIC_API_KEY"
            $result.Provider | Should -Be "anthropic"
        }

        It "Should return correct EnvVar name for openai provider" {
            # Act
            $result = Test-ApiKeyPresent -Provider "openai"

            # Assert
            $result.EnvVar | Should -Be "OPENAI_API_KEY"
            $result.Provider | Should -Be "openai"
        }

        It "Should mask key when MaskKey switch is used" {
            # Arrange
            $env:TEST_API_KEY_FOR_PESTER = "sk-test-1234567890abcdef"

            # Act
            $result = Test-ApiKeyPresent -EnvVarName "TEST_API_KEY_FOR_PESTER" -MaskKey

            # Assert
            $result.MaskedKey | Should -Not -BeNullOrEmpty
            $result.MaskedKey | Should -Match "^.{10}\.\.\.$"
            $result.MaskedKey | Should -Not -Contain "1234567890abcdef"
        }
    }
}

#endregion

#region AIUtil-Validation Tests

Describe "AIUtil-Validation.psm1" -Tag "Validation", "Utils" {

    Context "Get-PromptCategory" {

        It "Should return valid category string" {
            # Act
            $result = Get-PromptCategory -Prompt "Write a function"

            # Assert
            $result | Should -BeOfType [string]
            $result | Should -BeIn @("code", "analysis", "creative", "task", "question", "summary", "general")
        }

        It "Should detect 'code' category for code-related prompts" {
            # Test cases
            $codePrompts = @(
                "Write a Python function to sort a list"
                "Create a JavaScript class for user authentication"
                "Implement a binary search algorithm"
                "Generate code for API endpoint"
            )

            foreach ($prompt in $codePrompts) {
                $result = Get-PromptCategory -Prompt $prompt
                $result | Should -Be "code" -Because "Prompt: $prompt"
            }
        }

        It "Should detect 'analysis' category for analytical prompts" {
            # Test cases
            $analysisPrompts = @(
                "Compare REST and GraphQL APIs"
                "Analyze the performance of this algorithm"
                "Explain how async/await works"
            )

            foreach ($prompt in $analysisPrompts) {
                $result = Get-PromptCategory -Prompt $prompt
                $result | Should -Be "analysis" -Because "Prompt: $prompt"
            }
        }

        It "Should detect 'question' category for questions" {
            # Test cases
            $questionPrompts = @(
                "What is the capital of France?"
                "How does garbage collection work?"
                "Why is Python popular?"
            )

            foreach ($prompt in $questionPrompts) {
                $result = Get-PromptCategory -Prompt $prompt
                $result | Should -Be "question" -Because "Prompt: $prompt"
            }
        }

        It "Should return 'general' for empty or whitespace prompts" {
            Get-PromptCategory -Prompt "" | Should -Be "general"
            Get-PromptCategory -Prompt "   " | Should -Be "general"
        }

        It "Should accept pipeline input" {
            # Act
            $result = "Write a function" | Get-PromptCategory

            # Assert
            $result | Should -Be "code"
        }
    }

    Context "Get-PromptClarity" {

        It "Should return integer between 0 and 100" {
            # Act
            $result = Get-PromptClarity -Prompt "Write a Python function that sorts integers"

            # Assert
            $result | Should -BeOfType [int]
            $result | Should -BeGreaterOrEqual 0
            $result | Should -BeLessOrEqual 100
        }

        It "Should return 0 for empty prompt" {
            # Act
            $result = Get-PromptClarity -Prompt ""

            # Assert
            $result | Should -Be 0
        }

        It "Should return lower score for vague prompts" {
            # Act
            $vagueResult = Get-PromptClarity -Prompt "do something with the stuff"
            $clearResult = Get-PromptClarity -Prompt "Write a Python function that sorts a list of integers in ascending order"

            # Assert
            $vagueResult | Should -BeLessThan $clearResult
        }

        It "Should return higher score for specific prompts" {
            # Test cases with increasing specificity
            $vague = Get-PromptClarity -Prompt "help"
            $medium = Get-PromptClarity -Prompt "help with code"
            $specific = Get-PromptClarity -Prompt "Write a Python function called 'sort_list' that takes a list of integers and returns them sorted"

            # Assert
            $vague | Should -BeLessThan $medium
            $medium | Should -BeLessThan $specific
        }

        It "Should return detailed breakdown when Detailed switch is used" {
            # Act
            $result = Get-PromptClarity -Prompt "Write code" -Detailed

            # Assert
            $result | Should -BeOfType [PSCustomObject]
            $result.Score | Should -BeOfType [int]
            $result.Issues | Should -BeOfType [array]
            $result.Suggestions | Should -BeOfType [array]
            $result.Breakdown | Should -Not -BeNullOrEmpty
        }

        It "Should accept pipeline input" {
            # Act
            $result = "Test prompt" | Get-PromptClarity

            # Assert
            $result | Should -BeOfType [int]
        }
    }

    Context "Get-CodeLanguage" {

        It "Should detect PowerShell code" {
            $psCode = @'
function Get-Something {
    param([string]$Name)
    Write-Host "Hello $Name"
    $result = Get-Process | Where-Object { $_.Name -eq $Name }
    return $result
}
'@
            # Act
            $result = Get-CodeLanguage -Code $psCode

            # Assert
            $result | Should -Be "powershell"
        }

        It "Should detect Python code" {
            $pyCode = @'
def hello_world():
    print("Hello, World!")

class MyClass:
    def __init__(self, name):
        self.name = name

if __name__ == "__main__":
    hello_world()
'@
            # Act
            $result = Get-CodeLanguage -Code $pyCode

            # Assert
            $result | Should -Be "python"
        }

        It "Should detect JavaScript code" {
            $jsCode = @'
function greet(name) {
    console.log(`Hello, ${name}!`);
}

const fetchData = async () => {
    const response = await fetch('/api/data');
    return response.json();
};

module.exports = { greet, fetchData };
'@
            # Act
            $result = Get-CodeLanguage -Code $jsCode

            # Assert
            $result | Should -Be "javascript"
        }

        It "Should detect TypeScript code" {
            $tsCode = @'
interface User {
    name: string;
    age: number;
}

function greet(user: User): void {
    console.log(`Hello, ${user.name}`);
}

export type UserRole = 'admin' | 'user';
'@
            # Act
            $result = Get-CodeLanguage -Code $tsCode

            # Assert
            $result | Should -Be "typescript"
        }

        It "Should detect SQL code" {
            $sqlCode = @'
SELECT u.name, u.email, COUNT(o.id) as order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.active = 1
GROUP BY u.id
ORDER BY order_count DESC;
'@
            # Act
            $result = Get-CodeLanguage -Code $sqlCode

            # Assert
            $result | Should -Be "sql"
        }

        It "Should detect Rust code" {
            $rustCode = @'
fn main() {
    let mut numbers = vec![1, 2, 3, 4, 5];
    numbers.push(6);

    for n in &numbers {
        println!("{}", n);
    }
}

struct Point {
    x: f64,
    y: f64,
}

impl Point {
    fn new(x: f64, y: f64) -> Self {
        Point { x, y }
    }
}
'@
            # Act
            $result = Get-CodeLanguage -Code $rustCode

            # Assert
            $result | Should -Be "rust"
        }

        It "Should detect Go code" {
            $goCode = @'
package main

import "fmt"

func main() {
    message := "Hello, Go!"
    fmt.Println(message)
}

type Person struct {
    Name string
    Age  int
}

func (p *Person) Greet() {
    fmt.Printf("Hello, I'm %s\n", p.Name)
}
'@
            # Act
            $result = Get-CodeLanguage -Code $goCode

            # Assert
            $result | Should -Be "go"
        }

        It "Should return 'text' for empty or non-code content" {
            Get-CodeLanguage -Code "" | Should -Be "text"
            Get-CodeLanguage -Code "Hello, this is just plain text." | Should -Be "text"
        }

        It "Should return detailed breakdown when Detailed switch is used" {
            # Act
            $result = Get-CodeLanguage -Code "def hello(): pass" -Detailed

            # Assert
            $result | Should -BeOfType [PSCustomObject]
            $result.Language | Should -Be "python"
            $result.Confidence | Should -BeOfType [int]
            $result.Scores | Should -Not -BeNullOrEmpty
        }

        It "Should accept pipeline input" {
            # Act
            $result = "console.log('test');" | Get-CodeLanguage

            # Assert
            $result | Should -Be "javascript"
        }
    }

    Context "Test-PromptValid" {

        It "Should return true for valid prompts" {
            # Act
            $result = Test-PromptValid -Prompt "This is a valid prompt"

            # Assert
            $result | Should -Be $true
        }

        It "Should return false for null prompt" {
            # Act
            $result = Test-PromptValid -Prompt $null

            # Assert
            $result | Should -Be $false
        }

        It "Should return false for empty prompt" {
            # Act
            $result = Test-PromptValid -Prompt ""

            # Assert
            $result | Should -Be $false
        }

        It "Should return false for whitespace-only prompt" {
            # Act
            $result = Test-PromptValid -Prompt "   "

            # Assert
            $result | Should -Be $false
        }

        It "Should return false for prompt shorter than MinLength" {
            # Act
            $result = Test-PromptValid -Prompt "ab" -MinLength 5

            # Assert
            $result | Should -Be $false
        }

        It "Should return detailed validation info when Detailed switch is used" {
            # Act
            $result = Test-PromptValid -Prompt "" -Detailed

            # Assert
            $result | Should -BeOfType [PSCustomObject]
            $result.IsValid | Should -Be $false
            $result.Reason | Should -Not -BeNullOrEmpty
        }
    }
}

#endregion
