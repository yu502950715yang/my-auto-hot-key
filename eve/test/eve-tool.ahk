#Requires AutoHotkey v2.0
#SingleInstance Force
InstallKeybdHook
InstallMouseHook
SetTitleMatchMode 3

; 配置区 =================================
TargetWindows := [
    "测试1.txt - 记事本",
    "测试2.txt - 记事本"
]
SyncKeys := ["F4", "F5", "Ctrl+1"]  ; 混合测试键
; =======================================

; 获取窗口句柄
DetectHiddenWindows true
hwnds := []
for winTitle in TargetWindows {
    if (winTitle != "") {
        if hwnd := WinExist(winTitle) {
            hwnds.Push(hwnd)
        }
    }
}

; 动态热键绑定
for key in SyncKeys {
    try Hotkey "~$*" key, SyncInput  ; 增加错误捕获
}

SyncInput(thisHotkey) {
    key := RegExReplace(thisHotkey, "~|\$|\*") 
    ToolTip "正在同步：" key
    
    ; 遍历所有窗口句柄
    for hwnd in hwnds {
        ControlSend "{Blind}{" key " Down}", "Edit1", "ahk_id " hwnd
        Sleep 10
        ControlSend "{Blind}{" key " Up}", "Edit1", "ahk_id " hwnd
        ControlSend "{Text}[" A_Hour ":" A_Min "] " key "`n", "Edit1", "ahk_id " hwnd
    }
    
    SetTimer RemoveToolTip, -1000
}

RemoveToolTip() {
    ToolTip
}

F12:: {
    info := ""
    loopCount := hwnds.Length
    if (loopCount = 0) {
        info := "未找到任何窗口句柄"
    } else {
        for i, hwnd in hwnds {
            info .= "窗口" i "句柄：" hwnd 
            if (i < loopCount) {
                info .= "`n"  ; 
            }
        }
    }
    MsgBox info
}