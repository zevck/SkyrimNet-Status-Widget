Scriptname SNSWidgetMCM extends SKI_ConfigBase

;===========================================
; PROPERTIES
;===========================================

; Reference to the widget script for reading/writing settings
SNSWhisperWidget Property WidgetScript Auto
SNSGMWidget Property GMWidgetScript Auto

;===========================================
; MCM OPTION IDs
;===========================================

Int widgetVisibleOpt          ; Show/hide widget toggle
Int widgetPosXOpt             ; X position slider
Int widgetPosYOpt             ; Y position slider
Int widgetScaleOpt            ; Size/scale slider
Int widgetOpacityOpt          ; Opacity/alpha slider
Int widgetAnchorHOpt          ; Horizontal anchor menu
Int widgetAnchorVOpt          ; Vertical anchor menu
Int widgetPositionPresetOpt   ; Position preset menu
Int showRecordingOpt          ; Recording indicator toggle
Int hideWhenInactiveOpt       ; Auto-hide feature toggle
Int useHotkeyModeOpt          ; Update mode toggle
Int pollIntervalOpt           ; Polling interval slider
Int hideAllOpt                ; Hide all widgets toggle
Int refreshButtonOpt          ; Refresh widgets and hotkeys button

; GM Widget options
Int gmVisibleOpt              ; Show/hide GM widget toggle
Int gmPosXOpt                 ; X position slider
Int gmPosYOpt                 ; Y position slider
Int gmScaleOpt                ; Size/scale slider
Int gmOpacityOpt              ; Opacity/alpha slider
Int gmAnchorHOpt              ; Horizontal anchor menu
Int gmAnchorVOpt              ; Vertical anchor menu
Int gmPositionPresetOpt       ; Position preset menu
Int gmShowContinuousOpt       ; Continuous mode indicator toggle
Int gmHideWhenInactiveOpt     ; Auto-hide feature toggle
Int gmOnlyShowWhenContinuousOpt  ; Only show when continuous mode enabled
Int gmPollIntervalOpt         ; Polling interval slider
Int gmUseRelativePositionOpt  ; Relative positioning toggle
Int gmRelativeOffsetXOpt      ; Relative X offset slider
Int gmRelativeOffsetYOpt      ; Relative Y offset slider

;===========================================
; PRESET AND ANCHOR STRINGS
;===========================================

; Position preset display names
String[] positionPresetStrings

; Horizontal anchor display names (Left/Middle/Right)
String[] hAnchorStrings

; Vertical anchor display names (Top/Middle/Bottom)
String[] vAnchorStrings

; Relative positioning state for GM widget
Bool gmUseRelativePosition = True  ; Default to relative positioning
Float gmRelativeOffsetX = 0.0      ; X offset from whisper widget
Float gmRelativeOffsetY = -30.0    ; Y offset from whisper widget (30px above)

;===========================================
; INITIALIZATION
;===========================================

; Sets up mod name, pages, and string arrays for dropdowns
Event OnConfigInit()
    ModName = "SkyrimNet Status Widget"
    Pages = new String[3]
    Pages[0] = "Settings"
    Pages[1] = "Whisper Widget"
    Pages[2] = "GM Widget"
    
    ; Initialize position preset dropdown options
    ; Index 0 = User Defined (custom position)
    ; Index 1-9 = Nine preset positions (corners, edges, center)
    positionPresetStrings = new String[10]
    positionPresetStrings[0] = "User Defined"
    positionPresetStrings[1] = "Top Left"
    positionPresetStrings[2] = "Top Center"
    positionPresetStrings[3] = "Top Right"
    positionPresetStrings[4] = "Center Left"
    positionPresetStrings[5] = "Center"
    positionPresetStrings[6] = "Center Right"
    positionPresetStrings[7] = "Bottom Left"
    positionPresetStrings[8] = "Bottom Center"
    positionPresetStrings[9] = "Bottom Right"
    
    ; Initialize horizontal anchor dropdown
    hAnchorStrings = new String[3]
    hAnchorStrings[0] = "Left"      ; Anchor to left edge
    hAnchorStrings[1] = "Middle"    ; Anchor to center
    hAnchorStrings[2] = "Right"     ; Anchor to right edge
    
    ; Initialize vertical anchor dropdown
    vAnchorStrings = new String[3]
    vAnchorStrings[0] = "Top"       ; Anchor to top edge
    vAnchorStrings[1] = "Middle"    ; Anchor to center
    vAnchorStrings[2] = "Bottom"    ; Anchor to bottom edge
EndEvent

Event OnConfigOpen()
    Pages = new String[3]
    Pages[0] = "Settings"
    Pages[1] = "Whisper Widget"
    Pages[2] = "GM Widget"
EndEvent

;===========================================
; MCM PAGE BUILDING
;===========================================

; Creates all the UI elements (toggles, sliders, menus)
Event OnPageReset(String page)
    If (page == "Settings")
        ; Master settings page
        SetCursorFillMode(TOP_TO_BOTTOM)
        
        ;=== LEFT COLUMN ===
        SetCursorPosition(0)
        
        ; Widget visibility controls
        AddHeaderOption("Widget Visibility")
        Bool allVisible = WidgetScript.Visible && (!GMWidgetScript || GMWidgetScript.Visible)
        hideAllOpt = AddToggleOption("Hide All Widgets", !allVisible)
        
        AddEmptyOption()
        
        ; Global update settings
        AddHeaderOption("Update Mode")
        useHotkeyModeOpt = AddToggleOption("Use Hotkey Mode", WidgetScript.UseHotkeyMode)
        
        ; Poll interval - disabled when hotkey mode is active
        Int pollFlags = OPTION_FLAG_NONE
        If WidgetScript.UseHotkeyMode
            pollFlags = OPTION_FLAG_DISABLED
        EndIf
        pollIntervalOpt = AddSliderOption("Poll Interval", WidgetScript.PollInterval, "{1} sec", pollFlags)
        
        AddEmptyOption()
        
        ; Refresh control
        AddHeaderOption("Actions")
        refreshButtonOpt = AddTextOption("Refresh All", "")
    
        ;=== RIGHT COLUMN ===
        SetCursorPosition(1)
        
        ; Status information
        AddHeaderOption("Current Status")
        Bool isGlobalAI = SkyrimNetApi.GetConfigBool("game", "general.globalAIEnabled", True)
        String globalAIStatus = "OFF"
        If isGlobalAI
            globalAIStatus = "ON"
        EndIf
        AddTextOption("SkyrimNet Global AI", globalAIStatus, OPTION_FLAG_DISABLED)
        AddTextOption("Whisper Mode", GetWhisperStatus(), OPTION_FLAG_DISABLED)
        If GMWidgetScript
            AddTextOption("Game Master", GetGMStatus(), OPTION_FLAG_DISABLED)
            AddTextOption("Continuous Mode", GetContinuousStatus(), OPTION_FLAG_DISABLED)
        EndIf
        
    ElseIf (page == "Whisper Widget")
        ; Two-column layout: fill top to bottom
        SetCursorFillMode(TOP_TO_BOTTOM)
        
        ;=== LEFT COLUMN ===
        SetCursorPosition(0)
        
        ; Appearance settings section
        AddHeaderOption("Appearance")
        widgetVisibleOpt = AddToggleOption("Show Widget", WidgetScript.Visible)
        widgetScaleOpt = AddSliderOption("Widget Size", WidgetScript.Size, "{0}%")
        widgetOpacityOpt = AddSliderOption("Opacity", WidgetScript.Opacity, "{0}%")
        showRecordingOpt = AddToggleOption("Show Recording Indicator", WidgetScript.ShowRecordingIndicator)
        hideWhenInactiveOpt = AddToggleOption("Hide When Inactive", WidgetScript.HideWhenInactive)
        
        AddEmptyOption()
        
        ; Position settings section
        AddHeaderOption("Location")
        widgetPositionPresetOpt = AddMenuOption("Position Preset", GetCurrentPresetName())
        widgetPosXOpt = AddSliderOption("X Position", WidgetScript.X, "{0}")
        widgetPosYOpt = AddSliderOption("Y Position", WidgetScript.Y, "{0}")
        
        ;=== RIGHT COLUMN ===
        SetCursorPosition(1)
        
        ; Anchor settings section
        AddHeaderOption("Anchors")
        widgetAnchorHOpt = AddMenuOption("Horizontal Anchor", GetDisplayAnchor(WidgetScript.HAnchor, true))
        widgetAnchorVOpt = AddMenuOption("Vertical Anchor", GetDisplayAnchor(WidgetScript.VAnchor, false))
    
    ElseIf (page == "GM Widget")
        ; Check if GM widget script is available
        If !GMWidgetScript
            SetCursorFillMode(TOP_TO_BOTTOM)
            AddHeaderOption("Error")
            AddTextOption("GM Widget script not found!", "", OPTION_FLAG_DISABLED)
            AddTextOption("Ensure quest properties are set.", "", OPTION_FLAG_DISABLED)
            Return
        EndIf
        
        ; Two-column layout: fill top to bottom
        SetCursorFillMode(TOP_TO_BOTTOM)
        
        ;=== LEFT COLUMN ===
        SetCursorPosition(0)
        
        ; Appearance settings section
        AddHeaderOption("Appearance")
        gmVisibleOpt = AddToggleOption("Show Widget", GMWidgetScript.Visible)
        gmScaleOpt = AddSliderOption("Widget Size", GMWidgetScript.Size, "{0}%")
        gmOpacityOpt = AddSliderOption("Opacity", GMWidgetScript.Opacity, "{0}%")
        gmShowContinuousOpt = AddToggleOption("Show Continuous Mode Indicator", GMWidgetScript.ShowContinuousIndicator)
        gmHideWhenInactiveOpt = AddToggleOption("Hide When Inactive", GMWidgetScript.HideWhenInactive)
        gmOnlyShowWhenContinuousOpt = AddToggleOption("Only Show When Continuous", GMWidgetScript.OnlyShowWhenContinuous)
        
        AddEmptyOption()
        
        ; Position settings section
        AddHeaderOption("Location")
        
        ; Manual position controls - disabled when using relative positioning
        Int relativeFlags = OPTION_FLAG_NONE
        Int manualFlags = OPTION_FLAG_NONE
        If gmUseRelativePosition
            manualFlags = OPTION_FLAG_DISABLED
        Else
            relativeFlags = OPTION_FLAG_DISABLED
        EndIf
        
        gmPositionPresetOpt = AddMenuOption("Position Preset", GetGMCurrentPresetName(), manualFlags)
        gmPosXOpt = AddSliderOption("X Position", GMWidgetScript.X, "{0}", manualFlags)
        gmPosYOpt = AddSliderOption("Y Position", GMWidgetScript.Y, "{0}", manualFlags)
        
        ;=== RIGHT COLUMN ===
        SetCursorPosition(1)
        
        ; Anchor settings section - disabled when using relative positioning
        AddHeaderOption("Anchors")
        gmAnchorHOpt = AddMenuOption("Horizontal Anchor", GetDisplayAnchor(GMWidgetScript.HAnchor, true), manualFlags)
        gmAnchorVOpt = AddMenuOption("Vertical Anchor", GetDisplayAnchor(GMWidgetScript.VAnchor, false), manualFlags)
        
        AddEmptyOption()
        
        ; Relative positioning section
        AddHeaderOption("Relative Positioning")
        gmUseRelativePositionOpt = AddToggleOption("Relative to Whisper Widget", gmUseRelativePosition)
        gmRelativeOffsetXOpt = AddSliderOption("Relative X Offset", gmRelativeOffsetX, "{0}", relativeFlags)
        gmRelativeOffsetYOpt = AddSliderOption("Relative Y Offset", gmRelativeOffsetY, "{0}", relativeFlags)
    EndIf
EndEvent

;===========================================
; TOGGLE OPTION HANDLERS
;===========================================

; Toggles the boolean value and updates UI
Event OnOptionSelect(Int option)
    If (option == hideAllOpt)
        ; Toggle all widgets visibility
        Bool currentlyVisible = WidgetScript.Visible && (!GMWidgetScript || GMWidgetScript.Visible)
        Bool newVisibleState = !currentlyVisible  ; Flip visibility
        
        WidgetScript.Visible = newVisibleState
        If GMWidgetScript
            GMWidgetScript.Visible = newVisibleState
        EndIf
        
        ; Force widgets to update their visibility immediately
        WidgetScript.UpdateStatus(true)
        If GMWidgetScript
            GMWidgetScript.UpdateStatus(true)
        EndIf
        
        SetToggleOptionValue(hideAllOpt, !newVisibleState)  ; Toggle shows hide state
        
    ElseIf (option == widgetVisibleOpt)
        ; Toggle master visibility
        WidgetScript.Visible = !WidgetScript.Visible
        WidgetScript.UpdateStatus(true)
        SetToggleOptionValue(widgetVisibleOpt, WidgetScript.Visible)
        
    ElseIf (option == showRecordingOpt)
        ; Toggle recording indicator feature
        WidgetScript.ShowRecordingIndicator = !WidgetScript.ShowRecordingIndicator
        SetToggleOptionValue(showRecordingOpt, WidgetScript.ShowRecordingIndicator)
        
    ElseIf (option == hideWhenInactiveOpt)
        ; Toggle auto-hide feature
        WidgetScript.HideWhenInactive = !WidgetScript.HideWhenInactive
        SetToggleOptionValue(hideWhenInactiveOpt, WidgetScript.HideWhenInactive)
        WidgetScript.UpdateStatus(true)
        
    ElseIf (option == useHotkeyModeOpt)
        ; Toggle update mode
        WidgetScript.UseHotkeyMode = !WidgetScript.UseHotkeyMode
        SetToggleOptionValue(useHotkeyModeOpt, WidgetScript.UseHotkeyMode)
        
        ; Enable/disable poll interval slider based on new mode
        If WidgetScript.UseHotkeyMode
            SetOptionFlags(pollIntervalOpt, OPTION_FLAG_DISABLED)
        Else
            SetOptionFlags(pollIntervalOpt, OPTION_FLAG_NONE)
        EndIf
    
    ; GM Widget toggles
    ElseIf (option == gmVisibleOpt)
        GMWidgetScript.Visible = !GMWidgetScript.Visible
        GMWidgetScript.UpdateStatus(true)
        SetToggleOptionValue(gmVisibleOpt, GMWidgetScript.Visible)
        
    ElseIf (option == gmShowContinuousOpt)
        GMWidgetScript.ShowContinuousIndicator = !GMWidgetScript.ShowContinuousIndicator
        SetToggleOptionValue(gmShowContinuousOpt, GMWidgetScript.ShowContinuousIndicator)
        
    ElseIf (option == gmHideWhenInactiveOpt)
        GMWidgetScript.HideWhenInactive = !GMWidgetScript.HideWhenInactive
        SetToggleOptionValue(gmHideWhenInactiveOpt, GMWidgetScript.HideWhenInactive)
        GMWidgetScript.UpdateStatus(true)
        
    ElseIf (option == gmOnlyShowWhenContinuousOpt)
        GMWidgetScript.OnlyShowWhenContinuous = !GMWidgetScript.OnlyShowWhenContinuous
        SetToggleOptionValue(gmOnlyShowWhenContinuousOpt, GMWidgetScript.OnlyShowWhenContinuous)
        GMWidgetScript.UpdateStatus(true)
        
    ElseIf (option == gmUseRelativePositionOpt)
        gmUseRelativePosition = !gmUseRelativePosition
        SetToggleOptionValue(gmUseRelativePositionOpt, gmUseRelativePosition)
        
        ; Apply relative position if enabled
        If gmUseRelativePosition
            ApplyRelativePosition()
        EndIf
        
        ; Refresh page to update option flags
        ForcePageReset()
        
    ElseIf (option == refreshButtonOpt)
        ; Force update both widgets
        WidgetScript.UpdateStatus(true)
        If GMWidgetScript
            GMWidgetScript.UpdateStatus(true)
        EndIf
        
        ; Reload hotkeys
        WidgetScript.LoadHotkeyFromConfig()
        If WidgetScript.ShowRecordingIndicator && WidgetScript.UseHotkeyMode
            WidgetScript.LoadRecordingHotkeys()
        EndIf
        If GMWidgetScript
            GMWidgetScript.LoadHotkeysFromConfig()
        EndIf
        
        ; Show confirmation
        ShowMessage("Widgets and hotkeys refreshed.", false)
        ForcePageReset()
    EndIf
EndEvent

;===========================================
; SLIDER OPTION HANDLERS
;===========================================

; Sets up the slider's range, default, and starting value
Event OnOptionSliderOpen(Int option)
    If (option == widgetScaleOpt)
        ; Size slider: 50% to 200% in 5% increments
        SetSliderDialogStartValue(WidgetScript.Size)
        SetSliderDialogDefaultValue(100)
        SetSliderDialogRange(50, 200)
        SetSliderDialogInterval(5)
        
    ElseIf (option == widgetOpacityOpt)
        ; Opacity slider: 0% to 100% in 5% increments
        SetSliderDialogStartValue(WidgetScript.Opacity)
        SetSliderDialogDefaultValue(100)
        SetSliderDialogRange(0, 100)
        SetSliderDialogInterval(5)
        
    ElseIf (option == widgetPosXOpt)
        ; X position: 0 to 1280 (screen width at 720p)
        SetSliderDialogStartValue(WidgetScript.X)
        SetSliderDialogDefaultValue(1272.0)
        SetSliderDialogRange(0.0, 1280.0)
        SetSliderDialogInterval(1.0)
        
    ElseIf (option == widgetPosYOpt)
        ; Y position: 0 to 720 (screen height at 720p)
        SetSliderDialogStartValue(WidgetScript.Y)
        SetSliderDialogDefaultValue(716.0)
        SetSliderDialogRange(0.0, 720.0)
        SetSliderDialogInterval(1.0)
        
    ElseIf (option == pollIntervalOpt)
        ; Poll interval: 0.1 to 1.0 seconds
        SetSliderDialogStartValue(WidgetScript.PollInterval)
        SetSliderDialogDefaultValue(0.5)
        SetSliderDialogRange(0.1, 1.0)
        SetSliderDialogInterval(0.1)
    
    ; GM Widget sliders
    ElseIf (option == gmScaleOpt)
        SetSliderDialogStartValue(GMWidgetScript.Size)
        SetSliderDialogDefaultValue(100)
        SetSliderDialogRange(50, 200)
        SetSliderDialogInterval(5)
        
    ElseIf (option == gmOpacityOpt)
        SetSliderDialogStartValue(GMWidgetScript.Opacity)
        SetSliderDialogDefaultValue(100)
        SetSliderDialogRange(0, 100)
        SetSliderDialogInterval(5)
        
    ElseIf (option == gmPosXOpt)
        SetSliderDialogStartValue(GMWidgetScript.X)
        SetSliderDialogDefaultValue(1272.0)
        SetSliderDialogRange(0.0, 1280.0)
        SetSliderDialogInterval(1.0)
        
    ElseIf (option == gmPosYOpt)
        SetSliderDialogStartValue(GMWidgetScript.Y)
        SetSliderDialogDefaultValue(680.0)
        SetSliderDialogRange(0.0, 720.0)
        SetSliderDialogInterval(1.0)
        
    ElseIf (option == gmRelativeOffsetXOpt)
        SetSliderDialogStartValue(gmRelativeOffsetX)
        SetSliderDialogDefaultValue(0.0)
        SetSliderDialogRange(-500.0, 500.0)
        SetSliderDialogInterval(1.0)
        
    ElseIf (option == gmRelativeOffsetYOpt)
        SetSliderDialogStartValue(gmRelativeOffsetY)
        SetSliderDialogDefaultValue(-30.0)
        SetSliderDialogRange(-500.0, 500.0)
        SetSliderDialogInterval(1.0)
    EndIf
EndEvent

; Updates the widget property and MCM display
Event OnOptionSliderAccept(Int option, Float value)
    If (option == widgetScaleOpt)
        ; Update widget size
        WidgetScript.Size = value as Int
        SetSliderOptionValue(widgetScaleOpt, value, "{0}%")
        
    ElseIf (option == widgetOpacityOpt)
        ; Update widget opacity
        WidgetScript.Opacity = value as Int
        SetSliderOptionValue(widgetOpacityOpt, value, "{0}%")
        
    ElseIf (option == widgetPosXOpt)
        ; Update X position
        WidgetScript.X = value
        SetSliderOptionValue(widgetPosXOpt, value, "{0}")
        
    ElseIf (option == widgetPosYOpt)
        ; Update Y position
        WidgetScript.Y = value
        SetSliderOptionValue(widgetPosYOpt, value, "{0}")
        
    ElseIf (option == pollIntervalOpt)
        ; Update poll interval
        WidgetScript.PollInterval = value
        SetSliderOptionValue(pollIntervalOpt, value, "{1} sec")
    
    ; GM Widget sliders
    ElseIf (option == gmScaleOpt)
        GMWidgetScript.Size = value as Int
        SetSliderOptionValue(gmScaleOpt, value, "{0}%")
        
    ElseIf (option == gmOpacityOpt)
        GMWidgetScript.Opacity = value as Int
        SetSliderOptionValue(gmOpacityOpt, value, "{0}%")
        
    ElseIf (option == gmPosXOpt)
        GMWidgetScript.X = value
        SetSliderOptionValue(gmPosXOpt, value, "{0}")
        
    ElseIf (option == gmPosYOpt)
        GMWidgetScript.Y = value
        SetSliderOptionValue(gmPosYOpt, value, "{0}")
        
    ElseIf (option == pollIntervalOpt)
        ; Update both widgets with same poll interval
        WidgetScript.PollInterval = value
        If GMWidgetScript
            GMWidgetScript.PollInterval = value
        EndIf
        SetSliderOptionValue(pollIntervalOpt, value, "{1} sec")
        
    ElseIf (option == gmRelativeOffsetXOpt)
        gmRelativeOffsetX = value
        SetSliderOptionValue(gmRelativeOffsetXOpt, value, "{0}")
        ApplyRelativePosition()
        
    ElseIf (option == gmRelativeOffsetYOpt)
        gmRelativeOffsetY = value
        SetSliderOptionValue(gmRelativeOffsetYOpt, value, "{0}")
        ApplyRelativePosition()
    EndIf
EndEvent

;===========================================
; MENU OPTION HANDLERS
;===========================================

; Sets up the menu's available options and starting selection
Event OnOptionMenuOpen(Int option)
    If (option == widgetPositionPresetOpt)
        ; Position preset menu
        SetMenuDialogStartIndex(0)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(positionPresetStrings)
        
    ElseIf (option == widgetAnchorHOpt)
        ; Horizontal anchor menu (Left/Middle/Right)
        Int currentIndex = GetHAnchorIndex(WidgetScript.HAnchor)
        SetMenuDialogStartIndex(currentIndex)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(hAnchorStrings)
        
    ElseIf (option == widgetAnchorVOpt)
        ; Vertical anchor menu (Top/Middle/Bottom)
        Int currentIndex = GetVAnchorIndex(WidgetScript.VAnchor)
        SetMenuDialogStartIndex(currentIndex)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(vAnchorStrings)
    
    ; GM Widget menus
    ElseIf (option == gmPositionPresetOpt)
        SetMenuDialogStartIndex(0)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(positionPresetStrings)
        
    ElseIf (option == gmAnchorHOpt)
        Int currentIndex = GetHAnchorIndex(GMWidgetScript.HAnchor)
        SetMenuDialogStartIndex(currentIndex)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(hAnchorStrings)
        
    ElseIf (option == gmAnchorVOpt)
        Int currentIndex = GetVAnchorIndex(GMWidgetScript.VAnchor)
        SetMenuDialogStartIndex(currentIndex)
        SetMenuDialogDefaultIndex(0)
        SetMenuDialogOptions(vAnchorStrings)
    EndIf
EndEvent

; Updates the widget properties based on selection
Event OnOptionMenuAccept(Int option, Int index)
    If (option == widgetPositionPresetOpt)
        ; Apply selected position preset
        ApplyPositionPreset(index)
        SetMenuOptionValue(widgetPositionPresetOpt, positionPresetStrings[index])
        
        ; Update position sliders to show new values
        SetSliderOptionValue(widgetPosXOpt, WidgetScript.X, "{0}")
        SetSliderOptionValue(widgetPosYOpt, WidgetScript.Y, "{0}")
        
    ElseIf (option == widgetAnchorHOpt)
        ; Set horizontal anchor (convert display string to internal value)
        If index == 0
            WidgetScript.HAnchor = "left"
        ElseIf index == 1
            WidgetScript.HAnchor = "center"
        Else
            WidgetScript.HAnchor = "right"
        EndIf
        SetMenuOptionValue(widgetAnchorHOpt, hAnchorStrings[index])
        
    ElseIf (option == widgetAnchorVOpt)
        ; Set vertical anchor (convert display string to internal value)
        If index == 0
            WidgetScript.VAnchor = "top"
        ElseIf index == 1
            WidgetScript.VAnchor = "center"
        Else
            WidgetScript.VAnchor = "bottom"
        EndIf
        SetMenuOptionValue(widgetAnchorVOpt, vAnchorStrings[index])
    
    ; GM Widget menus
    ElseIf (option == gmPositionPresetOpt)
        ApplyGMPositionPreset(index)
        SetMenuOptionValue(gmPositionPresetOpt, positionPresetStrings[index])
        SetSliderOptionValue(gmPosXOpt, GMWidgetScript.X, "{0}")
        SetSliderOptionValue(gmPosYOpt, GMWidgetScript.Y, "{0}")
        
    ElseIf (option == gmAnchorHOpt)
        If index == 0
            GMWidgetScript.HAnchor = "left"
        ElseIf index == 1
            GMWidgetScript.HAnchor = "center"
        Else
            GMWidgetScript.HAnchor = "right"
        EndIf
        SetMenuOptionValue(gmAnchorHOpt, hAnchorStrings[index])
        
    ElseIf (option == gmAnchorVOpt)
        If index == 0
            GMWidgetScript.VAnchor = "top"
        ElseIf index == 1
            GMWidgetScript.VAnchor = "center"
        Else
            GMWidgetScript.VAnchor = "bottom"
        EndIf
        SetMenuOptionValue(gmAnchorVOpt, vAnchorStrings[index])
    EndIf
EndEvent

;===========================================
; HELP TEXT
;===========================================

; Shows descriptive text at bottom of MCM
Event OnOptionHighlight(Int option)
    If (option == widgetVisibleOpt)
        SetInfoText("Toggle the widget visibility on/off. Default: Enabled")
        
    ElseIf (option == widgetScaleOpt)
        SetInfoText("Adjust the size of the widget (50-200%). Default: 100")
        
    ElseIf (option == widgetOpacityOpt)
        SetInfoText("Adjust the opacity/transparency of the widget (0-100%). Default: 100")
        
    ElseIf (option == showRecordingOpt)
        SetInfoText("Show a visual indicator when recording input. Default: Enabled")
        
    ElseIf (option == hideWhenInactiveOpt)
        SetInfoText("Hide the widget when in default state (no whisper mode, no recording). Shows only when whisper mode is enabled. Default: Disabled")
        
    ElseIf (option == useHotkeyModeOpt)
        SetInfoText("Updates on keypress, disables polling. Reload or refresh is required after changing SkyrimNet keybinds. Default: Disabled")
        
    ElseIf (option == pollIntervalOpt)
        SetInfoText("How often to check for state changes in polling mode (0.1-1.0 seconds). Default: 0.5")
        
    ElseIf (option == widgetPositionPresetOpt)
        SetInfoText("Select a position preset or use User Defined for manual positioning")
        
    ElseIf (option == widgetPosXOpt)
        SetInfoText("Horizontal position (0-1280)")
        
    ElseIf (option == widgetPosYOpt)
        SetInfoText("Vertical position (0-720)")
        
    ElseIf (option == widgetAnchorHOpt)
        SetInfoText("Horizontal anchor point for the widget")
        
    ElseIf (option == widgetAnchorVOpt)
        SetInfoText("Vertical anchor point for the widget")
    
    ; GM Widget help text
    ElseIf (option == gmVisibleOpt)
        SetInfoText("Toggle the GM widget visibility on/off. Default: Enabled")
        
    ElseIf (option == gmScaleOpt)
        SetInfoText("Adjust the size of the GM widget (50-200%). Default: 100")
        
    ElseIf (option == gmOpacityOpt)
        SetInfoText("Adjust the opacity/transparency of the GM widget (0-100%). Default: 100")
        
    ElseIf (option == gmShowContinuousOpt)
        SetInfoText("Show a visual indicator when continuous mode is active. Default: Enabled")
        
    ElseIf (option == gmHideWhenInactiveOpt)
        SetInfoText("Hide the widget when game master is disabled. Default: Disabled")
        
    ElseIf (option == gmOnlyShowWhenContinuousOpt)
        SetInfoText("Only show widget when continuous mode and game master are enabled. Default: Disabled")
        
    ElseIf (option == gmUseRelativePositionOpt)
        SetInfoText("Position GM widget relative to whisper widget. When enabled, manual position controls are disabled. Default: Enabled")
        
    ElseIf (option == gmRelativeOffsetXOpt)
        SetInfoText("Horizontal offset from whisper widget (-500 to 500). Default: 0")
        
    ElseIf (option == gmRelativeOffsetYOpt)
        SetInfoText("Vertical offset from whisper widget (-500 to 500). Negative = above. Default: -30")
        
    ElseIf (option == gmPositionPresetOpt)
        SetInfoText("Select a position preset or use User Defined for manual positioning")
        
    ElseIf (option == gmPosXOpt)
        SetInfoText("Horizontal position (0-1280)")
        
    ElseIf (option == gmPosYOpt)
        SetInfoText("Vertical position (0-720)")
        
    ElseIf (option == gmAnchorHOpt)
        SetInfoText("Horizontal anchor point for the GM widget")
        
    ElseIf (option == gmAnchorVOpt)
        SetInfoText("Vertical anchor point for the GM widget")
    EndIf
EndEvent

; Returns the current whisper widget status for display
String Function GetWhisperStatus()
    If WidgetScript.IsWhisperModeEnabled()
        Return "ON"
    Else
        Return "OFF"
    EndIf
EndFunction

; Returns the current recording status for display
String Function GetRecordingStatus()
    If WidgetScript.ShowRecordingIndicator
        Return "ENABLED"
    Else
        Return "DISABLED"
    EndIf
EndFunction

; Returns the current GM widget status for display
String Function GetGMStatus()
    If GMWidgetScript.IsGMAgentEnabled()
        Return "ON"
    Else
        Return "OFF"
    EndIf
EndFunction

; Returns the current continuous mode status for display
String Function GetContinuousStatus()
    If GMWidgetScript.IsContinuousModeEnabled()
        Return "ON"
    Else
        Return "OFF"
    EndIf
EndFunction

; Apply whisper widget position preset
Function ApplyPositionPreset(Int presetIndex)
    If presetIndex == 0
        ; Custom - do nothing
        Return
    ElseIf presetIndex == 1
        ; Top Left
        WidgetScript.X = 5.0
        WidgetScript.Y = 5.0
        WidgetScript.HAnchor = "left"
        WidgetScript.VAnchor = "top"
    ElseIf presetIndex == 2
        ; Top Center
        WidgetScript.X = 640.0
        WidgetScript.Y = 5.0
        WidgetScript.HAnchor = "center"
        WidgetScript.VAnchor = "top"
    ElseIf presetIndex == 3
        ; Top Right
        WidgetScript.X = 1275.0
        WidgetScript.Y = 5.0
        WidgetScript.HAnchor = "right"
        WidgetScript.VAnchor = "top"
    ElseIf presetIndex == 4
        ; Center Left
        WidgetScript.X = 5.0
        WidgetScript.Y = 360.0
        WidgetScript.HAnchor = "left"
        WidgetScript.VAnchor = "center"
    ElseIf presetIndex == 5
        ; Center
        WidgetScript.X = 640.0
        WidgetScript.Y = 360.0
        WidgetScript.HAnchor = "center"
        WidgetScript.VAnchor = "center"
    ElseIf presetIndex == 6
        ; Center Right
        WidgetScript.X = 1275.0
        WidgetScript.Y = 360.0
        WidgetScript.HAnchor = "right"
        WidgetScript.VAnchor = "center"
    ElseIf presetIndex == 7
        ; Bottom Left
        WidgetScript.X = 5.0
        WidgetScript.Y = 715.0
        WidgetScript.HAnchor = "left"
        WidgetScript.VAnchor = "bottom"
    ElseIf presetIndex == 8
        ; Bottom Center
        WidgetScript.X = 640.0
        WidgetScript.Y = 715.0
        WidgetScript.HAnchor = "center"
        WidgetScript.VAnchor = "bottom"
    ElseIf presetIndex == 9
        ; Bottom Right (default)
        WidgetScript.X = 1272.0
        WidgetScript.Y = 716.0
        WidgetScript.HAnchor = "right"
        WidgetScript.VAnchor = "bottom"
    EndIf
    
    ; If relative positioning is enabled for GM widget, update its position too
    If gmUseRelativePosition
        ApplyRelativePosition()
    EndIf
EndFunction

; Apply GM widget position preset
Function ApplyGMPositionPreset(Int presetIndex)
    If presetIndex == 0
        ; Custom - do nothing
        Return
    ElseIf presetIndex == 1
        ; Top Left
        GMWidgetScript.X = 5.0
        GMWidgetScript.Y = 5.0
        GMWidgetScript.HAnchor = "left"
        GMWidgetScript.VAnchor = "top"
    ElseIf presetIndex == 2
        ; Top Center
        GMWidgetScript.X = 640.0
        GMWidgetScript.Y = 5.0
        GMWidgetScript.HAnchor = "center"
        GMWidgetScript.VAnchor = "top"
    ElseIf presetIndex == 3
        ; Top Right
        GMWidgetScript.X = 1275.0
        GMWidgetScript.Y = 5.0
        GMWidgetScript.HAnchor = "right"
        GMWidgetScript.VAnchor = "top"
    ElseIf presetIndex == 4
        ; Center Left
        GMWidgetScript.X = 5.0
        GMWidgetScript.Y = 360.0
        GMWidgetScript.HAnchor = "left"
        GMWidgetScript.VAnchor = "center"
    ElseIf presetIndex == 5
        ; Center
        GMWidgetScript.X = 640.0
        GMWidgetScript.Y = 360.0
        GMWidgetScript.HAnchor = "center"
        GMWidgetScript.VAnchor = "center"
    ElseIf presetIndex == 6
        ; Center Right
        GMWidgetScript.X = 1275.0
        GMWidgetScript.Y = 360.0
        GMWidgetScript.HAnchor = "right"
        GMWidgetScript.VAnchor = "center"
    ElseIf presetIndex == 7
        ; Bottom Left
        GMWidgetScript.X = 5.0
        GMWidgetScript.Y = 715.0
        GMWidgetScript.HAnchor = "left"
        GMWidgetScript.VAnchor = "bottom"
    ElseIf presetIndex == 8
        ; Bottom Center
        GMWidgetScript.X = 640.0
        GMWidgetScript.Y = 715.0
        GMWidgetScript.HAnchor = "center"
        GMWidgetScript.VAnchor = "bottom"
    ElseIf presetIndex == 9
        ; Bottom Right (default)
        GMWidgetScript.X = 1272.0
        GMWidgetScript.Y = 686.0
        GMWidgetScript.HAnchor = "right"
        GMWidgetScript.VAnchor = "bottom"
    EndIf
EndFunction

; Apply relative positioning to GM widget based on whisper widget position
Function ApplyRelativePosition()
    GMWidgetScript.X = WidgetScript.X + gmRelativeOffsetX
    
    ; Invert Y offset when whisper widget is anchored to top
    ; This prevents GM widget from going off-screen above the whisper widget
    Float yOffset = gmRelativeOffsetY
    If WidgetScript.VAnchor == "top"
        yOffset = -yOffset
    EndIf
    GMWidgetScript.Y = WidgetScript.Y + yOffset
    
    GMWidgetScript.HAnchor = WidgetScript.HAnchor
    GMWidgetScript.VAnchor = WidgetScript.VAnchor
EndFunction

; Check if two floats are close enough (for position matching)
Bool Function IsNear(Float a, Float b, Float tolerance = 5.0)
    Float diff = a - b
    If diff < 0
        diff = -diff
    EndIf
    Return diff <= tolerance
EndFunction

; Get the name of the current whisper widget position preset
String Function GetCurrentPresetName()
    ; Check each preset position
    If IsNear(WidgetScript.X, 48.0) && IsNear(WidgetScript.Y, 48.0)
        Return "Top Left"
    ElseIf IsNear(WidgetScript.X, 640.0) && IsNear(WidgetScript.Y, 48.0)
        Return "Top Center"
    ElseIf IsNear(WidgetScript.X, 1232.0) && IsNear(WidgetScript.Y, 48.0)
        Return "Top Right"
    ElseIf IsNear(WidgetScript.X, 48.0) && IsNear(WidgetScript.Y, 360.0)
        Return "Center Left"
    ElseIf IsNear(WidgetScript.X, 640.0) && IsNear(WidgetScript.Y, 360.0)
        Return "Center"
    ElseIf IsNear(WidgetScript.X, 1232.0) && IsNear(WidgetScript.Y, 360.0)
        Return "Center Right"
    ElseIf IsNear(WidgetScript.X, 48.0) && IsNear(WidgetScript.Y, 672.0)
        Return "Bottom Left"
    ElseIf IsNear(WidgetScript.X, 1272.0) && IsNear(WidgetScript.Y, 716.0)
        Return "Bottom Center"
    ElseIf IsNear(WidgetScript.X, 1232.0) && IsNear(WidgetScript.Y, 672.0)
        Return "Bottom Right"
    Else
        Return "Custom Preset"
    EndIf
EndFunction

; Get the name of the current GM widget position preset
String Function GetGMCurrentPresetName()
    ; Check each preset position
    If IsNear(GMWidgetScript.X, 48.0) && IsNear(GMWidgetScript.Y, 48.0)
        Return "Top Left"
    ElseIf IsNear(GMWidgetScript.X, 640.0) && IsNear(GMWidgetScript.Y, 48.0)
        Return "Top Center"
    ElseIf IsNear(GMWidgetScript.X, 1232.0) && IsNear(GMWidgetScript.Y, 48.0)
        Return "Top Right"
    ElseIf IsNear(GMWidgetScript.X, 48.0) && IsNear(GMWidgetScript.Y, 360.0)
        Return "Center Left"
    ElseIf IsNear(GMWidgetScript.X, 640.0) && IsNear(GMWidgetScript.Y, 360.0)
        Return "Center"
    ElseIf IsNear(GMWidgetScript.X, 1232.0) && IsNear(GMWidgetScript.Y, 360.0)
        Return "Center Right"
    ElseIf IsNear(GMWidgetScript.X, 48.0) && IsNear(GMWidgetScript.Y, 672.0)
        Return "Bottom Left"
    ElseIf IsNear(GMWidgetScript.X, 1272.0) && IsNear(GMWidgetScript.Y, 680.0)
        Return "Bottom Center"
    ElseIf IsNear(GMWidgetScript.X, 1232.0) && IsNear(GMWidgetScript.Y, 672.0)
        Return "Bottom Right"
    Else
        Return "Custom Preset"
    EndIf
EndFunction

; Converts internal horizontal anchor string to array index
; "left" -> 0, "center" -> 1, "right" -> 2
Int Function GetHAnchorIndex(String anchor)
    If (anchor == "left")
        Return 0
    ElseIf (anchor == "center")
        Return 1
    ElseIf (anchor == "right")
        Return 2
    Else
        Return 0  ; Default to left
    EndIf
EndFunction

; Converts internal vertical anchor string to array index
; "top" -> 0, "center" -> 1, "bottom" -> 2
Int Function GetVAnchorIndex(String anchor)
    If (anchor == "top")
        Return 0
    ElseIf (anchor == "center")
        Return 1
    ElseIf (anchor == "bottom")
        Return 2
    Else
        Return 0  ; Default to top
    EndIf
EndFunction

; Converts internal anchor string to display string for MCM
; Internal: "left"/"center"/"right" or "top"/"center"/"bottom"
; Display: "Left"/"Middle"/"Right" or "Top"/"Middle"/"Bottom"
String Function GetDisplayAnchor(String anchor, Bool isHorizontal)
    If isHorizontal
        Return hAnchorStrings[GetHAnchorIndex(anchor)]
    Else
        Return vAnchorStrings[GetVAnchorIndex(anchor)]
    EndIf
EndFunction
