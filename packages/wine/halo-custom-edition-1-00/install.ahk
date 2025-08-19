#Persistent
SetTitleMatchMode, 2  ; Allows partial matching of window titles

EulaWinTitle := "Halo - End User License Agreement"
WinTitle := "Halo Custom Edition Setup"

; Waits for a window to contain specific text
; Params:
;   WinTitle - the window title or ahk_class
;   TargetText - the text to wait for
;   Timeout := maximum time to wait in milliseconds (optional, default: 0 = infinite)
WaitForText(WinTitle, TargetText, Timeout := 0) {
    StartTime := A_TickCount
    Loop {
        ControlGetText, winText, , %WinTitle%
        if InStr(winText, TargetText)
            return True  ; Found the text
        if (Timeout > 0 && (A_TickCount - StartTime) > Timeout)
            return False ; Timeout reached
        Sleep, 500
    }
}

; Wait until the EULA window appears 
WinWait, %EulaWinTitle%
; Activate and click Accept
WinActivate, %EulaWinTitle%
ControlClick, Button1
WinWaitClose, %EulaWinTitle%


; "Setup cannot find a sound card"
Sleep, 2000
Send, {Enter}

; Wait until the installer window exists
WinWait, %WinTitle%
WinActivate, %WinTitle%

; Wait for dialogs to close
Sleep, 5000

; Send Enter key
Send, {Enter}

; Wait for next screen
Sleep, 5000

; Send the product key
Send, WWCXQQKQ4VQRWKQYDVGJFCRYJ
Sleep, 1000

; Send Enter key
Send, {Enter}

WaitForText(WinTitle, "&Next", 5000)
Sleep, 5000

; Send Enter
Send, {Enter}

; Wait for configuration screen
WaitForText(WinTitle, "Drive %c:", 5000)
Sleep, 5000

; Send Enter
Send, {Enter}

WaitForText(WinTitle, "Halo Custom Edition has been installed successfully!", 60000)

; Close the installer window
WinClose, %WinTitle%

ExitApp
