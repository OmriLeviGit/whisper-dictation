#Requires AutoHotkey v2.0
#SingleInstance Force

; ==================== CONFIGURATION ====================
; Python command - using uv to access installed dependencies
global PYTHON_CMD := "uv run python"
; Audio device ID (optional, leave empty for default microphone)
; Run: uv run python recorder.py --list-devices to see available devices
global AUDIO_DEVICE := ""
; =======================================================

; Global variables
global isRecording := false
global recordingProcess := 0
global outputFile := ""
global stopFlagFile := ""
global tempDir := A_Temp "\whisper_dictation"
global scriptDir := A_ScriptDir

; Create temp directory if it doesn't exist
if !DirExist(tempDir) {
    DirCreate(tempDir)
}

; Debug logging function
LogDebug(message) {
    global tempDir
    logFile := tempDir "\ahk_debug.log"
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend("[" timestamp "] " message "`n", logFile)
}

; Log startup
LogDebug("Script started! Waiting for Win+F1...")
LogDebug("Temp dir: " tempDir)
LogDebug("Script dir: " scriptDir)
LogDebug("Python CMD: " PYTHON_CMD)

; Clean up any stale stop flag files from previous sessions
CleanupStaleFlags() {
    global tempDir
    LogDebug("Cleaning up stale stop flag files...")
    try {
        Loop Files, tempDir "\*.stop" {
            FileDelete(A_LoopFileFullPath)
            LogDebug("Deleted stale flag: " A_LoopFileName)
        }
    } catch Error as err {
        LogDebug("Error cleaning up flags: " err.Message)
    }
}

; Run cleanup on startup
CleanupStaleFlags()

; Win+F1 - Hold to record
#F1::
{
    global isRecording, recordingProcess, outputFile, stopFlagFile, tempDir, scriptDir, PYTHON_CMD, AUDIO_DEVICE

    if (!isRecording) {
        LogDebug("Win+F1 pressed - starting recording")
        isRecording := true

        ; Generate unique filename with timestamp
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")
        outputFile := tempDir "\recording_" timestamp ".wav"
        stopFlagFile := tempDir "\recording_" timestamp ".stop"
        LogDebug("Output file: " outputFile)
        LogDebug("Stop flag file: " stopFlagFile)

        ; Show tooltip
        ToolTip("Recording... (Hold Win+F1)")
        SoundBeep(600, 100)  ; Beep to indicate start

        ; Build Python command
        recorderScript := scriptDir "\recorder.py"
        pythonCmd := PYTHON_CMD ' "' recorderScript '" "' outputFile '"'

        ; Add device parameter if specified
        if (AUDIO_DEVICE != "") {
            pythonCmd .= " " AUDIO_DEVICE
        }

        LogDebug("Python command: " pythonCmd)

        ; Start recording
        try {
            recordingProcess := Run(pythonCmd, , "Hide")
            LogDebug("Process started with PID: " recordingProcess)
        } catch Error as err {
            LogDebug("ERROR: " err.Message)
            ToolTip("Error starting recording:`n" err.Message)
            SetTimer () => ToolTip(), -3000
            isRecording := false
            return
        }

        ; Wait for key release
        KeyWait("F1")

        ; Stop recording
        StopRecording()
    }
}

StopRecording() {
    global isRecording, recordingProcess, outputFile, stopFlagFile, scriptDir, PYTHON_CMD

    if (isRecording) {
        LogDebug("Stopping recording, PID: " recordingProcess)

        ; Create stop flag file to signal Python to stop gracefully
        try {
            FileAppend("", stopFlagFile)
            LogDebug("Stop flag file created: " stopFlagFile)
        } catch Error as err {
            LogDebug("Error creating stop flag: " err.Message)
            ; Fall back to process killing if flag creation fails
            if (recordingProcess != 0) {
                ProcessClose(recordingProcess)
                LogDebug("Fallback: killed process with ProcessClose")
            }
            isRecording := false
            return
        }

        ; Give Python time to detect the flag (it checks every 200ms)
        ; Python will clean up the flag file itself
        LogDebug("Waiting for Python to detect stop flag...")
        Sleep(500)  ; Wait 500ms for Python to see the flag

        isRecording := false
        LogDebug("Recording stopped, file should be at: " outputFile)

        ; Play a sound to indicate recording stopped
        SoundBeep(800, 100)

        ; Wait for file to be written (check for existence with timeout)
        maxWaitMs := 3000
        waitedMs := 0
        while (!FileExist(outputFile) && waitedMs < maxWaitMs) {
            Sleep(100)
            waitedMs += 100
        }

        if (!FileExist(outputFile)) {
            LogDebug("ERROR: Recording file was not created")
            ToolTip("Error: Recording file not created", , , 1)
            SetTimer () => ToolTip("", , , 1), -3000
            return
        }

        LogDebug("Recording file exists, starting transcription...")

        ; Show transcription progress tooltip
        ToolTip("Transcribing...", , , 1)

        ; Build command to transcribe and type
        transcribeScript := scriptDir "\transcribe_and_type.py"
        transcribeCmd := PYTHON_CMD ' "' transcribeScript '" "' outputFile '"'
        LogDebug("Transcribe command: " transcribeCmd)

        ; Run transcription (synchronously, wait for completion)
        try {
            RunWait(transcribeCmd, , "Hide")
            LogDebug("Transcription completed")
            ToolTip("Transcription complete!", , , 1)
            SetTimer () => ToolTip("", , , 1), -1000  ; Hide after 1 second
        } catch Error as err {
            LogDebug("ERROR during transcription: " err.Message)
            ToolTip("Transcription error - check logs", , , 1)
            SetTimer () => ToolTip("", , , 1), -3000
        }
    }
}

; Show startup message
TrayTip("Hold-to-Record Ready", "Press and hold Win+F1 to record audio")
