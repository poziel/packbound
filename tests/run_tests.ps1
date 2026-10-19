param(
 [ValidateSet('smoke','systems','scenes','integration','render','all')][string]$Suite='smoke',
 [string]$Test='*', [switch]$Render, [switch]$List, [string]$Godot, [string]$RunId, [int]$Seed=1729
)
$runnerArgs=@('-B',(Join-Path $PSScriptRoot 'runner/run_tests.py'),'--suite',$Suite,'--test',$Test,'--seed',"$Seed")
if($Render){$runnerArgs+='--render'}
if($List){$runnerArgs+='--list'}
if($Godot){$runnerArgs+=@('--godot',$Godot)}
if($RunId){$runnerArgs+=@('--run-id',$RunId)}
& python @runnerArgs
exit $LASTEXITCODE
