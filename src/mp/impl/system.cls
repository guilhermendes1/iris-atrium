Class mp.impl.system Extends %RegisteredObject
{

ClassMethod Prop(pObj, pName As %String, pDefault = "") As %String
{
    Set tValue = pDefault
    Try { Set tValue = $Property(pObj, pName) } Catch {}
    Quit $Get(tValue)
}

/// Live system health snapshot from /proc (Linux container) with safe fallbacks.
ClassMethod Metrics() As %DynamicObject
{
    Set tObj = {"cpuPercent":0, "memoryTotalKB":0, "memoryUsedKB":0, "memoryPercent":0, "uptimeSeconds":0}
    Try {
        Do ..ReadMemInfo(.tObj)
        Do ..ReadCpuStat(.tObj)
        Do ..ReadUptime(.tObj)
    } Catch {}
    Quit tObj
}

ClassMethod ReadMemInfo(ByRef pObj) As %Status
{
    Set tTotal = 0, tAvail = 0
    Try {
        Set tSC = ..ShellFile("cat /proc/meminfo", "/tmp/mp_meminfo.txt")
        If $$$ISERR(tSC) Return tSC
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile("/tmp/mp_meminfo.txt")
        If $$$ISERR(tSC) Return tSC
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If $Extract(tLine, 1, 9) = "MemTotal:" Set tTotal = +$ZStrip($Piece(tLine, " ", 2, *), "<>W") * 1
            If $Extract(tLine, 1, 13) = "MemAvailable:" Set tAvail = +$ZStrip($Piece(tLine, " ", 2, *), "<>W") * 1
            If tTotal > 0 && tAvail > 0 Quit
        }
    } Catch {}
    If tTotal > 0 {
        Set tUsed = tTotal - tAvail
        If tUsed < 0 Set tUsed = 0
        Do pObj.%Set("memoryTotalKB", tTotal)
        Do pObj.%Set("memoryUsedKB", tUsed)
        Do pObj.%Set("memoryPercent", ..Round(tUsed * 100 / tTotal))
    }
    Quit $$$OK
}

ClassMethod ReadCpuStat(ByRef pObj) As %Status
{
    Set tTot1 = 0, tIdle1 = 0, tTot2 = 0, tIdle2 = 0
    Try {
        Set tSC = ..CpuLine(.tTot1, .tIdle1)
        If $$$ISERR(tSC) Return tSC
        Hang 0.2
        Set tSC = ..CpuLine(.tTot2, .tIdle2)
        If $$$ISERR(tSC) Return tSC
    } Catch {}
    Set tDiff = tTot2 - tTot1
    If tDiff > 0 {
        Set tIdle = tIdle2 - tIdle1
        If tIdle < 0 Set tIdle = 0
        Do pObj.%Set("cpuPercent", ..Round(100 - tIdle * 100 / tDiff))
    }
    Quit $$$OK
}

ClassMethod CpuLine(Output pTotal, Output pIdle) As %Status
{
    Set pTotal = 0, pIdle = 0
    Try {
        Set tSC = ..ShellFile("cat /proc/stat", "/tmp/mp_stat.txt")
        If $$$ISERR(tSC) Return tSC
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile("/tmp/mp_stat.txt")
        If $$$ISERR(tSC) Return tSC
        Set tLine = tStream.ReadLine()
        If $Piece(tLine, " ", 1) '= "cpu" Return $$$ERROR($$$GeneralError, "Unexpected /proc/stat")
        For i = 2:1:8 {
            Set pTotal = pTotal + +$Piece(tLine, " ", i) * 1
        }
        Set pIdle = +$Piece(tLine, " ", 5) * 1
    } Catch ex {
        Return ex.AsStatus()
    }
    Quit $$$OK
}

ClassMethod ReadUptime(ByRef pObj) As %Status
{
    Try {
        Set tSC = ..ShellFile("cat /proc/uptime", "/tmp/mp_uptime.txt")
        If $$$ISERR(tSC) Return tSC
        Set tText = ..ReadFileLine("/tmp/mp_uptime.txt")
        If tText '= "" Do pObj.%Set("uptimeSeconds", +$Piece(tText, " ", 1))
    } Catch {}
    Quit $$$OK
}

/// Run a shell command redirecting stdout to a temp file (works for /proc).
ClassMethod ShellFile(pCmd As %String, pOutFile As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tCmd = pCmd _ " > " _ pOutFile _ " 2>/dev/null"
        Set tRc = $ZF(-1, tCmd)
        If tRc '= 0 Set tSC = $$$ERROR($$$GeneralError, "Command failed: " _ tCmd)
        If '##class(%Library.File).Exists(pOutFile) Set tSC = $$$ERROR($$$GeneralError, "No output: " _ pOutFile)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// First line of a (real, seekable) file.
ClassMethod ReadFileLine(pPath As %String) As %String
{
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Set tSC = tStream.LinkToFile(pPath)
        If '$$$ISERR(tSC) Set tText = tStream.ReadLine(32768)
    } Catch {}
    Quit tText
}

ClassMethod Round(pValue As %Double) As %Double
{
    Quit +$Justify(pValue, 2, 1)
}

/// Disk usage for unique IRIS database directories (Linux df, guarded).
ClassMethod Disks() As %DynamicArray
{
    Set tArr = []
    Try {
        Set tDirs = []
        Set tBuilt = []
        Do ..AddDatabaseDirectories(.tBuilt, .tDirs)
        For i = 0:1:tDirs.%Size() - 1 {
            Set tDir = tDirs.%Get(i)
            Continue:tDir=""
            If tDir [ " " Continue
            Set tTotal = 0, tUsed = 0, tPct = 0
            Try {
                Set tSC = ..ShellFile("df -Pk "_ tDir, "/tmp/mp_df.txt")
                If $$$ISERR(tSC) Continue
                Set tText = ""
                Set tStream = ##class(%Stream.FileCharacter).%New()
                Set tSC = tStream.LinkToFile("/tmp/mp_df.txt")
                If $$$ISERR(tSC) Continue
                Set tCount = 0
                While 'tStream.AtEnd {
                    Set tLine = ..Collapse($ZStrip(tStream.ReadLine(), "<>W"))
                    Set tCount = tCount + 1
                    If tCount = 2 {
                        If tLine '= "" {
                            ; df -Pk columns: Filesystem 1024-blocks Used Available Capacity Mount
                            Set tTotal = +$Piece(tLine, " ", 2) * 1
                            Set tUsed = +$Piece(tLine, " ", 3) * 1
                            If tTotal > 0 Set tPct = ..Round(tUsed * 100 / tTotal)
                        }
                        Quit
                    }
                }
            } Catch {}
            Do tArr.%Push({
                "path":(tDir),
                "name":(""),
                "totalMB":(..Mb(tTotal)),
                "usedMB":(..Mb(tUsed)),
                "percentUsed":(tPct)
            })
        }
    } Catch {}
    Quit tArr
}

ClassMethod Mb(pKB As %Integer) As %Integer
{
    Quit $Number(pKB / 1024, "I")
}

/// Collect candidate database directories (Config.Databases when available).
ClassMethod AddDatabaseDirectories(ByRef pSeen, ByRef pDirs) As %Status
{
    Try {
        New $NAMESPACE
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Config.Databases).List(.tNames)
        If $$$ISERR(tSC) Return tSC
        Set tName = ""
        For {
            Set tName = $Order(tNames(tName))
            Quit:tName=""
            Try {
                Set tDb = ##class(Config.Databases).%OpenId(tName)
                If $IsObject(tDb) {
                    Set tDir = ..Prop(tDb, "Directory")
                    If tDir '= "" && '$Data(pSeen(tDir)) {
                        Set pSeen(tDir) = 1
                        Do pDirs.%Push(tDir)
                    }
                }
            } Catch {}
        }
    } Catch {}
    If pDirs.%Size() = 0 {
        Try { Do pDirs.%Push("/usr/irissys/mgr") } Catch {}
        Try {
            New $NAMESPACE
            Set $NAMESPACE = "%SYS"
            Set tPath = ##class(%SYS.Namespace).%OpenId("USER")
            If $IsObject(tPath) Do pDirs.%Push(..Prop(tPath, "Global"))
        } Catch {}
    }
    If pDirs.%Size() > 0 {
        ; normalize: only keep unique, drop unknown namespaces-global placeholders
        Set tNew = []
        For i = 0:1:pDirs.%Size() - 1 {
            Set tDir = pDirs.%Get(i)
            If tDir = "" || ($Extract(tDir, 1, 1) '= "/") Continue
            Do tNew.%Push(tDir)
        }
        Set pDirs = tNew
    }
    Quit $$$OK
}

/// List IRIS namespaces with their database directory (best effort), sourced from the native Atelier server descriptor.
ClassMethod Namespaces() As %DynamicArray
{
    Set tArr = []
    Try {
        Set tSC = ##class(mp.util.security).GetCredentials(.tUser, .tPass)
        If $$$ISERR(tSC) Return tArr
        Set tBody = ""
        Set tSC = ##class(mp.impl.webapps).GetJson("/api/atelier/", tUser, tPass, .tBody)
        If $$$ISERR(tSC) Return tArr
        Set tDyn = ##class(%DynamicObject).%FromJSON(tBody)
        If '$IsObject(tDyn) Return tArr
        If 'tDyn.%IsDefined("result") || '$IsObject(tDyn.result) Return tArr
        Set tList = tDyn.result.content.namespaces
        Set tSize = 0
        If $IsObject(tList) Set tSize = tList.%Size()
        For i = 0:1:tSize - 1 {
            Set tName = tList.%Get(i)
            If tName = "" Continue
            Do tArr.%Push({"name":(tName), "directory":(..NsDir(tName))})
        }
    } Catch {}
    Quit tArr
}

/// Best-effort database directory for a namespace via the Config APIs.
ClassMethod NsDir(pNamespace As %String) As %String
{
    Set tDir = ""
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Try {
        Set tSCg = ##class(Config.Namespaces).Get(pNamespace, .tProps)
        If tSCg = 1 {
            Set tDb = $Get(tProps("Global"))
            If tDb '= "" {
                Set tDbSC = ##class(Config.Databases).Get(tDb, .tDbProps)
                If tDbSC = 1 Set tDir = $Get(tDbProps("Directory"))
            }
        }
    } Catch {}
    Set $Namespace = tNs
    Quit tDir
}

/// List IRIS processes via the native Atelier jobs endpoint, optionally filtered by namespace.
ClassMethod Processes(pNamespace As %String = "") As %DynamicArray
{
    Set tArr = []
    Try {
        Set tSC = ##class(mp.util.security).GetCredentials(.tUser, .tPass)
        If $$$ISERR(tSC) Return tArr
        Set tBody = ""
        Set tSC = ##class(mp.impl.webapps).GetJson("/api/atelier/v1/%25SYS/jobs?system=1", tUser, tPass, .tBody)
        If $$$ISERR(tSC) Return tArr
        Set tDyn = ##class(%DynamicObject).%FromJSON(tBody)
        If '$IsObject(tDyn) || 'tDyn.%IsA("%Library.DynamicObject") Return tArr
        If 'tDyn.%IsDefined("result") || '$IsObject(tDyn.result) Return tArr
        Set tList = tDyn.result.content
        Set tSize = 0
        If $IsObject(tList) Set tSize = tList.%Size()
        For i = 0:1:tSize - 1 {
            Set tJob = tList.%Get(i)
            If '$IsObject(tJob) Continue
            Set tJobNs = ..Dyn(tJob, "namespace")
            If (pNamespace '= "") && ($ZConvert(tJobNs, "L") '= $ZConvert(pNamespace, "L")) Continue
            Do tArr.%Push({
                "pid":(+..Dyn(tJob, "pid", 0)),
                "userName":(..Dyn(tJob, "user", "")),
                "namespace":(tJobNs),
                "routine":(..Dyn(tJob, "routine")),
                "state":(..Dyn(tJob, "state", "Running")),
                "cpuTime":(+..Dyn(tJob, "cpu", 0)),
                "memoryUsedKB":(+..Dyn(tJob, "memoryUsed", 0)),
                "globalReferences":(+..Dyn(tJob, "globalReferences", 0)),
                "clientIP":(..Dyn(tJob, "clientIP", "")),
                "jobType":(+..Dyn(tJob, "jobType", 0)),
                "canBeTerminated":1,
                "startTimeUTC":(##class(mp.util.json).StampFlex(..Dyn(tJob, "startTime")))
            })
        }
    } Catch {}
    Quit tArr
}

/// Namespace-agnostic dynamic-property access.
ClassMethod Dyn(pObj, pName As %String, pDefault = "") As %String
{
    Set tValue = pDefault
    Try {
        If pObj.%IsDefined(pName) Set tValue = pObj.%Get(pName)
    } Catch {}
    Quit tValue
}

ClassMethod NumericDate(pValue) As %String
{
    If pValue = "" Quit ""
    If pValue = 0 Quit ""
    Quit pValue
}

/// Collapse runs of spaces into single spaces (df -Pk can be space-padded).
ClassMethod Collapse(pText As %String) As %String
{
    Set tOut = ""
    For i = 1:1:$Length(pText, " ") {
        Set tTok = $Piece(pText, " ", i)
        If tTok '= "" Set tOut = tOut _ $Select(tOut = "": "", 1: " ") _ tTok
    }
    Quit tOut
}

/// Terminate an IRIS process by pid.
ClassMethod Terminate(pPid As %String) As %Status
{
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Try {
        Set tProc = ##class(%SYS.Process).%OpenId(pPid)
        If $IsObject(tProc) {
            Set tSC = tProc.Terminate()
            If '$$$ISERR(tSC) Return $$$OK
        }
    } Catch {}
    ; fallback via process context
    Try {
        Set tSC = $System.Process.Terminate(pPid)
        If $$$ISERR(tSC) Return tSC
        Return $$$OK
    } Catch ex {
        Return ex.AsStatus()
    }
}

}