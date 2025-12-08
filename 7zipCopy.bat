@echo off
setlocal enabledelayedexpansion

REM Check if the correct number of arguments is provided
if "%~1"=="" (
    echo Usage: 7zipCopy.bat input_file.txt temp_folder target
    echo 1. 7-Zip will pack files listed in 'input_file.txt' to 'temp_folder'.
    echo 2. TeraCopy will copy 'temp_folder' to 'target'.
    exit /b 1
)

REM Set variables
set input_file=%~1
set outputDir=%~2
set target_path=%~3
set output_file=output_paths.txt
set zip_prefix=archive

REM Check if the input file exists
if not exist "%input_file%" (
    echo Input file not found: %input_file%
    exit /b 1
)

REM Check if the temp folder exists
if not exist "%outputDir%" (
    echo Temp folder not found: %outputDir%
    exit /b 1
)

REM Ask user whether to clear the temp folder
echo Temp folder: %outputDir%
set /p clear_temp=Delete all files in this folder (Y/N)? 

if /i "!clear_temp!"=="Y" (
    echo Clearing temp folder...
    del /q "%outputDir%\*"
    if %errorlevel% neq 0 (
        echo Failed to clear the folder.
        exit /b 1
    )
    echo Temp folder cleared.
) else (
    echo Temp folder not cleared.
)

REM Initialize the zip file name
set zipFileName=%outputDir%\%zip_prefix%.zip

REM Store files with no compression (-mx0) in 10 GB volumes (-v10g)
"C:\Program Files\7-Zip\7z.exe" a -tzip -mx0 -v10g "%zipFileName%" "@%input_file%" -bb

if errorlevel 1 (
    echo Compression failed.
    pause
    exit /b 1
)

"C:\Program Files\TeraCopy\TeraCopy.exe" copy "%outputDir%" "%target_path%"
