Param($k2Host, $k2WorkflowPort, [int]$SecondsToWaitForResponse, [bool]$ConsoleMode=$false)



Restart-K2ServerAndWait -Prompt $false -ConsoleMode $true

read-host 'Stop';