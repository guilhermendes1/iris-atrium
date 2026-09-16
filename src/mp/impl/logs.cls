Class mp.impl.logs Extends %RegisteredObject
{

ClassMethod Prop(pObj, pName As %String, pDefault = "") As %String
{
    Set tValue = pDefault
    Try { Set tValue = $Property(pObj, pName) } Catch {}
    Quit $Get(tValue)
}

ClassMethod ConsolePath() As %String
{
    Quit "/usr/irissys/mgr/console.log"
}

ClassMethod MessagesPath() As %String
{
    Quit "/usr/irissys/mgr/messages.log"
}

ClassMethod FileAvailable(pPath As %String) As %Boolean
{
    Set tOk = 0
    Try { Set tOk = ##class(%Library.File).Exists(pPath) } Catch { Set tOk = 0 }
    Quit tOk
}

/// Available log sources and their health.
ClassMethod Sources() As %DynamicArray
{
    Set tArr = []
    Set tConsole = ..FileAvailable(..ConsolePath()) || ..FileAvailable(..MessagesPath())
    Do tArr.%Push({"name":"Console", "available":(+tConsole)})
    Set tMessages = ..FileAvailable(..MessagesPath())
    Do tArr.%Push({"name":"Messages", "available":(+tMessages)})
    Do tArr.%Push({"name":"Audit", "available":(+..AuditAvailable())})
    Do tArr.%Push({"name":"TaskHistory", "available":1})
    Quit tArr
}

ClassMethod AuditAvailable() As %Boolean
{
    Set tOk = 0
    Try {
        Set tNS = ##class(%Library.ResultSet).%New("%SYS.Audit:QueryEvents")
        If tNS = "" Return 0
        Set tSC = tNS.Execute()
        If $$$ISERR(tSC) Return 0
        Set tOk = 1
    } Catch { Set tOk = 0 }
    Quit tOk
}

/// Unified log query across sources with filters.
ClassMethod Query(pSource As %String = "", pFrom As %String = "", pTo As %String = "", pSeverity As %String = "", pPageSize As %Integer = 200) As %DynamicObject
{
    Set tEntries = []
    Set tSource = $ZConvert($Get(pSource), "L")
    If tSource = "" || (tSource = "all") || (tSource = "console") Do ..ConsoleEntries(pFrom, pTo, pSeverity, .tEntries)
    If tSource = "" || (tSource = "all") || (tSource = "messages") Do ..MessagesEntries(pFrom, pTo, pSeverity, .tEntries)
    If tSource = "" || (tSource = "all") || (tSource = "audit") Do ..AuditEntries(pFrom, pTo, pSeverity, .tEntries)
    If tSource = "" || (tSource = "all") || (tSource = "taskhistory") Do ..TaskHistoryEntries(pFrom, pTo, pSeverity, .tEntries)

    Set tTotal = tEntries.%Size()
    If pPageSize < 1 Set pPageSize = 200
    If tTotal > pPageSize {
        Set tSliced = []
        For i = 0:1:pPageSize - 1 { Do tSliced.%Push(tEntries.%Get(i)) }
        Set tEntries = tSliced
    }
    Quit {"entries":(tEntries), "total":(tTotal)}
}

/// Convert the query result to CSV text.
ClassMethod ToCsv(pResult As %DynamicObject) As %String
{
    Set tCsv = "timestamp,severity,source,message,job,user" _ $Char(13, 10)
    Try {
        Set tEntries = pResult.entries
        For i = 0:1:tEntries.%Size() - 1 {
            Set tE = tEntries.%Get(i)
            Set tRow = $ListBuild(
                ..CsvEscape(##class(mp.util.json).DynVal(tE, "timestamp", "")),
                ..CsvEscape(##class(mp.util.json).DynVal(tE, "severity", "")),
                ..CsvEscape(##class(mp.util.json).DynVal(tE, "source", "")),
                ..CsvEscape(##class(mp.util.json).DynVal(tE, "message", "")),
                ..CsvEscape(##class(mp.util.json).DynVal(tE, "job", "")),
                ..CsvEscape(##class(mp.util.json).DynVal(tE, "user", "")))
            Set tCsv = tCsv _ $Replace($ListToString(tRow, ","), "", "") _ $Char(13, 10)
        }
    } Catch {}
    Quit tCsv
}

ClassMethod CsvEscape(pValue As %String) As %String
{
    Set tValue = $Get(pValue)
    Set tValue = $Replace(tValue, """", """""")
    Quit """" _ tValue _ """"
}

/// Read a log file into unified entries.
ClassMethod ReadLogFile(pPath As %String, pSource As %String, pFrom As %String, pTo As %String, pSeverity As %String, ByRef pEntries) As %Status
{
    If '..FileAvailable(pPath) Quit $$$OK
    Set tFrom = ..ToH(pFrom)
    Set tTo = ..ToH(pTo)
    Set tStream = ##class(%Stream.FileCharacter).%New()
    Set tSC = tStream.LinkToFile(pPath)
    If $$$ISERR(tSC) Return tSC
    Set tYear = $Piece($ZDate($H, 3), "-", 1)
    Set tLineNo = 0
    While 1 {
        Set tLine = tStream.ReadLine(32768)
        If '$Length(tLine) Quit
        Set tLineNo = tLineNo + 1
        If tLineNo > 50000 Quit
        Set tEntry = ..ParseLogLine(tLine, pSource, tYear)
        If '$IsObject(tEntry) Continue
        If ..Filter(tEntry, tFrom, tTo, pSeverity) Do pEntries.%Push(tEntry)
    }
    Quit $$$OK
}

/// Parse one console/messages log line. Supports both formats:
///   "09/16/26-11:39:00:930 (pid) 0 [GROUP] message"      (messages.log)
///   "09-16-26 11:39:00 message"                          (console.log style)
ClassMethod ParseLogLine(pLine As %String, pSource As %String, pYear As %String) As %DynamicObject
{
    Set tEntry = ""
    Try {
        Set tPrefix = $Piece(pLine, " ", 1)
        If $Length(tPrefix) < 5 Return ""
        Set tDatePart = $Piece(tPrefix, "-", 1)
        If tDatePart = "" Return ""
        ; messages.log packs the time after the dash inside token 1
        Set tTimePart = $Piece(tPrefix, "-", 2)
        If tTimePart = "" Set tTimePart = $Piece(pLine, " ", 2)
        ; drop fractional/millisecond suffix (4th colon part)
        Set tTimePart = $Piece(tTimePart, ":", 1, 3)
        Set tMorD = $Piece(tDatePart, "/", 1)
        Set tDy = $Piece(tDatePart, "/", 2)
        If tMorD = "" {
            ; fall back to dash-separated dates (MM-DD-YY)
            Set tMorD = $Piece(tDatePart, "-", 1)
            Set tDy = $Piece(tDatePart, "-", 2)
        }
        Set tYear = +$Piece(tDatePart, "/", 3)
        If tYear = 0 Set tYear = +pYear
        If tYear < 100 Set tYear = tYear + 2000
        Set tMonth = +tMorD
        Set tDay = +tDy
        If 'tMonth || 'tDay Return ""
        Set tRest = $Piece(pLine, " ", 2, *)
        Set tDayH = $ZDateH(tMonth _ "/" _ tDay _ "/" _ tYear, 1)
        Set tSecH = 0
        If tTimePart '= "" {
            Try { Set tSecH = $ZTimeH(tTimePart, 1) } Catch {}
        }
        Set tH = tDayH_","_tSecH
        Set tSeverity = "Info"
        Set tUp = $ZConvert(tRest, "U")
        If tUp [ "ERROR" Set tSeverity = "Error"
        If tUp [ "WARNING" Set tSeverity = "Warning"
        If tUp [ "DEBUG" Set tSeverity = "Debug"
        Set tEntry = {
            "timestamp":(##class(mp.util.json).Stamp(tH)),
            "severity":(tSeverity),
            "source":(pSource),
            "message":(tRest),
            "detail":"",
            "job":"",
            "user":""
        }
    } Catch {}
    Quit tEntry
}

ClassMethod ConsoleEntries(pFrom, pTo, pSeverity, ByRef pEntries) As %Status
{
    If ..FileAvailable(..ConsolePath()) Do ..ReadLogFile(..ConsolePath(), "Console", pFrom, pTo, pSeverity, .pEntries)
    Else
    Do ..ReadLogFile(..MessagesPath(), "Console", pFrom, pTo, pSeverity, .pEntries)
    Quit $$$OK
}

ClassMethod MessagesEntries(pFrom, pTo, pSeverity, ByRef pEntries) As %Status
{
    Do ..ReadLogFile(..MessagesPath(), "Messages", pFrom, pTo, pSeverity, .pEntries)
    Quit $$$OK
}

ClassMethod AuditEntries(pFrom, pTo, pSeverity, ByRef pEntries) As %Status
{
    Set tFrom = ..ToH(pFrom)
    Set tTo = ..ToH(pTo)
    Try {
        Set tNS = ##class(%Library.ResultSet).%New("%SYS.Audit:QueryEvents")
        If tNS = "" Return $$$OK
        Set tSC = tNS.Execute()
        If $$$ISERR(tSC) Return $$$OK
        While tNS.Next() {
            Set tEntry = {
                "timestamp":"",
                "severity":"Info",
                "source":"Audit",
                "message":($Get(tNS.Data("EventDescription"))),
                "detail":($Get(tNS.Data("ErrorMessage"))),
                "job":($Get(tNS.Data("JobId"))),
                "user":($Get(tNS.Data("Username")))
            }
            Set tH = ..ResultH(tNS, "TimeCreated")
            If tH '= "" Do tEntry.%Set("timestamp", ##class(mp.util.json).Stamp(tH))
            Do tEntry.%Set("message", $Get(tNS.Data("EventDescription")))
            Do tEntry.%Set("severity", ..AuditSeverity(tNS))
            If ..Filter(tEntry, tFrom, tTo, pSeverity) Do pEntries.%Push(tEntry)
        }
    } Catch {}
    Quit $$$OK
}

ClassMethod ResultH(pNS, pColumn) As %String
{
    Set tValue = ""
    Try { Set tValue = pNS.Data(pColumn) } Catch {}
    If tValue = "" Quit ""
    Quit tValue
}

ClassMethod AuditSeverity(pNS) As %String
{
    Set tFlag = ""
    Try { Set tFlag = pNS.Data("Flags") } Catch {}
    If tFlag [ "E" Quit "Error"
    If tFlag [ "W" Quit "Warning"
    Quit "Info"
}

ClassMethod TaskHistoryEntries(pFrom, pTo, pSeverity, ByRef pEntries) As %Status
{
    Set tFrom = ..ToH(pFrom)
    Set tTo = ..ToH(pTo)
    Try {
        Set tHistory = ##class(mp.impl.tasks).History("")
        For i = 0:1:tHistory.%Size() - 1 {
            Set tItem = tHistory.%Get(i)
            Set tName = ##class(mp.util.json).DynVal(tItem, "name", tItem.guid)
            Set tStatus = ##class(mp.util.json).DynVal(tItem, "status", "Finished")
            Set tEntry = {
                "timestamp":(##class(mp.util.json).DynVal(tItem, "finishTime", "")),
                "severity":"Info",
                "source":"TaskHistory",
                "message":("Task " _ tStatus _ ": " _ tName),
                "detail":(##class(mp.util.json).DynVal(tItem, "error", "")),
                "job":"",
                "user":""
            }
            If ##class(mp.util.json).DynVal(tItem, "error", "") '= "" Do tEntry.%Set("severity", "Error")
            If ..Filter(tEntry, tFrom, tTo, pSeverity) Do pEntries.%Push(tEntry)
        }
    } Catch {}
    Quit $$$OK
}

ClassMethod Filter(pEntry As %DynamicObject, pFrom As %String, pTo As %String, pSeverity As %String) As %Boolean
{
    If pSeverity '= "" {
        If $ZConvert(pEntry.severity, "L") '= $ZConvert(pSeverity, "L") Quit 0
    }
    If pFrom '= "" {
        Set tH = ..ToH(pEntry.timestamp)
        If tH '= "" && (tH < pFrom) Quit 0
    }
    If pTo '= "" {
        Set tH = ..ToH(pEntry.timestamp)
        If tH '= "" && (tH > pTo) Quit 0
    }
    Quit 1
}

/// Parse an ISO timestamp (yyyy-mm-ddThh:mm:ss) into $H.
ClassMethod ToH(pIso As %String) As %String
{
    If pIso = "" Quit ""
    Set tValue = $Piece(pIso, ".", 1)
    Set tValue = $Replace(tValue, "Z", "")
    Set tDate = $Piece(tValue, "T", 1)
    Set tTime = $Piece(tValue, "T", 2)
    Set tDate = $Replace(tDate, "-", "/")
    Set tH = ""
    Try {
        Set tDayH = $ZDateH(tDate, 1)
        Set tSecH = 0
        If tTime '= "" { Set tSecH = $ZTimeH(tTime, 1) }
        Set tH = tDayH_","_tSecH
    } Catch {}
    Quit tH
}

}