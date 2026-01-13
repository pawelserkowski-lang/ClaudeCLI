#Requires -Version 5.1
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester 5.x tests for AI Handler core modules.

.DESCRIPTION
    Unit tests for:
    - AIConfig.psm1: Configuration management
    - AIState.psm1: State management
    - AIConstants.psm1: Constants and thresholds

.NOTES
    Run with: Invoke-Pester -Path .\Core.Tests.ps1 -Output Detailed
#>

BeforeAll {
    # Define module paths
    $script:CorePath = Split-Path $PSScriptRoot -Parent | Join-Path -ChildPath 'core'
    $script:UtilsPath = Split-Path $PSScriptRoot -Parent | Join-Path -ChildPath 'utils'

    # Import JSON utilities first (dependency for other modules)
    $jsonUtilPath = Join-Path $script:CorePath 'AIUtil-JsonIO.psm1'
    if (Test-Path $jsonUtilPath) {
        Import-Module $jsonUtilPath -Force -ErrorAction SilentlyContinue
    }

    # Alternative location for JSON utilities
    $jsonUtilAlt = Join-Path $script:UtilsPath 'AIUtil-JsonIO.psm1'
    if (Test-Path $jsonUtilAlt) {
        Import-Module $jsonUtilAlt -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# AIConfig.psm1 Tests
# ============================================================================

Describe 'AIConfig Module' -Tag 'Config' {

    BeforeAll {
        $configModulePath = Join-Path $script:CorePath 'AIConfig.psm1'

        # Skip module import if file doesn't exist
        if (-not (Test-Path $configModulePath)) {
            throw "AIConfig.psm1 not found at: $configModulePath"
        }

        Import-Module $configModulePath -Force
    }

    Context 'Get-AIConfig' {

        It 'Should return a hashtable' {
            $config = Get-AIConfig
            $config | Should -BeOfType [hashtable]
        }

        It 'Should contain providers key' {
            $config = Get-AIConfig
            $config.ContainsKey('providers') | Should -BeTrue
        }

        It 'Should contain settings key' {
            $config = Get-AIConfig
            $config.ContainsKey('settings') | Should -BeTrue
        }

        It 'Should contain fallbackChain key' {
            $config = Get-AIConfig
            $config.ContainsKey('fallbackChain') | Should -BeTrue
        }

        It 'Should contain providerFallbackOrder key' {
            $config = Get-AIConfig
            $config.ContainsKey('providerFallbackOrder') | Should -BeTrue
        }
    }

    Context 'Get-DefaultConfig' {

        It 'Should return a hashtable' {
            $defaults = Get-DefaultConfig
            $defaults | Should -BeOfType [hashtable]
        }

        It 'Should have providers key' {
            $defaults = Get-DefaultConfig
            $defaults.ContainsKey('providers') | Should -BeTrue
        }

        It 'Should have fallbackChain key' {
            $defaults = Get-DefaultConfig
            $defaults.ContainsKey('fallbackChain') | Should -BeTrue
        }

        It 'Should have providerFallbackOrder key' {
            $defaults = Get-DefaultConfig
            $defaults.ContainsKey('providerFallbackOrder') | Should -BeTrue
        }

        It 'Should have settings key' {
            $defaults = Get-DefaultConfig
            $defaults.ContainsKey('settings') | Should -BeTrue
        }

        It 'Should have anthropic provider defined' {
            $defaults = Get-DefaultConfig
            $defaults.providers.ContainsKey('anthropic') | Should -BeTrue
        }

        It 'Should have openai provider defined' {
            $defaults = Get-DefaultConfig
            $defaults.providers.ContainsKey('openai') | Should -BeTrue
        }

        It 'Should have ollama provider defined' {
            $defaults = Get-DefaultConfig
            $defaults.providers.ContainsKey('ollama') | Should -BeTrue
        }

        It 'Should have maxRetries in settings' {
            $defaults = Get-DefaultConfig
            $defaults.settings.ContainsKey('maxRetries') | Should -BeTrue
        }

        It 'Should have rateLimitThreshold in settings' {
            $defaults = Get-DefaultConfig
            $defaults.settings.ContainsKey('rateLimitThreshold') | Should -BeTrue
        }

        It 'Should have autoFallback in settings' {
            $defaults = Get-DefaultConfig
            $defaults.settings.ContainsKey('autoFallback') | Should -BeTrue
        }
    }

    Context 'Merge-Config' {

        It 'Should merge user config with defaults' {
            $defaults = @{
                key1 = 'default1'
                key2 = 'default2'
                nested = @{
                    a = 1
                    b = 2
                }
            }
            $userConfig = @{
                key1 = 'user1'
                nested = @{
                    a = 10
                }
            }

            $merged = Merge-Config -UserConfig $userConfig -DefaultConfig $defaults

            $merged.key1 | Should -Be 'user1'
            $merged.key2 | Should -Be 'default2'
        }

        It 'Should preserve user values over defaults' {
            $defaults = @{ setting = 'default' }
            $userConfig = @{ setting = 'custom' }

            $merged = Merge-Config -UserConfig $userConfig -DefaultConfig $defaults

            $merged.setting | Should -Be 'custom'
        }

        It 'Should fill missing keys from defaults' {
            $defaults = @{
                key1 = 'value1'
                key2 = 'value2'
            }
            $userConfig = @{
                key1 = 'customValue'
            }

            $merged = Merge-Config -UserConfig $userConfig -DefaultConfig $defaults

            $merged.key1 | Should -Be 'customValue'
            $merged.key2 | Should -Be 'value2'
        }

        It 'Should merge nested hashtables recursively' {
            $defaults = @{
                outer = @{
                    inner1 = 'default1'
                    inner2 = 'default2'
                }
            }
            $userConfig = @{
                outer = @{
                    inner1 = 'custom1'
                }
            }

            $merged = Merge-Config -UserConfig $userConfig -DefaultConfig $defaults

            $merged.outer.inner1 | Should -Be 'custom1'
            $merged.outer.inner2 | Should -Be 'default2'
        }

        It 'Should preserve custom user keys not in defaults' {
            $defaults = @{ standard = 'value' }
            $userConfig = @{
                standard = 'value'
                custom = 'myCustomValue'
            }

            $merged = Merge-Config -UserConfig $userConfig -DefaultConfig $defaults

            $merged.custom | Should -Be 'myCustomValue'
        }
    }

    Context 'Test-ConfigValid' {

        It 'Should return true for valid config' {
            $validConfig = @{
                providers = @{
                    anthropic = @{
                        name = 'Anthropic'
                        baseUrl = 'https://api.anthropic.com/v1'
                        enabled = $true
                        models = @{}
                    }
                }
                fallbackChain = @{
                    anthropic = @('model1')
                }
                providerFallbackOrder = @('anthropic')
                settings = @{
                    maxRetries = 3
                    rateLimitThreshold = 0.85
                    autoFallback = $true
                }
            }

            Test-ConfigValid -Config $validConfig | Should -BeTrue
        }

        It 'Should return false when providers key is missing' {
            $invalidConfig = @{
                fallbackChain = @{}
                providerFallbackOrder = @()
                settings = @{
                    maxRetries = 3
                    rateLimitThreshold = 0.85
                    autoFallback = $true
                }
            }

            Test-ConfigValid -Config $invalidConfig | Should -BeFalse
        }

        It 'Should return false when settings key is missing' {
            $invalidConfig = @{
                providers = @{}
                fallbackChain = @{}
                providerFallbackOrder = @()
            }

            Test-ConfigValid -Config $invalidConfig | Should -BeFalse
        }

        It 'Should return false when fallbackChain key is missing' {
            $invalidConfig = @{
                providers = @{}
                providerFallbackOrder = @()
                settings = @{
                    maxRetries = 3
                    rateLimitThreshold = 0.85
                    autoFallback = $true
                }
            }

            Test-ConfigValid -Config $invalidConfig | Should -BeFalse
        }

        It 'Should return false when providerFallbackOrder key is missing' {
            $invalidConfig = @{
                providers = @{}
                fallbackChain = @{}
                settings = @{
                    maxRetries = 3
                    rateLimitThreshold = 0.85
                    autoFallback = $true
                }
            }

            Test-ConfigValid -Config $invalidConfig | Should -BeFalse
        }

        It 'Should validate provider structure has required keys' {
            $invalidConfig = @{
                providers = @{
                    test = @{
                        # Missing required keys: name, baseUrl, enabled, models
                    }
                }
                fallbackChain = @{}
                providerFallbackOrder = @()
                settings = @{
                    maxRetries = 3
                    rateLimitThreshold = 0.85
                    autoFallback = $true
                }
            }

            Test-ConfigValid -Config $invalidConfig | Should -BeFalse
        }

        It 'Should validate settings has required keys' {
            $invalidConfig = @{
                providers = @{}
                fallbackChain = @{}
                providerFallbackOrder = @()
                settings = @{
                    # Missing: maxRetries, rateLimitThreshold, autoFallback
                }
            }

            Test-ConfigValid -Config $invalidConfig | Should -BeFalse
        }
    }
}

# ============================================================================
# AIState.psm1 Tests
# ============================================================================

Describe 'AIState Module' -Tag 'State' {

    BeforeAll {
        $stateModulePath = Join-Path $script:CorePath 'AIState.psm1'

        if (-not (Test-Path $stateModulePath)) {
            throw "AIState.psm1 not found at: $stateModulePath"
        }

        Import-Module $stateModulePath -Force
    }

    Context 'Get-AIState' {

        It 'Should return a hashtable' {
            $state = Get-AIState
            $state | Should -BeOfType [hashtable]
        }

        It 'Should have currentProvider property' {
            $state = Get-AIState
            $state.ContainsKey('currentProvider') | Should -BeTrue
        }

        It 'Should have currentModel property' {
            $state = Get-AIState
            $state.ContainsKey('currentModel') | Should -BeTrue
        }

        It 'Should have usage property' {
            $state = Get-AIState
            $state.ContainsKey('usage') | Should -BeTrue
        }

        It 'Should have errors property' {
            $state = Get-AIState
            $state.ContainsKey('errors') | Should -BeTrue
        }
    }

    Context 'Initialize-AIState' {

        It 'Should return a hashtable' {
            # Use a mock config getter to avoid dependency on config file
            $mockConfig = {
                @{
                    providers = @{
                        testProvider = @{
                            name = 'Test'
                            enabled = $true
                            models = @{
                                'testModel' = @{
                                    tier = 'lite'
                                }
                            }
                        }
                    }
                    settings = @{
                        modelDiscovery = @{
                            enabled = $false
                        }
                    }
                }
            }

            $state = Initialize-AIState -ConfigGetter $mockConfig
            $state | Should -BeOfType [hashtable]
        }

        It 'Should create usage tracking hashtable' {
            $mockConfig = {
                @{
                    providers = @{
                        testProvider = @{
                            name = 'Test'
                            enabled = $true
                            models = @{
                                'testModel' = @{
                                    tier = 'lite'
                                }
                            }
                        }
                    }
                    settings = @{
                        modelDiscovery = @{
                            enabled = $false
                        }
                    }
                }
            }

            $state = Initialize-AIState -ConfigGetter $mockConfig
            $state.usage | Should -BeOfType [hashtable]
        }

        It 'Should initialize usage for configured providers' {
            $mockConfig = {
                @{
                    providers = @{
                        myProvider = @{
                            name = 'My Provider'
                            enabled = $true
                            models = @{
                                'model1' = @{ tier = 'lite' }
                            }
                        }
                    }
                    settings = @{
                        modelDiscovery = @{
                            enabled = $false
                        }
                    }
                }
            }

            $state = Initialize-AIState -ConfigGetter $mockConfig
            $state.usage.ContainsKey('myProvider') | Should -BeTrue
        }

        It 'Should initialize usage tracking counters for models' {
            $mockConfig = {
                @{
                    providers = @{
                        testProv = @{
                            name = 'Test'
                            enabled = $true
                            models = @{
                                'model-x' = @{ tier = 'standard' }
                            }
                        }
                    }
                    settings = @{
                        modelDiscovery = @{
                            enabled = $false
                        }
                    }
                }
            }

            $state = Initialize-AIState -ConfigGetter $mockConfig
            $state.usage['testProv']['model-x'] | Should -Not -BeNullOrEmpty
            $state.usage['testProv']['model-x'].ContainsKey('totalTokens') | Should -BeTrue
            $state.usage['testProv']['model-x'].ContainsKey('totalRequests') | Should -BeTrue
        }
    }

    Context 'Update-AIState' {

        It 'Should update currentProvider property' {
            $state = Update-AIState -Property 'currentProvider' -Value 'openai'
            $state.currentProvider | Should -Be 'openai'
        }

        It 'Should update currentModel property' {
            $state = Update-AIState -Property 'currentModel' -Value 'gpt-4o'
            $state.currentModel | Should -Be 'gpt-4o'
        }

        It 'Should update usage data for provider/model' {
            $usageData = @{
                totalTokens = 5000
                totalRequests = 25
            }

            $state = Update-AIState -Provider 'testProvider' -Model 'testModel' -UsageData $usageData

            $state.usage['testProvider']['testModel'].totalTokens | Should -Be 5000
            $state.usage['testProvider']['testModel'].totalRequests | Should -Be 25
        }

        It 'Should create nested structure if provider does not exist' {
            $usageData = @{
                totalCost = 1.50
            }

            $state = Update-AIState -Provider 'newProvider' -Model 'newModel' -UsageData $usageData

            $state.usage.ContainsKey('newProvider') | Should -BeTrue
            $state.usage['newProvider'].ContainsKey('newModel') | Should -BeTrue
        }

        It 'Should return updated state hashtable' {
            $state = Update-AIState -Property 'currentProvider' -Value 'anthropic'
            $state | Should -BeOfType [hashtable]
        }
    }
}

# ============================================================================
# AIConstants.psm1 Tests
# ============================================================================

Describe 'AIConstants Module' -Tag 'Constants' {

    BeforeAll {
        $constantsModulePath = Join-Path $script:CorePath 'AIConstants.psm1'

        if (-not (Test-Path $constantsModulePath)) {
            throw "AIConstants.psm1 not found at: $constantsModulePath"
        }

        Import-Module $constantsModulePath -Force
    }

    Context 'Exported Variables Exist' {

        It 'Should export Paths variable' {
            $Paths | Should -Not -BeNullOrEmpty
        }

        It 'Should export Thresholds variable' {
            $Thresholds | Should -Not -BeNullOrEmpty
        }

        It 'Should export ProviderPriority variable' {
            $ProviderPriority | Should -Not -BeNullOrEmpty
        }

        It 'Should export TierScores variable' {
            $TierScores | Should -Not -BeNullOrEmpty
        }

        It 'Should export TaskTierMap variable' {
            $TaskTierMap | Should -Not -BeNullOrEmpty
        }

        It 'Should export ModelCapabilities variable' {
            $ModelCapabilities | Should -Not -BeNullOrEmpty
        }

        It 'Should export ErrorCodes variable' {
            $ErrorCodes | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Thresholds Structure' {

        It 'Should have RateLimitWarning key' {
            $Thresholds.ContainsKey('RateLimitWarning') | Should -BeTrue
        }

        It 'Should have RateLimitCritical key' {
            $Thresholds.ContainsKey('RateLimitCritical') | Should -BeTrue
        }

        It 'Should have MaxRetries key' {
            $Thresholds.ContainsKey('MaxRetries') | Should -BeTrue
        }

        It 'Should have RetryDelayMs key' {
            $Thresholds.ContainsKey('RetryDelayMs') | Should -BeTrue
        }

        It 'Should have TimeoutMs key' {
            $Thresholds.ContainsKey('TimeoutMs') | Should -BeTrue
        }

        It 'Should have MaxConcurrent key' {
            $Thresholds.ContainsKey('MaxConcurrent') | Should -BeTrue
        }

        It 'Should have CpuLocalThreshold key' {
            $Thresholds.ContainsKey('CpuLocalThreshold') | Should -BeTrue
        }

        It 'Should have CpuHybridThreshold key' {
            $Thresholds.ContainsKey('CpuHybridThreshold') | Should -BeTrue
        }

        It 'RateLimitWarning should be numeric between 0 and 1' {
            $Thresholds.RateLimitWarning | Should -BeGreaterThan 0
            $Thresholds.RateLimitWarning | Should -BeLessThan 1
        }

        It 'RateLimitCritical should be greater than RateLimitWarning' {
            $Thresholds.RateLimitCritical | Should -BeGreaterThan $Thresholds.RateLimitWarning
        }

        It 'MaxRetries should be positive integer' {
            $Thresholds.MaxRetries | Should -BeGreaterThan 0
        }
    }

    Context 'ProviderPriority Structure' {

        It 'Should be an array' {
            $ProviderPriority | Should -BeOfType [array]
        }

        It 'Should contain anthropic provider' {
            $ProviderPriority | Should -Contain 'anthropic'
        }

        It 'Should contain openai provider' {
            $ProviderPriority | Should -Contain 'openai'
        }

        It 'Should contain ollama provider' {
            $ProviderPriority | Should -Contain 'ollama'
        }

        It 'Should have anthropic as first priority' {
            $ProviderPriority[0] | Should -Be 'anthropic'
        }

        It 'Should have ollama as last priority (local fallback)' {
            $ProviderPriority[-1] | Should -Be 'ollama'
        }

        It 'Should have at least 3 providers' {
            $ProviderPriority.Count | Should -BeGreaterOrEqual 3
        }
    }

    Context 'TierScores Structure' {

        It 'Should be a hashtable' {
            $TierScores | Should -BeOfType [hashtable]
        }

        It 'Should have pro tier' {
            $TierScores.ContainsKey('pro') | Should -BeTrue
        }

        It 'Should have standard tier' {
            $TierScores.ContainsKey('standard') | Should -BeTrue
        }

        It 'Should have lite tier' {
            $TierScores.ContainsKey('lite') | Should -BeTrue
        }

        It 'Pro tier should have highest score' {
            $TierScores.pro | Should -BeGreaterThan $TierScores.standard
            $TierScores.pro | Should -BeGreaterThan $TierScores.lite
        }

        It 'Standard tier should be between pro and lite' {
            $TierScores.standard | Should -BeLessThan $TierScores.pro
            $TierScores.standard | Should -BeGreaterThan $TierScores.lite
        }
    }

    Context 'TaskTierMap Structure' {

        It 'Should be a hashtable' {
            $TaskTierMap | Should -BeOfType [hashtable]
        }

        It 'Should have code task mapping' {
            $TaskTierMap.ContainsKey('code') | Should -BeTrue
        }

        It 'Should have simple task mapping' {
            $TaskTierMap.ContainsKey('simple') | Should -BeTrue
        }

        It 'Should have analysis task mapping' {
            $TaskTierMap.ContainsKey('analysis') | Should -BeTrue
        }

        It 'Should have general task mapping' {
            $TaskTierMap.ContainsKey('general') | Should -BeTrue
        }

        It 'Complex tasks should map to pro tier' {
            $TaskTierMap.complex | Should -Be 'pro'
        }

        It 'Simple tasks should map to lite tier' {
            $TaskTierMap.simple | Should -Be 'lite'
        }
    }

    Context 'Paths Structure' {

        It 'Should be a hashtable' {
            $Paths | Should -BeOfType [hashtable]
        }

        It 'Should have Config path' {
            $Paths.ContainsKey('Config') | Should -BeTrue
        }

        It 'Should have State path' {
            $Paths.ContainsKey('State') | Should -BeTrue
        }

        It 'Should have Cache path' {
            $Paths.ContainsKey('Cache') | Should -BeTrue
        }

        It 'Should have Modules path' {
            $Paths.ContainsKey('Modules') | Should -BeTrue
        }

        It 'Config path should end with .json' {
            $Paths.Config | Should -Match '\.json$'
        }

        It 'State path should end with .json' {
            $Paths.State | Should -Match '\.json$'
        }
    }

    Context 'ErrorCodes Structure' {

        It 'Should be a hashtable' {
            $ErrorCodes | Should -BeOfType [hashtable]
        }

        It 'Should have RateLimitExceeded code' {
            $ErrorCodes.ContainsKey('RateLimitExceeded') | Should -BeTrue
        }

        It 'Should have AuthenticationFailed code' {
            $ErrorCodes.ContainsKey('AuthenticationFailed') | Should -BeTrue
        }

        It 'Should have Timeout code' {
            $ErrorCodes.ContainsKey('Timeout') | Should -BeTrue
        }

        It 'Should have ProviderUnavailable code' {
            $ErrorCodes.ContainsKey('ProviderUnavailable') | Should -BeTrue
        }
    }

    Context 'ModelCapabilities Structure' {

        It 'Should be a hashtable' {
            $ModelCapabilities | Should -BeOfType [hashtable]
        }

        It 'Should have VisionModels array' {
            $ModelCapabilities.ContainsKey('VisionModels') | Should -BeTrue
            $ModelCapabilities.VisionModels | Should -BeOfType [array]
        }

        It 'Should have CodeModels array' {
            $ModelCapabilities.ContainsKey('CodeModels') | Should -BeTrue
            $ModelCapabilities.CodeModels | Should -BeOfType [array]
        }

        It 'Should have LongContextModels array' {
            $ModelCapabilities.ContainsKey('LongContextModels') | Should -BeTrue
            $ModelCapabilities.LongContextModels | Should -BeOfType [array]
        }

        It 'VisionModels should include Claude models' {
            $ModelCapabilities.VisionModels | Should -Contain 'claude-opus-4-5-20251101'
        }

        It 'CodeModels should include qwen2.5-coder' {
            ($ModelCapabilities.CodeModels -like 'qwen2.5-coder*').Count | Should -BeGreaterThan 0
        }
    }
}
