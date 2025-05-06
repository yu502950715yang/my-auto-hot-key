; 主配置文件路径
#Requires AutoHotkey v2.0
#SingleInstance Force

; 主配置文件路径
configFile := "EveQb.ini"

; 检查并创建默认配置文件
; 当配置文件不存在时生成带注释的默认配置
if !FileExist(configFile) {
    CreateDefaultConfig(configFile)
    MsgBox("已创建默认配置文件。请编辑 " configFile " 并重新运行脚本。")
    ExitApp
}

; 全局配置默认值
; 使用Map结构存储可配置参数及其默认值
globalSettings := Map(
    "TriggerHotkey", "^!F1",  ; 默认值
    "SendKey", "F1",
    "DelayBetween", 100,
    "RequireActivation", 1
)

; 读取[Settings]配置节
; 解析配置文件中的键值对并覆盖默认值
try {
    foundSettings := false
    configContent := FileRead(configFile, "UTF-8")  ; 显式指定编码
    configContent := StrReplace(configContent, "`r")  ; 移除回车符
    configContent := RegExReplace(configContent, "^\xFEFF", "")  ; 移除BOM头
    loop parse configContent, "`n" {
        currentLine := Trim(A_LoopField)
        if InStr(currentLine, "[Settings]") {
            foundSettings := true
            continue
        }
        ; 遇到下一个节头时停止读取
        if foundSettings && RegExMatch(currentLine, "^\[") {
            break
        }
        if foundSettings {
            ; 跳过空行和注释
            if (currentLine = "" || InStr(currentLine, ";")) {
                continue
            }
            ; 使用正则表达式提取键值对
            if RegExMatch(currentLine, "^\s*(\w+)\s*=\s*(.+?)\s*$", &match) {
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

; 读取[Windows]配置节
; 收集窗口标题/进程名的匹配模式
windowPatterns := []
try {
    inWindowsSection := false
    configContent := FileRead(configFile, "UTF-8")  ; 显式指定编码
    configContent := StrReplace(configContent, "`r")  ; 移除回车符
    configContent := RegExReplace(configContent, "^\xFEFF", "")  ; 移除BOM头
    loop parse configContent, "`n" {
        currentLine := Trim(A_LoopField)
        if InStr(currentLine, "[Windows]") {
            inWindowsSection := true
            continue
        }
        if inWindowsSection && RegExMatch(currentLine, "^\[") {
            break
        }
        if inWindowsSection && currentLine != "" && !InStr(currentLine, ";") {
            MsgBox("匹配模式: " currentLine)
            windowPatterns.Push(Trim(currentLine))
        }
    }
} catch as e {
    MsgBox("读取窗口配置时出错: " e.Message)
    ExitApp
}

; joined := ""
; for index, pattern in windowPatterns {
;     joined .= (index > 1 ? ", " : "") pattern
; }
; MsgBox("窗口匹配模式: " joined)

; 注册全局热键
try {
    Hotkey(globalSettings["TriggerHotkey"], SendKeyToGames)
} catch as e {
    MsgBox("热键注册失败: " e.Message "`n请检查 TriggerHotkey 配置。")
    ExitApp
}

; 函数：SendKeyToGames
; 功能：向所有匹配窗口发送配置的按键
; 参数：* (可变参数，AHK热键函数的回调参数规范)
SendKeyToGames(*) {
    ; 存储原始活动窗口
    originalWindow := WinExist("A")
    
    ; 遍历所有窗口进行匹配
    windows := WinGetList()
    for windowID in windows {
        ; 打印窗口ID和标题
        ; MsgBox("窗口ID: " windowID  "`n标题: " WinGetTitle("ahk_id " windowID))
        try {
            title := WinGetTitle("ahk_id " windowID)
            exeName := WinGetProcessName("ahk_id " windowID)
            isVisible := WinGetMinMax("ahk_id " windowID)
            
            ; 跳过最小化窗口
            if isVisible = -1 {
                continue
            }
            
            ; 窗口匹配逻辑
            for pattern in windowPatterns {
                if (InStr(title, pattern) || InStr(exeName, pattern)) {
                    ; 窗口激活处理
                    if globalSettings["RequireActivation"] {
                        try {
                            WinActivate("ahk_id " windowID)
                            WinWaitActive("ahk_id " windowID,, 1)
                        }
                    }
                    
                    ; 发送按键逻辑
                    try {
                        if globalSettings["RequireActivation"] {
                            Send("{" globalSettings["SendKey"] "}")
                        } else {
                            ControlSend("{ " globalSettings["SendKey"] " }",, "ahk_id " windowID)
                        }
                    }
                    
                    ; 保持配置的发送间隔
                    Sleep(globalSettings["DelayBetween"])
                    break
                }
            }
        }
    }
    
    ; 恢复原始窗口状态
    try {
        WinActivate("ahk_id " originalWindow)
    }
}

; 函数：CreateDefaultConfig
; 功能：生成带注释的默认配置文件
; 参数：filePath - 要创建的配置文件路径
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
    ; 可以使用游戏名来识别游戏窗口
    ; 示例:
    军用馒头
    隔壁老王
    )"
    
    try {
        FileAppend(defaultConfig, filePath, "UTF-8")
    } catch as e {
        MsgBox("创建配置文件失败: " e.Message)
    }
}