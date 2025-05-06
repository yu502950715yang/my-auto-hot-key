#Requires AutoHotkey v2.0
#SingleInstance Force

; 主配置文件
configFile := "EveQb.ini"

; 检查并创建默认配置文件
if !FileExist(configFile) {
    CreateDefaultConfig(configFile)
    MsgBox("已创建默认配置文件。请编辑 " configFile " 并重新运行脚本。")
    ExitApp
}

; 读取全局设置
globalSettings := Map(
    "TriggerHotkey", "^!F1",  ; 默认值
    "SendKey", "F1",
    "DelayBetween", 100,
    "RequireActivation", 1
)

try {
    foundSettings := false
    loop read, configFile {
        if InStr(A_LoopReadLine, "[Settings]") {
            foundSettings := true
            continue
        }
        ; 遇到下一个节头时停止读取
        if foundSettings && RegExMatch(A_LoopReadLine, "^\[") {
            break
        }
        if foundSettings {
            if (A_LoopReadLine = "" || InStr(A_LoopReadLine, ";")) {
                continue
            }
            if RegExMatch(A_LoopReadLine, "^\s*(\w+)\s*=\s*(.+?)\s*$", &match) {
                key := match[1]
                value := match[2]
                if globalSettings.Has(key) {
                    switch key {
                        case "DelayBetween", "RequireActivation":
                            globalSettings[key] := Integer(value)
                        default:
                            globalSettings[key] := value
                    }
                }
            }
        }
    }
} catch as e {
    MsgBox("读取配置文件时出错: " e.Message)
    ExitApp
}

; 读取目标窗口配置
windowPatterns := []
try {
    inWindowsSection := false
    loop read, configFile {
        if InStr(A_LoopReadLine, "[Windows]") {
            inWindowsSection := true
            continue
        }
        if inWindowsSection && RegExMatch(A_LoopReadLine, "^\[") {
            break
        }
        if inWindowsSection && A_LoopReadLine != "" && !InStr(A_LoopReadLine, ";") {
            windowPatterns.Push(Trim(A_LoopReadLine))
        }
    }
} catch as e {
    MsgBox("读取窗口配置时出错: " e.Message)
    ExitApp
}

; 注册热键
try {
    Hotkey(globalSettings["TriggerHotkey"], SendKeyToGames)
} catch as e {
    MsgBox("热键注册失败: " e.Message "`n请检查 TriggerHotkey 配置。")
    ExitApp
}

; 主功能：发送按键到所有匹配窗口
SendKeyToGames(*) {
    ; 存储原始活动窗口
    originalWindow := WinExist("A")
    
    ; 获取所有窗口列表
    windows := WinGetList()
    
    ; 遍历所有窗口
    for windowID in windows {
        try {
            title := WinGetTitle("ahk_id " windowID)
            exeName := WinGetProcessName("ahk_id " windowID)
            isVisible := WinGetMinMax("ahk_id " windowID)
            
            ; 跳过最小化的窗口
            if isVisible = -1 {
                continue
            }
            
            ; 检查是否匹配任何配置的模式
            for pattern in windowPatterns {
                if (InStr(title, pattern) || InStr(exeName, pattern)) {
                    ; 如果需要激活窗口
                    if globalSettings["RequireActivation"] {
                        try {
                            WinActivate("ahk_id " windowID)
                            WinWaitActive("ahk_id " windowID,, 1)
                        }
                    }
                    
                    ; 发送配置的按键
                    try {
                        if globalSettings["RequireActivation"] {
                            Send("{" globalSettings["SendKey"] "}")
                        } else {
                            ControlSend("{ " globalSettings["SendKey"] " }",, "ahk_id " windowID)
                        }
                    }
                    
                    ; 延迟
                    Sleep(globalSettings["DelayBetween"])
                    break
                }
            }
        }
    }
    
    ; 恢复原始活动窗口
    try {
        WinActivate("ahk_id " originalWindow)
    }
}

; 创建默认配置文件
CreateDefaultConfig(filePath) {
    defaultConfig := "
    (
    [Settings]
    ; 触发热键 (^=Ctrl, !=Alt, +=Shift, #=Win)
    TriggerHotkey=^!F1
    
    ; 要发送的按键 (可以是任何有效按键，如 F1, Enter, Space, a, b, 1, 2等)
    SendKey=F1
    
    ; 发送按键间的延迟(毫秒)
    DelayBetween=100
    
    ; 是否需要激活窗口 (1=是, 0=否)
    RequireActivation=1

    [Windows]
    ; 在此列出目标窗口的标题或进程名
    ; 每行一个，可以使用部分匹配
    ; 示例:
    Game.exe
    My Game Window
    AnotherGame
    )"
    
    try {
        FileAppend(defaultConfig, filePath, "UTF-8")
    } catch as e {
        MsgBox("创建配置文件失败: " e.Message)
    }
}