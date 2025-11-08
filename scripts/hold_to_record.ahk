#Requires AutoHotkey v2.0
#SingleInstance Force

; ==================== CONFIGURATION ====================
; Configuration is now loaded from config/client.env
; This section contains derived/computed values
; =======================================================

; Global variables
global isRecording := false
global recordingProcess := 0
global outputFile := ""
global stopFlagFile := ""
global tempDir := ""  ; Will be set from config or default
global scriptDir := A_ScriptDir
global projectRoot := scriptDir "\..\"  ; Project root is parent of scripts/
global srcDir := projectRoot "src"
global configDir := projectRoot "config"
global clientConfigFile := configDir "\client.env"

; Configuration variables (loaded from config file)
global PYTHON_CMD := "uv run python"
global AUDIO_DEVICE := ""
global HOTKEY_CONFIG := "Win+F1"  ; Default fallback
global HOTKEY_BASE_KEY := "F1"     ; Base key for KeyWait (extracted from hotkey)
global PASTE_HOTKEY_CONFIG := "Win+V"  ; Default paste hotkey
global PASTE_HOTKEY_BASE := ""
global TEMP_DIR_CONFIG := ""  ; User-configured temp dir

; Context capture variables (captured on hotkey release)
global capturedWindowID := 0
global capturedControl := ""
global capturedCaretStart := -1
global capturedCaretEnd := -1

; Last transcription (saved for pasting with Win+V)
global lastTranscription := ""

; Debug logging function
LogDebug(message) {
    global tempDir
    logFile := tempDir "\ahk_debug.log"
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend("[" timestamp "] " message "`n", logFile)
}

; Read configuration from client.env file
LoadConfig() {
    global clientConfigFile, AUDIO_DEVICE, HOTKEY_CONFIG, PASTE_HOTKEY_CONFIG, TEMP_DIR_CONFIG

    LogDebug("Loading config from: " clientConfigFile)

    if !FileExist(clientConfigFile) {
        LogDebug("WARNING: Config file not found, using defaults")
        return
    }

    try {
        configContent := FileRead(clientConfigFile)

        ; Parse each line
        Loop Parse, configContent, "`n", "`r" {
            line := Trim(A_LoopField)

            ; Skip empty lines and comments
            if (line = "" || SubStr(line, 1, 1) = "#") {
                continue
            }

            ; Parse KEY=VALUE
            if InStr(line, "=") {
                parts := StrSplit(line, "=", , 2)
                key := Trim(parts[1])
                value := Trim(parts[2])

                ; Strip inline comments (everything after #)
                if InStr(value, "#") {
                    commentPos := InStr(value, "#")
                    value := SubStr(value, 1, commentPos - 1)
                    value := Trim(value)
                }

                ; Load relevant config values
                if (key = "AUDIO_DEVICE") {
                    AUDIO_DEVICE := value
                    LogDebug("Loaded AUDIO_DEVICE: " value)
                } else if (key = "HOTKEY") {
                    HOTKEY_CONFIG := value
                    LogDebug("Loaded HOTKEY: " value)
                } else if (key = "PASTE_HOTKEY") {
                    PASTE_HOTKEY_CONFIG := value
                    LogDebug("Loaded PASTE_HOTKEY: " value)
                } else if (key = "TEMP_DIR") {
                    TEMP_DIR_CONFIG := value
                    LogDebug("Loaded TEMP_DIR: " value)
                }
            }
        }
    } catch Error as err {
        LogDebug("ERROR loading config: " err.Message)
    }
}

; Convert user-friendly hotkey format to AHK format
; Examples: "Win+F1" -> {ahkFormat: "#F1", baseKey: "F1"}
ConvertHotkeyFormat(userFormat) {
    LogDebug("Converting hotkey: " userFormat)

    ahkFormat := ""
    baseKey := ""
    parts := StrSplit(userFormat, "+")

    ; Process each part
    for index, part in parts {
        part := Trim(part)

        ; Convert modifiers
        if (part = "Win") {
            ahkFormat .= "#"
        } else if (part = "Ctrl") {
            ahkFormat .= "^"
        } else if (part = "Alt") {
            ahkFormat .= "!"
        } else if (part = "Shift") {
            ahkFormat .= "+"
        } else {
            ; This is the actual key (last part)
            ahkFormat .= part
            baseKey := part
        }
    }

    LogDebug("Converted to: " ahkFormat " (base key: " baseKey ")")
    return {ahkFormat: ahkFormat, baseKey: baseKey}
}

; Log startup
LogDebug("Script started!")
LogDebug("Script dir: " scriptDir)
LogDebug("Python CMD: " PYTHON_CMD)

; Load configuration
LoadConfig()

; Set temp directory from config or use default
if (TEMP_DIR_CONFIG != "") {
    tempDir := TEMP_DIR_CONFIG
    LogDebug("Using configured temp dir: " tempDir)
} else {
    tempDir := A_Temp "\whisper_dictation"
    LogDebug("Using default temp dir: " tempDir)
}

; Create temp directory if it doesn't exist
if !DirExist(tempDir) {
    DirCreate(tempDir)
    LogDebug("Created temp directory: " tempDir)
}

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

; ==================== CARET POSITION FUNCTIONS ====================

; Try to capture caret position for simple Edit controls
; Returns: {start: pos, end: pos} or {start: -1, end: -1} if failed
CaptureCaret(controlHwnd) {
    try {
        ; EM_GETSEL = 0xB0 (gets selection start and end)
        ; SendMessage returns the selection, wParam/lParam receive the positions
        result := SendMessage(0xB0, 0, 0, , "ahk_id " controlHwnd)

        ; Result contains start in low word, end in high word
        ; But for now, we'll just get the caret position from EM_GETSEL differently
        startPos := result & 0xFFFF
        endPos := (result >> 16) & 0xFFFF

        LogDebug("Caret: Captured position " startPos " - " endPos " for control " controlHwnd)
        return {start: startPos, end: endPos}
    } catch as err {
        LogDebug("Caret: Could not capture position: " err.Message)
        return {start: -1, end: -1}
    }
}

; Try to restore caret position for simple Edit controls
; Returns: true if successful, false otherwise
RestoreCaret(controlHwnd, caretPos) {
    if (caretPos.start < 0) {
        LogDebug("Caret: No valid position to restore")
        return false
    }

    try {
        ; EM_SETSEL = 0xB1 (sets selection/caret position)
        SendMessage(0xB1, caretPos.start, caretPos.end, , "ahk_id " controlHwnd)
        LogDebug("Caret: Restored position " caretPos.start " - " caretPos.end " for control " controlHwnd)
        return true
    } catch as err {
        LogDebug("Caret: Could not restore position: " err.Message)
        return false
    }
}

; ==================== TYPING FUNCTION ====================

; Type text using AHK's native SendInput (faster and no focus issues)
TypeText(text) {
    if (text = "") {
        LogDebug("TypeText: Empty text, nothing to type")
        return
    }

    try {
        LogDebug("TypeText: Typing " StrLen(text) " characters")

        ; Use SendInput for fast, reliable typing
        ; SendInput queues keystrokes and is atomic (won't be interrupted)
        SendInput("{Text}" text)

        LogDebug("TypeText: Completed successfully")

    } catch Error as err {
        LogDebug("TypeText ERROR: " err.Message)
    }
}

; ==================== HOTKEY HANDLERS ====================

; Handler for paste hotkey (Win+V)
HandlePasteHotkey() {
    global lastTranscription

    LogDebug("Paste hotkey pressed")

    if (lastTranscription = "") {
        LogDebug("Paste: No transcription saved, doing nothing")
        return
    }

    LogDebug("Paste: Typing last transcription: '" lastTranscription "'")
    TypeText(lastTranscription)
}

; Handler for hold-to-record hotkey
HandleRecordingHotkey() {
    global isRecording, recordingProcess, outputFile, stopFlagFile, tempDir, scriptDir, PYTHON_CMD, AUDIO_DEVICE

    if (!isRecording) {
        LogDebug("Recording hotkey pressed - starting recording")
        isRecording := true

        ; Generate unique filename with timestamp
        timestamp := FormatTime(, "yyyyMMdd_HHmmss")
        outputFile := tempDir "\recording_" timestamp ".wav"
        stopFlagFile := tempDir "\recording_" timestamp ".stop"
        LogDebug("Output file: " outputFile)
        LogDebug("Stop flag file: " stopFlagFile)

        ; Show tooltip
        ToolTip("Recording... (Hold hotkey)")
        SoundBeep(600, 100)  ; Beep to indicate start

        ; Build Python command
        recorderScript := srcDir "\record.py"
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
        KeyWait(HOTKEY_BASE_KEY)

        ; Stop recording
        StopRecording()
    }
}

StopRecording() {
    global isRecording, recordingProcess, outputFile, stopFlagFile, scriptDir, PYTHON_CMD
    global capturedWindowID, capturedControl, capturedCaretStart, capturedCaretEnd, lastTranscription

    if (isRecording) {
        LogDebug("Stopping recording, PID: " recordingProcess)

        ; Play a sound immediately to indicate release detected
        SoundBeep(800, 100)

        ; ===== CAPTURE CONTEXT ON RELEASE =====
        capturedWindowID := WinGetID("A")
        capturedWindowTitle := WinGetTitle("A")
        LogDebug("Context: Captured window " capturedWindowID " (" capturedWindowTitle ")")

        ; Try to capture focused control
        try {
            capturedControl := ControlGetFocus("ahk_id " capturedWindowID)
            LogDebug("Context: Captured control " capturedControl)

            ; Try to capture caret position (best effort for simple Edit controls)
            if (capturedControl != "") {
                try {
                    controlHwnd := ControlGetHwnd(capturedControl, "ahk_id " capturedWindowID)
                    caretPos := CaptureCaret(controlHwnd)
                    capturedCaretStart := caretPos.start
                    capturedCaretEnd := caretPos.end
                } catch {
                    capturedCaretStart := -1
                    capturedCaretEnd := -1
                    LogDebug("Context: Could not capture caret position")
                }
            }
        } catch {
            capturedControl := ""
            capturedCaretStart := -1
            capturedCaretEnd := -1
            LogDebug("Context: Could not capture control")
        }

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

        ; Give Python time to detect the flag and write the file (2 tries of 250ms)
        ; Python checks every 200ms
        LogDebug("Waiting for Python to detect stop flag...")
        Sleep(250)  ; First wait

        if (!FileExist(outputFile)) {
            LogDebug("File not ready, waiting another 250ms...")
            Sleep(250)  ; Second try
        }

        isRecording := false
        LogDebug("Recording stopped, file should be at: " outputFile)

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

        ; Build command to transcribe (get text without typing)
        transcribeScript := srcDir "\transcribe.py"
        transcribeCmd := PYTHON_CMD ' "' transcribeScript '" "' outputFile '"'
        LogDebug("Transcribe command: " transcribeCmd)

        ; Run transcription and capture output
        try {
            ; Create temp file for output capture
            tempOutputFile := tempDir "\transcription_output.txt"

            ; Delete old output file if exists
            if FileExist(tempOutputFile) {
                FileDelete(tempOutputFile)
            }

            ; Use ComSpec to run command with proper redirection
            shellCmd := A_ComSpec ' /c "' transcribeCmd ' > "' tempOutputFile '""'
            RunWait(shellCmd, , "Hide")

            ; Read the transcribed text
            if FileExist(tempOutputFile) {
                transcribedText := FileRead(tempOutputFile)
                FileDelete(tempOutputFile)  ; Clean up

                LogDebug("Transcription received: '" transcribedText "'")
                ToolTip("", , , 1)  ; Hide tooltip

                ; Check if transcription is empty
                if (transcribedText = "" || transcribedText = "`r`n" || transcribedText = "`n") {
                    LogDebug("Empty transcription, nothing to type/queue")
                    return
                }

                ; ===== SAVE TRANSCRIPTION =====
                ; Always save to lastTranscription (available via Win+V)
                lastTranscription := transcribedText
                LogDebug("Saved transcription to lastTranscription: '" transcribedText "'")

                ; ===== WINDOW MATCHING LOGIC =====
                currentWindowID := WinGetID("A")
                currentWindowTitle := WinGetTitle("A")
                LogDebug("Window check: Current=" currentWindowID " (" currentWindowTitle "), Captured=" capturedWindowID)

                if (currentWindowID = capturedWindowID) {
                    ; Same window - also type directly with caret restoration
                    LogDebug("Window MATCH - typing directly (transcription already saved)")

                    ; Try to restore control focus (best effort)
                    if (capturedControl != "") {
                        try {
                            ControlFocus(capturedControl, "ahk_id " capturedWindowID)
                            Sleep(50)  ; Small delay for focus to establish
                            LogDebug("Restored control focus: " capturedControl)
                        } catch as err {
                            LogDebug("Could not restore control focus: " err.Message)
                        }
                    }

                    ; Try to restore caret position (best effort)
                    if (capturedCaretStart >= 0 && capturedControl != "") {
                        try {
                            controlHwnd := ControlGetHwnd(capturedControl, "ahk_id " capturedWindowID)
                            RestoreCaret(controlHwnd, {start: capturedCaretStart, end: capturedCaretEnd})
                            Sleep(50)  ; Small delay for caret to be set
                        } catch as err {
                            LogDebug("Could not restore caret: " err.Message)
                        }
                    }

                    ; Type the text using AHK's native SendInput
                    TypeText(transcribedText)

                } else {
                    ; Different window - transcription already saved for later pasting
                    LogDebug("Window MISMATCH - transcription saved for Win+V pasting")
                }

            } else {
                LogDebug("ERROR: Transcription output file not found")
                ToolTip("Transcription error - check logs", , , 1)
                SetTimer () => ToolTip("", , , 1), -3000
            }

        } catch Error as err {
            LogDebug("ERROR during transcription: " err.Message)
            ToolTip("Transcription error - check logs", , , 1)
            SetTimer () => ToolTip("", , , 1), -3000
        }
    }
}

; Register the recording hotkey dynamically
hotkeyInfo := ConvertHotkeyFormat(HOTKEY_CONFIG)
HOTKEY_BASE_KEY := hotkeyInfo.baseKey
ahkHotkey := hotkeyInfo.ahkFormat

LogDebug("Registering recording hotkey: " ahkHotkey " (base key: " HOTKEY_BASE_KEY ")")

try {
    Hotkey(ahkHotkey, (*) => HandleRecordingHotkey(), "On")
    LogDebug("Recording hotkey registered successfully!")
} catch Error as err {
    LogDebug("ERROR: Failed to register recording hotkey: " err.Message)
    MsgBox("Failed to register hotkey: " HOTKEY_CONFIG "`n`nError: " err.Message "`n`nPlease check your config/client.env file.")
    ExitApp()
}

; Register the paste hotkey dynamically
pasteHotkeyInfo := ConvertHotkeyFormat(PASTE_HOTKEY_CONFIG)
PASTE_HOTKEY_BASE := pasteHotkeyInfo.baseKey
ahkPasteHotkey := pasteHotkeyInfo.ahkFormat

LogDebug("Registering paste hotkey: " ahkPasteHotkey " (base key: " PASTE_HOTKEY_BASE ")")

try {
    Hotkey(ahkPasteHotkey, (*) => HandlePasteHotkey(), "On")
    LogDebug("Paste hotkey registered successfully!")
} catch Error as err {
    LogDebug("ERROR: Failed to register paste hotkey: " err.Message)
    MsgBox("Failed to register paste hotkey: " PASTE_HOTKEY_CONFIG "`n`nError: " err.Message "`n`nPlease check your config/client.env file.")
    ExitApp()
}

; Show startup message
TrayTip("Hold-to-Record Ready", "Press and hold " HOTKEY_CONFIG " to record audio`nPress " PASTE_HOTKEY_CONFIG " to paste last transcription")
