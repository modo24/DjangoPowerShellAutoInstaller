param($name, $username)
$CurrentPath = Get-Location
$NewFolder = "$CurrentPath\$name" 
$ForbiddenNames = 'asgiref', 'Django', 'sqlparse', 'tzdata2'

if (-not(Get-Command 'python' -errorAction SilentlyContinue)) {
    Write-Host "You must install Python first. You can download the latest stable Python version from https://www.python.org/downloads/" -ForegroundColor "Red";
    break   

} elseif ($name.length -eq 0) {
    Write-Host "Error! Missing Required Command Line Arguments: django [-name] 'your_project_name' [-username] 'your_username'" -ForegroundColor "Red";
    break
    

} elseif  ($name -match '[^A-Za-z0-9_]') {
    Write-Host "CommandError: '$name' is not a valid project name. Please make sure the name is a valid identifier." -ForegroundColor "Red";    
    break

} elseif (Test-Path -Path $NewFolder) {
    Write-Host "You cannot create a project named '$name', it already exists a folder with this name in current path. Please try another name." -ForegroundColor "Red";
    break

} elseif ($name.length -gt 30) {
    Write-Host "Error: The name ""$name"" is greater than 30 characters. Please try another name." -ForegroundColor "Red";
    break  

} else {

    Write-Output "import $name" | python >$null 2>&1 

    if (($LASTEXITCODE -eq 0) -or ($ForbiddenNames.ToLower().contains($name.ToLower()))) {
        Write-Host "CommandError: '$name' conflicts with the name of an existing Python module and cannot be used as a project name. Please try another name." -ForegroundColor "Red"; 
        break
    }

    function Write-ProgressHelper {
        param (
            [int]$StepNumber,
            [string]$Message            
        )

        Write-Progress -Activity 'Creating the Django Project...' -Status $Message -PercentComplete (($StepNumber / $steps) * 100)
    }
    
    $script:steps = ([System.Management.Automation.PsParser]::Tokenize((Get-Content "$PSScriptRoot\$($MyInvocation.MyCommand.Name)"), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Write-ProgressHelper' }).Count
    $stepCounter = 1
    
    Clear-Host

    Write-Host "Starting creating the Django project '$name' in $CurrentPath\$name`n"  
    
    Write-Host "Enter superuser credentials:"
    if ($null -eq $username) {
        Do {
            $username = Read-Host -Prompt "Username"                            
        } Until ($username)       
    }      
    
    Do {
        $read_password = Read-Host -Prompt "Password" -AsSecureString        
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($read_password)
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    } Until ($read_password) 
    
    New-Item $name -itemtype directory >$null 2>&1
    Set-Location $name       
    Clear-Host

    Write-Host "Starting creating the Django project '$name' in $CurrentPath\$name`n"

    if (-not(Get-Command 'pip' -errorAction SilentlyContinue)) {
        Write-ProgressHelper -Message 'Installing PIP package...' -StepNumber ($stepCounter++)
        Invoke-WebRequest https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python get-pip.py >$null 2>&1         
        Remove-Item get-pip.py        
        python.exe -m pip install --upgrade pip --quiet                              
    } 
    
    if (-not(Get-Command 'virtualenv' -errorAction SilentlyContinue)) {
        Write-ProgressHelper -Message 'Installing Virtualenv package...' -StepNumber ($stepCounter++)
        pip install virtualenv --quiet
    }       
        
    Write-ProgressHelper -Message 'Creating a Python Virtual Environment...' -StepNumber ($stepCounter++)
    
    virtualenv . --python=python3 --quiet
    .\Scripts\activate                
  
    Write-ProgressHelper -Message 'Updating Virtual Environment Python packages...' -StepNumber ($stepCounter++)
                        
    python -m pip install --upgrade pip --quiet    
        
    if (-not(Test-Path -Path 'requirements.txt' -PathType Leaf)) {
        try {                        
            Write-ProgressHelper -Message 'Installing Python Django packages...' -StepNumber ($stepCounter++)
            pip install django --quiet
            pip freeze > requirements.txt
        }
        catch {
            throw $_.Exception.Message
        }
    }

    else {
        Write-ProgressHelper -Message 'Installing Python Django packages from requirements.txt...' -StepNumber ($stepCounter++)             
        pip install -r .\requirements.txt --quiet
    }        
    
    Write-ProgressHelper -Message "Initializing the Django Project..." -StepNumber ($stepCounter++)        
    django-admin startproject $name .
    
    if ($LASTEXITCODE -eq 1) {        
        Write-Host "CommandError: '$name' conflicts with the name of an existing Python module installed in the new Virtual Environment and cannot be used as a project name. Please try another name." -ForegroundColor "Red";
        deactivate
        Set-Location ..        
        Remove-Item $name -Force         
        break          

    } else {            
        Write-ProgressHelper -Message 'Running initial Django migrations...' -StepNumber ($stepCounter++)            
        python manage.py migrate >$null 2>&1            
        
        Write-ProgressHelper -Message 'Creating the Django Project Superuser...' -StepNumber ($stepCounter++)        
        
        Write-Output "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('$username', '$email', '$password')" | python manage.py shell >$null 2>&1            
        
                           
    }    
    Write-ProgressHelper -Message "Done!" -StepNumber (10)
    Start-Sleep -Seconds 1

    Clear-Host 
    Write-Host "The Django project '$name' was successfully created!"
    
    $run = Read-Host -Prompt "Do you want to run now the server? [Y/N]"
    if (($run -eq 'Y') -or ($run -eq 'y')) {
        Clear-Host
        Start-Process http://127.0.0.1:8000/admin/
        python manage.py runserver

    }else {
        Write-Host "The Django project '$name' was successfully created! To run Django server use: python manage.py runserver 0.0.0.0:80"
        Write-Host "You you want access the Django Admin Panel you must use you credentials on http://localhost/admin/"
        Set-Location ..
        break
    } 
}
