Scriptname SNSGMWidget extends SKI_WidgetBase

;===========================================
; SkyrimNet Game Master & Continuous Mode Widget
; Displays GM agent on/off state and continuous mode indicator
;===========================================

;===========================================
; PROPERTIES
;===========================================

; Quest containing skynet_Library script for Papyrus hotkey support
Quest Property SkyrimNetLibraryQuest Auto

;===========================================
; STATE TRACKING
;===========================================

; Previous state values to prevent redundant UI updates
Bool lastGMState = False           ; Last known GM agent enabled state
Bool lastContinuousState = False   ; Last known continuous mode state
Bool lastGlobalAIState = True      ; Last known global AI state

; Hotkey management
Int gmHotkey = -1                  ; Toggle GM mode hotkey
Int continuousHotkey = -1          ; Toggle continuous mode hotkey
Int globalAIHotkey = -1            ; Global AI toggle hotkey (C++ mode only, -1 = none)
Bool usePapyrusHotkeys = False     ; True = Papyrus hotkeys, False = C++ hotkeys

; Burst polling when hotkey pressed
Int burstPollCount = 0             ; Counter for burst polls after key press
Int maxBurstPolls = 4              ; Poll 4 times at 0.1s intervals (covers 0.4s window)

; Temporary polling after reset
Int tempPollCount = 0               ; Counter for temporary polls after reset
Int maxTempPolls = 6                ; Poll 6 times (18 seconds at 3s interval) after reset
Int maxTimeoutPolls = 20            ; Maximum 20 polls (60 seconds at 3s) before timeout
Bool tempPollingTimedOut = False    ; Flag if temp polling exceeded timeout
Float fTempPollInterval = 3.0       ; Temp polling interval (3 seconds to reduce init load)

;===========================================
; SETTINGS (configurable via MCM)
;===========================================

Bool widgetVisible = True          ; Master visibility toggle
Int widgetSize = 100               ; Scale percentage (50-200, default 100)
Int widgetOpacity = 100            ; Opacity percentage (0-100, default 100)
Bool bShowContinuousIndicator = True  ; Enable continuous mode indicator
Bool bHideWhenInactive = False     ; Auto-hide when GM OFF and continuous OFF
Bool bOnlyShowWhenContinuous = False  ; Only show widget when continuous mode is ON (requires GM)
Bool bUseHotkeyMode = True         ; Update mode: False = polling, True = hotkey only (DEFAULT)
Float fPollInterval = 0.5          ; Polling interval (seconds)

; Master visibility toggle property
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
Int Property Size
    Int Function Get()
        Return widgetSize
    EndFunction
    
    Function Set(Int a_val)
        widgetSize = a_val
        If (Ready)
            UI.SetFloat(HUD_MENU, WidgetRoot + "._xscale", widgetSize as Float)
            UI.SetFloat(HUD_MENU, WidgetRoot + "._yscale", widgetSize as Float)
        EndIf
    EndFunction
EndProperty

; Widget opacity property
Int Property Opacity
    Int Function Get()
        Return widgetOpacity
    EndFunction
    
    Function Set(Int a_val)
        widgetOpacity = a_val
        If (Ready)
            UI.SetInt(HUD_MENU, WidgetRoot + "._alpha", widgetOpacity)
        EndIf
    EndFunction
EndProperty

; Continuous mode indicator toggle
Bool Property ShowContinuousIndicator
    Bool Function Get()
        Return bShowContinuousIndicator
    EndFunction
    
    Function Set(Bool a_val)
        bShowContinuousIndicator = a_val
        If (Ready)
            UpdateStatus()
        EndIf
    EndFunction
EndProperty

; Auto-hide when inactive toggle
Bool Property HideWhenInactive
    Bool Function Get()
        Return bHideWhenInactive
    EndFunction
    
    Function Set(Bool a_val)
        bHideWhenInactive = a_val
        If (Ready)
            UpdateStatus()
        EndIf
    EndFunction
EndProperty

; Only show when continuous mode enabled toggle
Bool Property OnlyShowWhenContinuous
    Bool Function Get()
        Return bOnlyShowWhenContinuous
    EndFunction
    
    Function Set(Bool a_val)
        bOnlyShowWhenContinuous = a_val
        If (Ready)
            UpdateStatus()
        EndIf
    EndFunction
EndProperty

; Update mode toggle (polling vs hotkey-only)
Bool Property UseHotkeyMode
    Bool Function Get()
        Return bUseHotkeyMode
    EndFunction
    
    Function Set(Bool a_val)
        bUseHotkeyMode = a_val
        If (Ready)
            UnregisterForUpdate()
            If !bUseHotkeyMode
                ; Switching to polling mode - start polling
                RegisterForSingleUpdate(fPollInterval)
            Else
                ; Switching to hotkey mode - start background global AI checks
                RegisterForSingleUpdate(fPollInterval)
            EndIf
        EndIf
    EndFunction
EndProperty

; Polling interval property
Float Property PollInterval
    Float Function Get()
        Return fPollInterval
    EndFunction
    
    Function Set(Float a_val)
        fPollInterval = a_val
        If (Ready)
            UnregisterForUpdate()
            RegisterForSingleUpdate(fPollInterval)
        EndIf
    EndFunction
EndProperty

;===========================================
; INITIALIZATION EVENTS
;===========================================

Event OnInit()
    Debug.Trace("[SNSGMWidget] OnInit() called")
    
    ; Set default position BEFORE calling Parent.OnInit()
    ; This ensures correct position on first load (Bottom Right, above whisper widget)
    X = 1272.0          ; Horizontal position
    Y = 686.0           ; Vertical position (30px above whisper widget's default Y=716)
    HAnchor = "right"   ; Anchor to right edge
    VAnchor = "bottom"  ; Anchor to bottom edge
    
    Debug.Trace("[SNSGMWidget] Calling Parent.OnInit()")
    Parent.OnInit()
    Debug.Trace("[SNSGMWidget] OnInit() complete, Ready=" + Ready)
EndEvent

; Called when player loads a save game
Event OnGameReload()
    Debug.Trace("[SNSGMWidget] OnGameReload() called, Ready=" + Ready)
    
    Parent.OnGameReload()
    
    Debug.Trace("[SNSGMWidget] OnGameReload() complete, Ready=" + Ready)
    
    ; Detect and register GM mode hotkeys
    LoadHotkeysFromConfig()
EndEvent

; Override to set custom modes before parent calls UpdateWidgetModes()
Event OnWidgetLoad()
    Debug.Trace("[SNSGMWidget] OnWidgetLoad() called, Ready=" + Ready)
    
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
        
    ; Now let parent handle the rest
    Parent.OnWidgetLoad()
    Debug.Trace("[SNSGMWidget] OnWidgetLoad() complete, Ready=" + Ready)
EndEvent

; Called when widget is reset (UI reload, etc.)
Event OnWidgetReset()
    Debug.Trace("[SNSGMWidget] OnWidgetReset() called, Ready=" + Ready)
    
    ; Reset temp polling counter (but NOT burstPollCount - that's only for hotkeys)
    tempPollCount = 0
    
    ; Load hotkeys (in case OnGameReload didn't fire)
    LoadHotkeysFromConfig()
    
    Parent.OnWidgetReset()
        
    ; Apply saved settings to the Flash widget
    If (Ready)
        Debug.Trace("[SNSGMWidget] Applying widget settings")
        ; Apply visual settings
        UI.SetFloat(HUD_MENU, WidgetRoot + "._xscale", widgetSize as Float)
        UI.SetFloat(HUD_MENU, WidgetRoot + "._yscale", widgetSize as Float)
        UI.SetInt(HUD_MENU, WidgetRoot + "._alpha", widgetOpacity)
        
        ; Set initial visibility (UpdateStatus will apply global AI and hide-when-inactive logic)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", widgetVisible)
        Debug.Trace("[SNSGMWidget] Initial visibility set to: " + widgetVisible)
        
        ; Restore last known icon states to prevent flash of default OFF state
        ; Cached states are usually correct (persisted from before reload)
        ; Forced updates will correct them within 1-2 seconds if SkyrimNet state changed
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setGMMode", lastGMState)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", lastContinuousState)
        Debug.Trace("[SNSGMWidget] Restored cached states - GM:" + lastGMState + " Continuous:" + lastContinuousState)
    Else
        Debug.Trace("[SNSGMWidget] WARNING: Ready=False in OnWidgetReset!")
    EndIf
    
    ; Listen for load screen closing to refresh state after load
    RegisterForMenu("LoadingMenu")
    
    ; Always start initial polling after reset to establish state
    ; In hotkey mode, this will poll a few times then stop
    ; In polling mode, this will poll continuously
    If bUseHotkeyMode
        tempPollCount = 0  ; Reset temp poll counter
    EndIf
    RegisterForSingleUpdate(fTempPollInterval)
EndEvent

;===========================================
; WIDGET SOURCE
;===========================================

; Returns the path to the widget SWF file
String Function GetWidgetSource()
    Return "SNSGMWidget.swf"
EndFunction

; Returns the widget type identifier
String Function GetWidgetType()
    Return "pnx.widgets.GMWidget"
EndFunction

;===========================================
; EVENT HANDLERS
;===========================================

; Handles hotkey presses for GM and continuous mode toggles
Event OnKeyDown(Int keyCode)
    If !Utility.IsInMenuMode()
        If keyCode == gmHotkey
            ; GM hotkey: start burst polling
            burstPollCount = 0
            RegisterForSingleUpdate(0.1)
        ElseIf keyCode == continuousHotkey
            ; Continuous hotkey: start burst polling
            burstPollCount = 0
            RegisterForSingleUpdate(0.1)
        ElseIf keyCode == globalAIHotkey && globalAIHotkey != -1
            ; Global AI hotkey: start burst polling
            burstPollCount = 0
            RegisterForSingleUpdate(0.1)
        EndIf
    EndIf
EndEvent

; Periodic update event - polls GM and continuous mode state
Event OnUpdate()
    Debug.Trace("[SNSGMWidget] OnUpdate() called - burstPollCount=" + burstPollCount + ", tempPollCount=" + tempPollCount + ", bUseHotkeyMode=" + bUseHotkeyMode)
    ; Priority 1: Burst polling after hotkey press
    If burstPollCount < maxBurstPolls
        UpdateStatus()  ; Check all states
        burstPollCount += 1
        If burstPollCount < maxBurstPolls
            RegisterForSingleUpdate(0.1)  ; Quick 0.1s interval for burst
        EndIf
        Return
    EndIf
    
    ; Reset burst counter so it doesn't interfere with other polling modes
    If burstPollCount >= maxBurstPolls
        burstPollCount = maxBurstPolls  ; Keep at max to prevent overflow
    EndIf
    
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
        ; Hotkey mode: temporary post-reset polling only
        ; Keep polling until BOTH poll count reached AND widget is Ready
        ; This prevents stopping temp polling before SWF has finished loading
        ; But timeout after 1 minute to prevent infinite polling
        If (tempPollCount < maxTempPolls || !Ready) && tempPollCount < maxTimeoutPolls
            ; Force update on first poll to ensure UI matches state even if no change detected
            Bool forceFirst = (tempPollCount == 0)
            Debug.Trace("[SNSGMWidget] Temp poll #" + tempPollCount + ", forceFirst=" + forceFirst + ", Ready=" + Ready)
            UpdateStatus(forceFirst)
            tempPollCount += 1
            RegisterForSingleUpdate(fTempPollInterval)
            
            ; Log if we're extending polling due to Ready=False
            If tempPollCount >= maxTempPolls && !Ready
                Debug.Trace("[SNSGMWidget] Extending temp polling, Ready=False (poll " + tempPollCount + ")")
            EndIf
        Else
            ; Check if we timed out
            If !Ready && tempPollCount >= maxTimeoutPolls
                Debug.Trace("[SNSGMWidget] ERROR: Temp polling timed out after " + tempPollCount + " polls, Ready=False!")
                tempPollingTimedOut = True
            Else
                ; Temp polling complete
                Debug.Trace("[SNSGMWidget] Temp polling complete after " + tempPollCount + " polls, Ready=True")
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

; Full status update - checks both GM mode AND continuous mode state
Function UpdateStatus(Bool forceUpdate = false)
    ; Check if SkyrimNet global AI is enabled
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    
    ; Query current states from SkyrimNet
    Bool isGMEnabled = IsGMAgentEnabled()
    Bool isContinuous = False
        
    ; Check continuous mode if feature is enabled OR if forcing update
    ; Continuous mode indicator only makes sense when GameMaster is enabled
    If (bShowContinuousIndicator || forceUpdate) && isGMEnabled
        isContinuous = IsContinuousModeEnabled()
    EndIf
    
    ; Calculate visibility: start with base visibility, apply global AI and auto-hide logic
    Bool shouldBeVisible = widgetVisible && isGlobalAIEnabled
    If shouldBeVisible && bOnlyShowWhenContinuous
        ; Only show when both GM and continuous are enabled
        If !isGMEnabled || !isContinuous
            shouldBeVisible = false
        EndIf
    ElseIf shouldBeVisible && bHideWhenInactive
        ; Hide if GameMaster is disabled
        If !isGMEnabled
            shouldBeVisible = false
        EndIf
    EndIf
    
    ; When forcing update, skip change detection entirely
    If forceUpdate
        Debug.Trace("[SNSGMWidget] Force update - GM:" + isGMEnabled + " Continuous:" + isContinuous + " Visible:" + shouldBeVisible + " Ready:" + Ready)
        lastGlobalAIState = isGlobalAIEnabled
        ; Always update UI to match actual state
        Debug.Trace("[SNSGMWidget] Setting GM icon to: " + isGMEnabled)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setGMMode", isGMEnabled)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", isContinuous)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        
        ; Update cached states
        lastGMState = isGMEnabled
        lastContinuousState = isContinuous
        Return
    EndIf
    
    ; Normal operation: detect state changes
    Bool globalAIChanged = (isGlobalAIEnabled != lastGlobalAIState)
    lastGlobalAIState = isGlobalAIEnabled
    
    Bool stateChanged = globalAIChanged || (isGMEnabled != lastGMState || isContinuous != lastContinuousState)
    
    ; Only update UI if state actually changed
    If stateChanged && Ready
        Debug.Trace("[SNSGMWidget] State changed - Setting GM icon to: " + isGMEnabled + " (was: " + lastGMState + ")")
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setGMMode", isGMEnabled)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", isContinuous)
        UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        
        ; Update cached states
        lastGMState = isGMEnabled
        lastContinuousState = isContinuous
    EndIf
EndFunction

; Fast update for GM hotkey press - only checks GM mode
; Skips continuous mode check for instant response
Function UpdateGMMode()
    ; Early exit if global AI is disabled
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    If !isGlobalAIEnabled
        Return
    EndIf
    
    Bool isGMEnabled = IsGMAgentEnabled()
    
    ; Update only if GM state changed
    If isGMEnabled != lastGMState
        lastGMState = isGMEnabled
        
        ; Check continuous mode since it depends on GM state
        Bool isContinuous = False
        If isGMEnabled && bShowContinuousIndicator
            isContinuous = IsContinuousModeEnabled()
            lastContinuousState = isContinuous
        Else
            ; GM disabled means continuous indicator should be off
            lastContinuousState = False
        EndIf
        
        If (Ready)
            ; Update both GM and continuous indicators together
            Debug.Trace("[SNSGMWidget] UpdateGMMode - Setting GM icon to: " + isGMEnabled)
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setGMMode", isGMEnabled)
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", isContinuous)
            
            ; Apply auto-hide logic if enabled
            Bool shouldBeVisible = widgetVisible
            If bOnlyShowWhenContinuous
                ; Only show when both GM and continuous are enabled
                If !isGMEnabled || !isContinuous
                    shouldBeVisible = false
                EndIf
            ElseIf bHideWhenInactive && !isGMEnabled
                shouldBeVisible = false
            EndIf
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        EndIf
    EndIf
EndFunction

; Fast update for continuous mode hotkey press - checks continuous mode
; Also verifies GM is enabled since continuous requires GM
Function UpdateContinuousMode()
    ; Early exit if feature disabled
    If !bShowContinuousIndicator
        Return
    EndIf
    
    ; Early exit if global AI is disabled
    Bool isGlobalAIEnabled = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
    If !isGlobalAIEnabled
        Return
    EndIf
    
    ; Check GM state - continuous only makes sense when GM is enabled
    Bool isGMEnabled = IsGMAgentEnabled()
    Bool isContinuous = False
    If isGMEnabled
        isContinuous = IsContinuousModeEnabled()
    EndIf
    
    ; Update only if continuous state changed
    If isContinuous != lastContinuousState
        lastContinuousState = isContinuous
        
        If (Ready)
            ; Update continuous indicator
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setContinuous", isContinuous)
            
            ; Apply auto-hide logic if enabled
            Bool shouldBeVisible = widgetVisible
            If bOnlyShowWhenContinuous
                ; Only show when both GM and continuous are enabled
                If !isGMEnabled || !isContinuous
                    shouldBeVisible = false
                EndIf
            ElseIf bHideWhenInactive && !isGMEnabled
                shouldBeVisible = false
            EndIf
            UI.InvokeBool(HUD_MENU, WidgetRoot + ".setVisible", shouldBeVisible)
        EndIf
    EndIf
EndFunction

;===========================================
; STATE DETECTION
;===========================================

; Checks if Game Master agent is currently enabled
; Returns true if GM mode is active
Bool Function IsGMAgentEnabled()
    ; Check config value for GM agent enabled state
    ; Config: SkyrimNet.yaml - gamemaster.agentEnabled (boolean)
    Bool gmEnabled = SkyrimNetApi.GetConfigBool("game", "gamemaster.agentEnabled", False)
    Return gmEnabled
EndFunction

; Checks if Continuous mode is currently enabled
; Returns true if continuous mode is active
; Checks if continuous scene mode is currently enabled
Bool Function IsContinuousModeEnabled()
    Return SkyrimNetApi.IsContinuousModeEnabled()
EndFunction

;===========================================
; HOTKEY MANAGEMENT
;===========================================

; Loads hotkeys from SkyrimNet config and registers them
Function LoadHotkeysFromConfig()
    ; Determine which hotkey system SkyrimNet is using
    usePapyrusHotkeys = !SkyrimNetApi.IsCppHotkeysEnabled()
    
    ; Arrays to store new hotkeys
    Int newGMHotkey = -1
    Int newContinuousHotkey = -1
    Int newGlobalAIHotkey = -1
    
    If usePapyrusHotkeys
        ; Papyrus system: Read hotkeys directly from quest properties
        ; Note: Global AI toggle hotkey doesn't exist in Papyrus, so we skip it
        If SkyrimNetLibraryQuest
            skynet_Library libraryScript = SkyrimNetLibraryQuest as skynet_Library
            If libraryScript
                newGMHotkey = libraryScript.hotkeyToggleGameMaster
                newContinuousHotkey = libraryScript.hotkeyToggleContinuousMode
            EndIf
        EndIf
    Else
        ; C++ system: Read VK codes from config and convert
        newGMHotkey = ConvertVKToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "toggleGameMaster", -1))
        newContinuousHotkey = ConvertVKToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "toggleContinuousMode", -1))
        newGlobalAIHotkey = ConvertVKToSkyrim(SkyrimNetApi.GetConfigInt("hotkey", "toggleGlobalAI", -1))
    EndIf
    
    ; Unregister old hotkeys
    If gmHotkey != -1
        UnregisterForKey(gmHotkey)
    EndIf
    If continuousHotkey != -1
        UnregisterForKey(continuousHotkey)
    EndIf
    If globalAIHotkey != -1
        UnregisterForKey(globalAIHotkey)
    EndIf
    
    ; Register new hotkeys
    gmHotkey = newGMHotkey
    continuousHotkey = newContinuousHotkey
    globalAIHotkey = newGlobalAIHotkey
    
    If gmHotkey != -1
        RegisterForKey(gmHotkey)
    EndIf
    If continuousHotkey != -1
        RegisterForKey(continuousHotkey)
    EndIf
    If globalAIHotkey != -1
        RegisterForKey(globalAIHotkey)
    EndIf
EndFunction

; Converts Windows Virtual Key codes to Skyrim DirectInput scan codes
; Matches the whisper widget's conversion function
; Returns: Skyrim key code, or -1 if unsupported
Int Function ConvertVKToSkyrim(Int vkCode)
    ; Common number keys 0-9
    If vkCode == 48
        Return 11  ; 0
    ElseIf vkCode >= 49 && vkCode <= 57
        Return vkCode - 48 + 2  ; 1-9 mapped to 2-10
    EndIf
    
    ; Letters A-Z (VK 0x41-0x5A / 65-90)
    If vkCode >= 65 && vkCode <= 90
        Return vkCode - 65 + 30  ; A=30, B=48, etc.
    EndIf
    
    ; Function keys F1-F12
    If vkCode >= 112 && vkCode <= 123
        Return vkCode - 112 + 59  ; F1=59, F12=88
    EndIf
    
    ; Common special keys
    If vkCode == 32  ; Space
        Return 57
    ElseIf vkCode == 13  ; Enter
        Return 28
    ElseIf vkCode == 9   ; Tab
        Return 15
    ElseIf vkCode == 16  ; Shift
        Return 42
    ElseIf vkCode == 17  ; Ctrl
        Return 29
    ElseIf vkCode == 18  ; Alt
        Return 56
    EndIf
    
    ; Unsupported or invalid
    Return -1
EndFunction
