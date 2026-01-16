Scriptname SNSWhisperWidget extends SKI_WidgetBase

;===========================================
; PROPERTIES
;===========================================

; Quest containing skynet_Library script for Papyrus hotkey support
Quest Property SkyrimNetLibraryQuest Auto

;===========================================
; STATE TRACKING
;===========================================

; Previous state values to prevent redundant UI updates
Bool lastWhisperState = False      ; Last known whisper mode state
Bool lastRecordingState = False    ; Last known recording/open mic state
Bool lastGlobalAIState = True      ; Last known global AI state

; Hotkey management
Int whisperHotkey = -1              ; Currently registered hotkey code (-1 = none)
Int globalAIHotkey = -1             ; Global AI toggle hotkey (C++ mode only, -1 = none)
Bool usePapyrusHotkeys = False     ; True = Papyrus hotkeys, False = C++ hotkeys

; Recording hotkey tracking (for hotkey-only mode)
Int recordSpeechHotkey = -1         ; RecordSpeech hotkey
Int toggleOpenMicHotkey = -1        ; ToggleOpenMic hotkey
Int voiceThoughtHotkey = -1         ; VoiceThought hotkey
Int voiceDialogueTransformHotkey = -1  ; VoiceDialogueTransform hotkey
Int voiceDirectInputHotkey = -1     ; VoiceDirectInput hotkey

; Key press state tracking (for detecting held keys across reload)
Bool recordSpeechPressed = False
Bool toggleOpenMicPressed = False
Bool voiceThoughtPressed = False
Bool voiceDialoguePressed = False
Bool voiceDirectInputPressed = False

; Temporary post-reload polling (for hotkey mode)
Int tempPollCount = 0               ; Counter for temporary polls after reload
Int maxTempPolls = 6                ; Poll 6 times (18 seconds at 3s interval) after reload
Int maxTimeoutPolls = 20            ; Maximum 20 polls (60 seconds at 3s) before timeout
Bool tempPollingTimedOut = False    ; Flag if temp polling exceeded timeout
Float fTempPollInterval = 3.0       ; Temp polling interval (3 seconds to reduce init load)

; Burst polling when hotkey pressed (for hotkey mode)
Int burstPollCount = 0              ; Counter for burst polls after key press
Int maxBurstPolls = 4               ; Poll 4 times at 0.1s intervals (covers 0.4s window)

;===========================================
; SETTINGS (configurable via MCM)
;===========================================

Bool widgetVisible = True           ; Master visibility toggle
Int widgetSize = 100                ; Scale percentage (50-200, default 100)
Int widgetOpacity = 100             ; Opacity percentage (0-100, default 100)
Bool bShowRecordingIndicator = True  ; Enable recording/open mic indicator
Bool bHideWhenInactive = False      ; Auto-hide when whisper OFF and not recording
Bool bUseHotkeyMode = True          ; True = hotkey-only updates (DEFAULT), False = polling mode
Float fPollInterval = 0.5           ; Polling interval (seconds) when not using hotkey mode

; Master visibility toggle property
; When set to false, widget is hidden regardless of whisper/recording state
Bool Property Visible
    Bool Function Get()
        Return widgetVisible
    EndFunction
    
    Function Set(Bool a_val)
        widgetVisible = a_val
        If (Ready)
            ; Force full status update to ensure proper visibility state
            UpdateStatus(true)
        EndIf
    EndFunction
EndProperty

; Widget scale property (percentage: 50-200)
; 100 = normal size, 50 = half size, 200 = double size
Int Property Size
    Int Function Get()
        Return widgetSize
    EndFunction
    
    Function Set(Int a_val)
        widgetSize = a_val
        If (Ready)
            ; Update Flash widget scale
            UI.SetFloat(HUD_MENU, WidgetRoot + "._xscale", widgetSize as Float)
            UI.SetFloat(HUD_MENU, WidgetRoot + "._yscale", widgetSize as Float)
        EndIf
    EndFunction
EndProperty

; Widget opacity (alpha transparency)
; Controls how transparent the widget appears (0 = invisible, 100 = fully opaque)
Int Property Opacity
    Int Function Get()
        Return widgetOpacity
    EndFunction
    
    Function Set(Int a_val)
        widgetOpacity = a_val
        If (Ready)
            ; Update Flash widget alpha (0-100 range)
            UI.SetInt(HUD_MENU, WidgetRoot + "._alpha", widgetOpacity)
        EndIf
    EndFunction
EndProperty

; Recording/Open Mic indicator toggle
; When enabled, shows recording indicator (via hotkeys or polling depending on mode)
; In polling mode: starts/stops periodic polling
; In hotkey mode: registers/unregisters recording hotkeys
Bool Property ShowRecordingIndicator
    Bool Function Get()
        Return bShowRecordingIndicator
    EndFunction
    
    Function Set(Bool a_val)
        bShowRecordingIndicator = a_val
        
        If (Ready)
            ; Force immediate update to reflect new state
            UpdateStatus()
            
            ; Handle mode-specific behavior
            If a_val
                If bUseHotkeyMode
                    ; Hotkey mode: register recording hotkeys
                    LoadRecordingHotkeys()
                Else
                    ; Polling mode: start polling
                    RegisterForSingleUpdate(pollInterval)
                EndIf
            Else
                If bUseHotkeyMode
                    ; Hotkey mode: unregister recording hotkeys
                    UnregisterRecordingHotkeys()
                Else
                    ; Polling mode: stop polling
                    UnregisterForUpdate()
                EndIf
            EndIf
        EndIf
    EndFunction
EndProperty

; Auto-hide feature toggle
; When enabled, hides widget when both whisper mode is OFF and not recording
; Widget only shows when "active" (whisper mode ON or recording)
Bool Property HideWhenInactive
    Bool Function Get()
        Return bHideWhenInactive
    EndFunction
    
    Function Set(Bool a_val)
        bHideWhenInactive = a_val
        
        If (Ready)
            ; Force immediate update to apply new visibility logic
            UpdateStatus()
        EndIf
    EndFunction
EndProperty

; Update mode toggle
; True = Hotkey-only mode (instant updates, no polling)
; False = Polling mode (periodic checks, works with dashboard changes)
Bool Property UseHotkeyMode
    Bool Function Get()
        Return bUseHotkeyMode
    EndFunction
    
    Function Set(Bool a_val)
        bUseHotkeyMode = a_val
        
        If (Ready)
            ; Switch between modes
            If a_val
                ; Switching to hotkey mode
                UnregisterForUpdate()  ; Stop polling
                If bShowRecordingIndicator
                    LoadRecordingHotkeys()  ; Register recording hotkeys
                EndIf
            Else
                ; Switching to polling mode
                burstPollCount = maxBurstPolls  ; Stop any burst polling
                If bShowRecordingIndicator
                    UnregisterRecordingHotkeys()  ; Unregister recording hotkeys
                    RegisterForSingleUpdate(fPollInterval)  ; Start polling
                EndIf
            EndIf
            
            ; Update status with new mode
            UpdateStatus()
        EndIf
    EndFunction
EndProperty

; Polling interval property (polling mode only)
; Controls how often the widget checks whisper and recording state
; Range: 0.1 - 1.0 seconds
Float Property PollInterval
    Float Function Get()
        Return fPollInterval
    EndFunction
    
    Function Set(Float a_val)
        fPollInterval = a_val
        
        ; If currently in polling mode with recording indicator enabled,
        ; restart polling with new interval
        If (Ready && !bUseHotkeyMode && bShowRecordingIndicator)
            UnregisterForUpdate()
            RegisterForSingleUpdate(fPollInterval)
        EndIf
    EndFunction
EndProperty

;===========================================
; INITIALIZATION EVENTS
;===========================================

Event OnInit()
    Debug.Trace("[SNSWhisperWidget] OnInit() called")
    
    ; Set default position BEFORE calling Parent.OnInit()
    ; This ensures correct position on first load (Bottom Right corner)
    X = 1272.0          ; Horizontal position
    Y = 716.0           ; Vertical position
    HAnchor = "right"   ; Anchor to right edge
    VAnchor = "bottom"  ; Anchor to bottom edge
    
    Debug.Trace("[SNSWhisperWidget] Calling Parent.OnInit()")
    Parent.OnInit()
    Debug.Trace("[SNSWhisperWidget] OnInit() complete, Ready=" + Ready)
EndEvent

; Called when player loads a save game
; This is the correct place to query SkyrimNet API (after game state is loaded)
Event OnGameReload()
    Debug.Trace("[SNSWhisperWidget] OnGameReload() called, Ready=" + Ready)
    
    Parent.OnGameReload()
    
    Debug.Trace("[SNSWhisperWidget] OnGameReload() complete, Ready=" + Ready)
    
    ; Check if any recording key was held during reload
    Bool keyWasHeld = recordSpeechPressed || voiceThoughtPressed || voiceDialoguePressed || voiceDirectInputPressed
    
    ; Clear all key pressed states (reload breaks key tracking)
    recordSpeechPressed = False
    toggleOpenMicPressed = False
    voiceThoughtPressed = False
    voiceDialoguePressed = False
    voiceDirectInputPressed = False
    
    ; Detect and register whisper mode hotkey (C++ or Papyrus)
    LoadHotkeyFromConfig()
    
    ; Re-register recording hotkeys if in hotkey mode
    If bShowRecordingIndicator && bUseHotkeyMode
        LoadRecordingHotkeys()
    EndIf
EndEvent

;===========================================
; HOTKEY CONVERSION
;===========================================

; Converts Windows Virtual Key codes (VK_*) to Skyrim DirectInput scan codes
; Required for C++ hotkey system which uses Windows VK codes in config
; VK codes: https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
; Returns: Skyrim key code, or -1 if unsupported
Int Function ConvertVKInputToSkyrim(Int vkCode)
    
    ; Numbers 0-9 (VK 0x30-0x39 / 48-57)
    If vkCode == 48
        Return 11  ; 0
    ElseIf vkCode >= 49 && vkCode <= 57
        Return vkCode - 47  ; 1-9 -> 2-10
    
    ; Letters A-Z (VK 0x41-0x5A / 65-90)
    ElseIf vkCode == 65
        Return 30  ; A
    ElseIf vkCode == 66
        Return 48  ; B
    ElseIf vkCode == 67
        Return 46  ; C
    ElseIf vkCode == 68
        Return 32  ; D
    ElseIf vkCode == 69
        Return 18  ; E
    ElseIf vkCode == 70
        Return 33  ; F
    ElseIf vkCode == 71
        Return 34  ; G
    ElseIf vkCode == 72
        Return 35  ; H
    ElseIf vkCode == 73
        Return 23  ; I
    ElseIf vkCode == 74
        Return 36  ; J
    ElseIf vkCode == 75
        Return 37  ; K
    ElseIf vkCode == 76
        Return 38  ; L
    ElseIf vkCode == 77
        Return 50  ; M
    ElseIf vkCode == 78
        Return 49  ; N
    ElseIf vkCode == 79
        Return 24  ; O
    ElseIf vkCode == 80
        Return 25  ; P
    ElseIf vkCode == 81
        Return 16  ; Q
    ElseIf vkCode == 82
        Return 19  ; R
    ElseIf vkCode == 83
        Return 31  ; S
    ElseIf vkCode == 84
        Return 20  ; T
    ElseIf vkCode == 85
        Return 22  ; U
    ElseIf vkCode == 86
        Return 47  ; V
    ElseIf vkCode == 87
        Return 17  ; W
    ElseIf vkCode == 88
        Return 45  ; X
    ElseIf vkCode == 89
        Return 21  ; Y
    ElseIf vkCode == 90
        Return 44  ; Z
    
    ; Function keys F1-F24 (VK 0x70-0x87 / 112-135)
    ElseIf vkCode >= 112 && vkCode <= 123
        Return vkCode - 53  ; F1-F12 -> 59-70
    ElseIf vkCode >= 124 && vkCode <= 135
        Return vkCode  ; F13-F24 -> 124-135
    
    ; Special keys
    ElseIf vkCode == 27
        Return 1   ; ESC
    ElseIf vkCode == 32
        Return 57  ; Space
    ElseIf vkCode == 13
        Return 28  ; Enter
    ElseIf vkCode == 9
        Return 15  ; Tab
    ElseIf vkCode == 8
        Return 14  ; Backspace
    ElseIf vkCode == 16
        Return 42  ; Shift (left)
    ElseIf vkCode == 17
        Return 29  ; Ctrl (left)
    ElseIf vkCode == 18
        Return 56  ; Alt (left)
    ElseIf vkCode == 20
        Return 58  ; Caps Lock
    ElseIf vkCode == 19
        Return 70  ; Pause
    
    ; Punctuation keys
    ElseIf vkCode == 189
        Return 12  ; - (minus)
    ElseIf vkCode == 187
        Return 13  ; = (equals)
    ElseIf vkCode == 219
        Return 26  ; [
    ElseIf vkCode == 221
        Return 27  ; ]
    ElseIf vkCode == 186
        Return 39  ; ;
    ElseIf vkCode == 222
        Return 40  ; '
    ElseIf vkCode == 192
        Return 41  ; `
    ElseIf vkCode == 220
        Return 43  ; \
    ElseIf vkCode == 188
        Return 51  ; , (comma)
    ElseIf vkCode == 190
        Return 52  ; . (period)
    ElseIf vkCode == 191
        Return 53  ; / (slash)
    
    ; Arrow keys
    ElseIf vkCode == 37
        Return 203  ; Left
    ElseIf vkCode == 38
        Return 200  ; Up
    ElseIf vkCode == 39
        Return 205  ; Right
    ElseIf vkCode == 40
        Return 208  ; Down
    
    ; Navigation keys
    ElseIf vkCode == 45
        Return 210  ; Insert
    ElseIf vkCode == 46
        Return 211  ; Delete
    ElseIf vkCode == 36
        Return 199  ; Home
    ElseIf vkCode == 35
        Return 207  ; End
    ElseIf vkCode == 33
        Return 201  ; Page Up
    ElseIf vkCode == 34
        Return 209  ; Page Down
    ElseIf vkCode == 44
        Return 183  ; Print Screen
    ElseIf vkCode == 145
        Return 70  ; Scroll Lock
    
    ; Numpad keys (VK 0x60-0x6F / 96-111)
    ElseIf vkCode == 96
        Return 82  ; Num 0
    ElseIf vkCode == 97
        Return 79  ; Num 1
    ElseIf vkCode == 98
        Return 80  ; Num 2
    ElseIf vkCode == 99
        Return 81  ; Num 3
    ElseIf vkCode == 100
        Return 75  ; Num 4
    ElseIf vkCode == 101
        Return 76  ; Num 5
    ElseIf vkCode == 102
        Return 77  ; Num 6
    ElseIf vkCode == 103
        Return 71  ; Num 7
    ElseIf vkCode == 104
        Return 72  ; Num 8
    ElseIf vkCode == 105
        Return 73  ; Num 9
    ElseIf vkCode == 106
        Return 55  ; Num *
    ElseIf vkCode == 107
        Return 78  ; Num +
    ElseIf vkCode == 109
        Return 74  ; Num -
    ElseIf vkCode == 110
        Return 83  ; Num Del
    ElseIf vkCode == 111
        Return 181  ; Num /
    ElseIf vkCode == 144
        Return 69  ; Num Lock
    
    ; Extended keys
    ElseIf vkCode == 160
        Return 42  ; Left Shift
    ElseIf vkCode == 161
        Return 54  ; Right Shift
    ElseIf vkCode == 162
        Return 29  ; Left Ctrl
    ElseIf vkCode == 163
        Return 157  ; Right Ctrl
    ElseIf vkCode == 164
        Return 56  ; Left Alt
    ElseIf vkCode == 165
        Return 184  ; Right Alt
    
    Else
        Return -1  ; Unsupported key
    EndIf
EndFunction

;===========================================
; WIDGET LIFECYCLE EVENTS
;===========================================

; Called when widget is reset (UI reload, etc.)
; Sets up initial UI state and event registrations
Event OnWidgetReset()
    Debug.Trace("[SNSWhisperWidget] OnWidgetReset() called, Ready=" + Ready)
    
    ; Reset temp polling counter (but NOT burstPollCount - that's only for hotkeys)
    tempPollCount = 0
    
    Parent.OnWidgetReset()
    
    ; Apply saved settings to the Flash widget
    If (Ready)
        Debug.Trace("[SNSWhisperWidget] Applying widget settings")
        UI.SetFloat(HUD_MENU, WidgetRoot + "._xscale", widgetSize as Float)
        UI.SetFloat(HUD_MENU, WidgetRoot + "._yscale", widgetSize as Float)
        UI.SetInt(HUD_MENU, WidgetRoot + "._alpha", widgetOpacity)
        
        ; Set initial visibility (UpdateStatus will apply global AI and hide-when-inactive logic)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", widgetVisible)
        Debug.Trace("[SNSWhisperWidget] Initial visibility set to: " + widgetVisible)
        
        ; Don't restore cached states - whisper mode resets to OFF on reload
        ; SkyrimNet always resets whisper mode to disabled, so cached state would be wrong
        ; Forced updates will set correct state within 1-2 seconds
    Else
        Debug.Trace("[SNSWhisperWidget] WARNING: Ready=False in OnWidgetReset!")
    EndIf
    
    ; Register for common menu types to catch state changes in menus
    ; This catches edge cases like typing hotkey in mod menu search fields
    RegisterForMenu("LoadingMenu")
    RegisterForMenu("Dialogue Menu")
    RegisterForMenu("ContainerMenu")
    RegisterForMenu("InventoryMenu")
    RegisterForMenu("MagicMenu")
    RegisterForMenu("BarterMenu")
    RegisterForMenu("GiftMenu")
    RegisterForMenu("JournalMenu")
    RegisterForMenu("MapMenu")
    RegisterForMenu("FavoritesMenu")
    RegisterForMenu("Console")
    RegisterForMenu("CustomMenu")  ; Many SKSE mods use this
    
    ; Register recording hotkeys if needed
    If bShowRecordingIndicator && bUseHotkeyMode
        LoadRecordingHotkeys()
    EndIf
    
    ; Always start initial polling after reset to establish state
    ; In hotkey mode, this will poll a few times then stop (controlled by tempPollCount)
    ; In polling mode, this will poll continuously
    If bUseHotkeyMode
        tempPollCount = 0  ; Reset temp poll counter
    EndIf
    RegisterForSingleUpdate(fTempPollInterval)
EndEvent

; Override to set custom modes before parent calls UpdateWidgetModes()
Event OnWidgetLoad()
    Debug.Trace("[SNSWhisperWidget] OnWidgetLoad() called, Ready=" + Ready)
    
    ; Set modes to include DialogueMode BEFORE parent sets them
    string[] modesArray = new string[7]
    modesArray[0] = "All"
    modesArray[1] = "StealthMode"
    modesArray[2] = "Favor"
    modesArray[3] = "Swimming"
    modesArray[4] = "HorseMode"
    modesArray[5] = "WarHorseMode"
    modesArray[6] = "DialogueMode"
    Modes = modesArray
        
    ; Now let parent handle the rest (will call UpdateWidgetModes with our modes)
    Parent.OnWidgetLoad()
    Debug.Trace("[SNSWhisperWidget] OnWidgetLoad() complete, Ready=" + Ready)
EndEvent

;===========================================
; HOTKEY MANAGEMENT
;===========================================

; Detects and registers recording-related hotkeys for hotkey-only mode
; Registers: RecordSpeech, ToggleOpenMic, VoiceThought, VoiceDialogueTransform, VoiceDirectInput
Function LoadRecordingHotkeys()
    ; Get hotkey system type
    Bool isPapyrus = !SkyrimNetApi.IsCppHotkeysEnabled()
    
    ; Arrays to store new hotkeys
    Int newRecordSpeech = -1
    Int newToggleOpenMic = -1
    Int newVoiceThought = -1
    Int newVoiceDialogue = -1
    Int newVoiceDirectInput = -1
    
    If isPapyrus
        ; Papyrus system: Read from quest properties
        If SkyrimNetLibraryQuest
            skynet_Library libraryScript = SkyrimNetLibraryQuest as skynet_Library
            If libraryScript
                newRecordSpeech = libraryScript.hotkeyRecordSpeech
                newToggleOpenMic = libraryScript.hotkeyToggleOpenMic
                newVoiceThought = libraryScript.hotkeyVoiceThought
                newVoiceDialogue = libraryScript.hotkeyVoiceDialogueTransform
                newVoiceDirectInput = libraryScript.hotkeyVoiceDirectInput
            EndIf
        EndIf
    Else
        ; C++ system: Read VK codes from config and convert
        newRecordSpeech = ConvertVKInputToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "recordSpeech", -1))
        newToggleOpenMic = ConvertVKInputToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "toggleOpenMic", -1))
        newVoiceThought = ConvertVKInputToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "voiceThought", -1))
        newVoiceDialogue = ConvertVKInputToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "voiceDialogueTransform", -1))
        newVoiceDirectInput = ConvertVKInputToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "voiceDirectInput", -1))
    EndIf
    
    ; Unregister old hotkeys
    If recordSpeechHotkey != -1
        UnregisterForKey(recordSpeechHotkey)
    EndIf
    If toggleOpenMicHotkey != -1
        UnregisterForKey(toggleOpenMicHotkey)
    EndIf
    If voiceThoughtHotkey != -1
        UnregisterForKey(voiceThoughtHotkey)
    EndIf
    If voiceDialogueTransformHotkey != -1
        UnregisterForKey(voiceDialogueTransformHotkey)
    EndIf
    If voiceDirectInputHotkey != -1
        UnregisterForKey(voiceDirectInputHotkey)
    EndIf
    
    ; Register new hotkeys
    recordSpeechHotkey = newRecordSpeech
    toggleOpenMicHotkey = newToggleOpenMic
    voiceThoughtHotkey = newVoiceThought
    voiceDialogueTransformHotkey = newVoiceDialogue
    voiceDirectInputHotkey = newVoiceDirectInput
    
    If recordSpeechHotkey != -1
        RegisterForKey(recordSpeechHotkey)
    EndIf
    If toggleOpenMicHotkey != -1
        RegisterForKey(toggleOpenMicHotkey)
    EndIf
    If voiceThoughtHotkey != -1
        RegisterForKey(voiceThoughtHotkey)
    EndIf
    If voiceDialogueTransformHotkey != -1
        RegisterForKey(voiceDialogueTransformHotkey)
    EndIf
    If voiceDirectInputHotkey != -1
        RegisterForKey(voiceDirectInputHotkey)
    EndIf
EndFunction

; Unregisters all recording-related hotkeys
Function UnregisterRecordingHotkeys()
    If recordSpeechHotkey != -1
        UnregisterForKey(recordSpeechHotkey)
        recordSpeechHotkey = -1
    EndIf
    If toggleOpenMicHotkey != -1
        UnregisterForKey(toggleOpenMicHotkey)
        toggleOpenMicHotkey = -1
    EndIf
    If voiceThoughtHotkey != -1
        UnregisterForKey(voiceThoughtHotkey)
        voiceThoughtHotkey = -1
    EndIf
    If voiceDialogueTransformHotkey != -1
        UnregisterForKey(voiceDialogueTransformHotkey)
        voiceDialogueTransformHotkey = -1
    EndIf
    If voiceDirectInputHotkey != -1
        UnregisterForKey(voiceDirectInputHotkey)
        voiceDirectInputHotkey = -1
    EndIf
EndFunction

; Detects and registers the whisper mode toggle hotkey
; Supports both C++ hotkeys (from config file) and Papyrus hotkeys (from quest)
; Automatically converts C++ VK codes to Skyrim scan codes
Function LoadHotkeyFromConfig()
    ; Determine which hotkey system SkyrimNet is using
    usePapyrusHotkeys = !SkyrimNetApi.IsCppHotkeysEnabled()
    
    Int newHotkey = -1
    Int newGlobalAIHotkey = -1
    
    If usePapyrusHotkeys
        ; Papyrus system: Read hotkey directly from quest property
        If SkyrimNetLibraryQuest
            skynet_Library libraryScript = SkyrimNetLibraryQuest as skynet_Library
            If libraryScript
                newHotkey = libraryScript.hotkeyToggleWhisperMode
                ; Global AI hotkey only available in Papyrus mode if exposed
            EndIf
        EndIf
    Else
        ; C++ system: Read VK code from config and convert to Skyrim code
        Int directInputKey = SkyrimNetApi.GetConfigInt("hotkey", "toggleWhisperMode", -1)
        newHotkey = ConvertVKInputToSkyrim(directInputKey)
        
        ; Also load global AI hotkey (C++ only)
        Int globalAIKey = SkyrimNetApi.GetConfigInt("hotkey", "toggleGlobalAI", -1)
        newGlobalAIHotkey = ConvertVKInputToSkyrim(globalAIKey)
    EndIf
    
    ; Re-register whisper hotkey if it changed
    If newHotkey != whisperHotkey
        ; Unregister old hotkey
        If whisperHotkey != -1
            UnregisterForKey(whisperHotkey)
        EndIf
        
        ; Register new hotkey
        whisperHotkey = newHotkey
        If whisperHotkey != -1
            RegisterForKey(whisperHotkey)
        EndIf
    EndIf
    
    ; Re-register global AI hotkey if it changed
    If newGlobalAIHotkey != globalAIHotkey
        ; Unregister old hotkey
        If globalAIHotkey != -1
            UnregisterForKey(globalAIHotkey)
        EndIf
        
        ; Register new hotkey
        globalAIHotkey = newGlobalAIHotkey
        If globalAIHotkey != -1
            RegisterForKey(globalAIHotkey)
        EndIf
    EndIf
EndFunction

;===========================================
; EVENT HANDLERS
;===========================================

; Handles hotkey press for instant widget update
; Called when registered hotkey is pressed
Event OnKeyDown(Int keyCode)
    If keyCode == whisperHotkey
        ; Start burst polling to catch config update
        ; Polls at 0.1s intervals for up to 0.4s total (4 polls)
        ; Process even in menu mode (e.g., typing in search fields)
        burstPollCount = 0
        tempPollCount = maxTempPolls  ; Stop any temp polling
        RegisterForSingleUpdate(0.1)
        
    ElseIf !Utility.IsInMenuMode()
        If keyCode == globalAIHotkey && globalAIHotkey != -1
            ; Global AI toggled (C++ mode only): start burst polling
            burstPollCount = 0
            tempPollCount = maxTempPolls  ; Stop any temp polling
            RegisterForSingleUpdate(0.1)
            
        ElseIf bUseHotkeyMode && bShowRecordingIndicator && IsRecordingHotkey(keyCode)
            ; Track which key is pressed
            If keyCode == recordSpeechHotkey
                recordSpeechPressed = True
            ElseIf keyCode == toggleOpenMicHotkey
                toggleOpenMicPressed = True
            ElseIf keyCode == voiceThoughtHotkey
                voiceThoughtPressed = True
            ElseIf keyCode == voiceDialogueTransformHotkey
                voiceDialoguePressed = True
            ElseIf keyCode == voiceDirectInputHotkey
                voiceDirectInputPressed = True
            EndIf
            
            ; Recording hotkey: start burst polling to catch recording state
            ; API may take a moment to register the recording
            burstPollCount = 0
            tempPollCount = maxTempPolls  ; Stop any temp polling
            RegisterForSingleUpdate(0.1)
        EndIf
    EndIf
EndEvent

; Handles hotkey release for push-to-talk recording hotkeys
; Only active in hotkey mode
Event OnKeyUp(Int keyCode, Float holdTime)
    If !Utility.IsInMenuMode() && bUseHotkeyMode && bShowRecordingIndicator
        If IsRecordingHotkey(keyCode)
            ; Clear pressed state
            If keyCode == recordSpeechHotkey
                recordSpeechPressed = False
            ElseIf keyCode == toggleOpenMicHotkey
                toggleOpenMicPressed = False
            ElseIf keyCode == voiceThoughtHotkey
                voiceThoughtPressed = False
            ElseIf keyCode == voiceDialogueTransformHotkey
                voiceDialoguePressed = False
            ElseIf keyCode == voiceDirectInputHotkey
                voiceDirectInputPressed = False
            EndIf
            
            ; Recording hotkey released: start burst polling to catch state change
            burstPollCount = 0
            tempPollCount = maxTempPolls  ; Stop any temp polling
            RegisterForSingleUpdate(0.1)
        EndIf
    EndIf
EndEvent

; Checks if a key code is one of the recording hotkeys
Bool Function IsRecordingHotkey(Int keyCode)
    Return keyCode == recordSpeechHotkey || keyCode == toggleOpenMicHotkey || \
           keyCode == voiceThoughtHotkey || keyCode == voiceDialogueTransformHotkey || \
           keyCode == voiceDirectInputHotkey
EndFunction

; Called when a menu closes
; Catches edge cases where hotkey was typed in text fields (OnKeyDown doesn't fire)
Event OnMenuClose(String menuName)
    ; Force sync check to catch any state changes that happened in menu
    ; This is event-driven (not polling) and only fires when menus close
    If Ready
        UpdateStatus(true)
    EndIf
EndEvent

; Periodic update event for polling mode
; Checks both whisper and recording state
; Only active when ShowRecordingIndicator is enabled AND in polling mode
; Also runs temporarily after reload in hotkey mode to catch push-to-talk state
; Also runs burst polling after whisper hotkey press
Event OnUpdate()
    ; Priority 1: Burst polling after whisper hotkey press
    If burstPollCount < maxBurstPolls
        UpdateStatus()  ; Check both whisper AND recording state
        burstPollCount += 1
        If burstPollCount < maxBurstPolls
            RegisterForSingleUpdate(0.1)  ; Quick 0.1s interval for burst
        EndIf
        Return
    EndIf
    
    ; Priority 2: Normal polling or temp post-reload polling
    If !bUseHotkeyMode
        ; Polling mode: continuous updates
        ; Force update on first few polls after reset to handle SkyrimNet initialization delay
        Bool forceFirst = (tempPollCount < 3)
        UpdateStatus(forceFirst)
        If tempPollCount < 10
            tempPollCount += 1
        EndIf
        RegisterForSingleUpdate(fPollInterval)
    Else
        ; Hotkey mode: temporary post-reload polling only
        ; Keep polling until BOTH poll count reached AND widget is Ready
        ; This prevents stopping temp polling before SWF has finished loading
        ; But timeout after 1 minute to prevent infinite polling
        If (tempPollCount < maxTempPolls || !Ready) && tempPollCount < maxTimeoutPolls
            UpdateStatus()
            tempPollCount += 1
            RegisterForSingleUpdate(fTempPollInterval)
            
            ; Log if we're extending polling due to Ready=False
            If tempPollCount >= maxTempPolls && !Ready
                Debug.Trace("[SNSWhisperWidget] Extending temp polling, Ready=False (poll " + tempPollCount + ")")
            EndIf
        Else
            ; Check if we timed out
            If !Ready && tempPollCount >= maxTimeoutPolls
                Debug.Trace("[SNSWhisperWidget] ERROR: Temp polling timed out after " + tempPollCount + " polls, Ready=False!")
                tempPollingTimedOut = True
            Else
                ; Temp polling complete
                Debug.Trace("[SNSWhisperWidget] Temp polling complete after " + tempPollCount + " polls, Ready=True")
            EndIf
        EndIf
        ; After temp polls complete, stop all polling - everything is hotkey-driven
    EndIf
EndEvent

;===========================================
; STATE UPDATE FUNCTIONS
;===========================================

; Lightweight check for global AI state
; Used in hotkey mode to ensure widget hides when SkyrimNet is disabled
; without the overhead of full state polling
Function CheckGlobalAIState()
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    
    If !isGlobalAIEnabled
        ; Global AI disabled - hide widget
        If Ready
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", false)
        EndIf
    Else
        ; Global AI enabled - do full update to restore state
        UpdateStatus(true)
    EndIf
EndFunction

; Full status update - checks both whisper mode AND recording state
; Called on game load and when settings change
; More expensive than UpdateWhisperMode() due to checking both states
Function UpdateStatus(Bool forceUpdate = false)
    ; Check if SkyrimNet global AI is enabled
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    
    ; Query current states from SkyrimNet
    Bool isWhisperOn = IsWhisperModeEnabled()
    Bool isRecording = False
    
    ; Check recording if feature is enabled OR if forcing update
    If bShowRecordingIndicator || forceUpdate
        isRecording = SkyrimNetApi.IsRecordingInput()
    EndIf
    
    ; Calculate visibility: start with base visibility, apply global AI and auto-hide logic
    Bool shouldBeVisible = widgetVisible && isGlobalAIEnabled
    If shouldBeVisible && bHideWhenInactive
        If bShowRecordingIndicator
            ; Consider both whisper and recording for auto-hide
            If !isWhisperOn && !isRecording
                shouldBeVisible = false
            EndIf
        Else
            ; Only consider whisper for auto-hide
            If !isWhisperOn
                shouldBeVisible = false
            EndIf
        EndIf
    EndIf
    
    ; When forcing update, skip change detection entirely
    If forceUpdate
        lastGlobalAIState = isGlobalAIEnabled
        ; Always update UI to match actual state
        ; Only show recording if the feature is enabled
        Bool showRecording = isRecording && bShowRecordingIndicator
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setWhisperMode", isWhisperOn)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setRecording", showRecording)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        
        ; Update cached states
        lastWhisperState = isWhisperOn
        lastRecordingState = isRecording
        Return
    EndIf
    
    ; Normal operation: detect state changes
    Bool globalAIChanged = (isGlobalAIEnabled != lastGlobalAIState)
    lastGlobalAIState = isGlobalAIEnabled
    
    Bool stateChanged = globalAIChanged || (isWhisperOn != lastWhisperState || isRecording != lastRecordingState)
    Bool becomingVisible = (!lastWhisperState && !lastRecordingState) && (isWhisperOn || isRecording)
    
    ; Update UI only if state changed or becoming visible
    If stateChanged || becomingVisible
        If (Ready)
            ; Send updates to Flash widget
            ; Only show recording if the feature is enabled
            Bool showRecording = isRecording && bShowRecordingIndicator
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setWhisperMode", isWhisperOn)
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setRecording", showRecording)
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
            
            ; Only update cached states if UI update succeeded
            lastWhisperState = isWhisperOn
            lastRecordingState = isRecording
        EndIf
    EndIf
EndFunction

; Fast update for hotkey press - only checks whisper mode
; Skips recording check for instant response
; Called from OnKeyDown event handler
Function UpdateWhisperMode()
    ; Early exit if global AI is disabled
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    If !isGlobalAIEnabled
        Return
    EndIf
    
    Bool isWhisperOn = IsWhisperModeEnabled()
    
    ; Update only if whisper state changed
    If isWhisperOn != lastWhisperState
        lastWhisperState = isWhisperOn
        
        If (Ready)
            ; Update whisper mode icon
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setWhisperMode", isWhisperOn)
            
            ; Apply auto-hide logic if enabled
            Bool shouldBeVisible = widgetVisible
            If bHideWhenInactive && !isWhisperOn && !lastRecordingState
                shouldBeVisible = false
            EndIf
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        EndIf
    EndIf
EndFunction

; Update recording state only
; Called from hotkey events (in hotkey mode) or OnUpdate (in polling mode)
Function UpdateRecordingState()
    ; Early exit if feature disabled
    If !bShowRecordingIndicator
        Return
    EndIf
    
    ; Early exit if global AI is disabled
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    If !isGlobalAIEnabled
        Return
    EndIf
    
    ; Check if currently recording
    Bool isRecording = SkyrimNetApi.IsRecordingInput()
    
    ; Update only if recording state changed
    If isRecording != lastRecordingState
        lastRecordingState = isRecording
        
        If (Ready)
            ; Update recording indicator
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setRecording", isRecording)
            
            ; Apply auto-hide logic if enabled
            Bool shouldBeVisible = widgetVisible
            If bHideWhenInactive && !lastWhisperState && !isRecording
                shouldBeVisible = false
            EndIf
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        EndIf
    EndIf
EndFunction

;===========================================
; STATE DETECTION
;===========================================

; Determines if whisper mode is currently active
; Whisper mode is ON when distance is at or below whisper threshold
; Returns: True if whisper mode is enabled, False otherwise
Bool Function IsWhisperModeEnabled()
    ; Query SkyrimNet config for distance values
    Float currentDistance = SkyrimNetApi.GetConfigFloat("game", "interaction.maxDistance", 1000.0)
    Float whisperDistance = SkyrimNetApi.GetConfigFloat("game", "interaction.whisperMaxDistance", 200.0)
        
    ; If current distance is at or below whisper threshold, it's whisper mode
    ; Any distance above whisper threshold is considered normal mode
    Bool isWhisper = (currentDistance <= whisperDistance)
    Return isWhisper
EndFunction

;===========================================
; WIDGET INTERFACE (required by SKI_WidgetBase)
;===========================================

; Returns the filename of the Flash widget SWF
String Function GetWidgetSource()
    Return "SNSWidget.swf"
EndFunction

; Returns the ActionScript class path for the widget
String Function GetWidgetType()
    Return "pnx.widgets.SNSWidget"
EndFunction
