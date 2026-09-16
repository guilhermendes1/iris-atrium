Class mp.impl.tasks Extends %RegisteredObject
{

ClassMethod Prop(pObj, pName As %String, pDefault = "") As %String
{
    Set tValue = pDefault
    Try { Set tValue = $Property(pObj, pName) } Catch {}
    Quit $Get(tValue)
}

ClassMethod InSys() As %String
{
    Set $NAMESPACE = "%SYS"
    Quit ""
}

ClassMethod Tasks() As %DynamicArray
{
    Set tArr = []
    New $NAMESPACE
    Set tOld = ..InSys()
    Try {
        Set tId = ""
        For {
            Set tId = $Order(^SYS("Task", "TaskD", tId))
            Quit:tId=""
            Set tTask = ##class(%SYS.Task).%OpenId(tId)
            Continue:'$IsObject(tTask)
            Do tArr.%Push(..TaskRow(tTask))
        }
    } Catch {}
    Quit tArr
}

ClassMethod TaskRow(pTask) As %DynamicObject
{
    Set tGuid = pTask.%Id()
    Set tObj = {
        "guid":(tGuid),
        "name":(..Prop(pTask, "Name")),
        "description":(..Prop(pTask, "Description")),
        "namespace":(..Prop(pTask, "NameSpace")),
        "taskClass":(..Prop(pTask, "TaskClass")),
        "frequency":(..Prop(pTask, "DisplayRun")),
        "runAsUser":(..Prop(pTask, "RunAsUser")),
        "enabled":(..Enabled(pTask)),
        "status":(..TaskStatus(pTask)),
        "nextScheduled":(..Prop(pTask, "DisplayNextScheduled")),
        "lastStarted":(##class(mp.util.json).StampFlex(..Prop(pTask, "LastStarted"))),
        "lastFinished":(##class(mp.util.json).StampFlex(..Prop(pTask, "LastFinished"))),
        "error":(..Prop(pTask, "Error"))
    }
    Quit tObj
}

ClassMethod Enabled(pTask) As %Boolean
{
    Try {
        If $Property(pTask, "Suspended") = 1 Return 0
    } Catch {}
    Quit 1
}

ClassMethod TaskStatus(pTask) As %String
{
    If ..Enabled(pTask) = 0 Quit "Suspended"
    Set tRaw = ..Prop(pTask, "Status")
    If tRaw = 0 Quit "Idle"
    If tRaw = 1 Quit "Scheduled"
    If tRaw = 2 Quit "Running"
    If tRaw = 3 Quit "Suspended"
    If tRaw = 4 Quit "Terminated"
    If tRaw = 5 Quit "Error"
    Quit tRaw
}

/// Trigger a task to run now.
ClassMethod RunNow(pGuid As %String) As %Status
{
    New $NAMESPACE
    Set tOld = ..InSys()
    Try {
        Return ##class(%SYS.Task).RunNow(pGuid)
    } Catch ex {
        Return ex.AsStatus()
    }
}

/// Suspend (1) or resume (0) a task.
ClassMethod SetSuspended(pGuid As %String, pSuspended As %Boolean) As %Status
{
    New $NAMESPACE
    Set tOld = ..InSys()
    Try {
        If pSuspended {
            Return ##class(%SYS.Task).Suspend(pGuid)
        } Else {
            Return ##class(%SYS.Task).Resume(pGuid)
        }
    } Catch ex {
        Return ex.AsStatus()
    }
}

/// Task execution history (filtered by task guid when provided).
ClassMethod History(pGuid As %String = "") As %DynamicArray
{
    Set tArr = []
    New $NAMESPACE
    Set tOld = ..InSys()
    Try {
        Set tId = ""
        For {
            Set tId = $Order(^SYS("Task", "HistoryD", tId), -1)
            Quit:tId=""
            Set tEntry = ..HistoryRow(tId)
            Continue:'$IsObject(tEntry)
            If (pGuid '= "") && (tEntry.guid '= pGuid) Continue
            Do tArr.%Push(tEntry)
        }
    } Catch {}
    Quit tArr
}

ClassMethod HistoryRow(pId As %String) As %DynamicObject
{
    Set tEntry = ""
    Try {
        Set tNode = $Get(^SYS("Task", "HistoryD", pId))
        If tNode = "" Return ""
        Set tLength = $ListLength(tNode)
        If tLength < 3 Return ""

        Set tArr = []
        For i = 1:1:tLength {
            Set tEl = $ListGet(tNode, i)
            If $IsObject(tEl) Set tEl = ""
            Do tArr.%Push(tEl)
        }

        Set tStart = ..SlotH(tArr, 5)
        Set tFinish = ..SlotH(tArr, 6)

        Set tResult = tArr.%Get(2)
        Set tResultU = $ZConvert(tResult, "U")

        ; name: completed entries carry the task name in slot 7; TASKMGR
        ; bookkeeping entries put the descriptive text in slot 3
        Set tName = tArr.%Get(6)
        If (tName = "") || (tName = "TASKMGR") {
            Set tName = tResult
        }

        Set tTaskClass = ""
        Set tSlot4 = tArr.%Get(3)
        If (tSlot4 [ ".") || (tSlot4 [ "%SYS") Set tTaskClass = tSlot4

        Set tRunAs = tArr.%Get(14)
        If tRunAs = "" Set tRunAs = tSlot4
        If (tRunAs [ ".") || (tRunAs = "") Set tRunAs = ""

        ; Map the result word to a status, surfacing failures as error
        Set tStatus = ""
        Set tError = ""
        If tResultU [ "SUCCESS" {
            Set tStatus = "Success"
        } ElseIf (tResultU [ "FAILED") || (tResultU [ "FAILURE") || (tResultU [ "ERROR") {
            Set tStatus = "Failed"
            Set tError = tResult
        } ElseIf tResultU [ "EXPIRED" {
            Set tStatus = "Failed"
            Set tError = tResult
        } ElseIf tResultU [ "SUSPENDED" {
            Set tStatus = "Suspended"
        } ElseIf tResultU [ "RESUMED" {
            Set tStatus = "Resumed"
        } ElseIf tResultU [ "SCHEDULING" {
            Set tStatus = "Scheduled"
        } ElseIf tResult '= "" {
            Set tStatus = tResult
        }

        Set tObj = {
            "guid":(pId),
            "name":(tName),
            "taskClass":(tTaskClass),
            "namespace":(tArr.%Get(7)),
            "runAsUser":(tRunAs),
            "status":(tStatus),
            "startTime":(##class(mp.util.json).StampFlex(tStart)),
            "finishTime":(##class(mp.util.json).StampFlex(tFinish)),
            "error":(tError),
            "output":""
        }
        Set tEntry = tObj
    } Catch {}
    Quit tEntry
}

ClassMethod SlotH(pArr, pIndex As %Integer) As %String
{
    Set tValue = ""
    Try {
        Set tEl = pArr.%Get(pIndex - 1)
        If tEl = "" Return ""
        Set tDays = ""
        Set tSecs = ""
        If $ListValid(tEl) {
            Set tDays = $ListGet(tEl, 1)
            Set tSecs = $ListGet(tEl, 2)
        } ElseIf tEl [ "," {
            Set tDays = +$Piece(tEl, ",", 1)
            Set tSecs = +$Piece(tEl, ",", 2)
        }
        If (tDays '= "") && (tSecs '= "") && (+tDays = tDays) && (+tSecs = tSecs) {
            If (+tDays > 0) && (+tDays < 1000000) && (+tSecs >= 0) && (+tSecs < 86400) {
                Set tValue = +tDays _ "," _ +tSecs
            }
        }
    } Catch {}
    Quit tValue
}

ClassMethod TaskName(pGuid As %String) As %String
{
    Set tName = ""
    Try {
        Set tTask = ##class(%SYS.Task).%OpenId(pGuid)
        If $IsObject(tTask) Set tName = ..Prop(tTask, "Name")
    } Catch {}
    Quit tName
}

}