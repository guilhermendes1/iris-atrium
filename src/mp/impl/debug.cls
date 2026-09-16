Class mp.impl.debug Extends %RegisteredObject
{

ClassMethod HistoryD() As %String
{
    Set tOut = ""
    Set tId = ""
    For {
        Set tId = $Order(^SYS("Task", "HistoryD", tId), -1)
        Quit:tId=""
        If tId < 48 Quit
        Set tNode = $Get(^SYS("Task", "HistoryD", tId))
        Set tLen = $ListLength(tNode)
        Set tOut = tOut _ "ID=" _ tId _ " LN=" _ tLen _ "; "
        For i = 1:1:tLen {
            Set tEl = $ListGet(tNode, i)
            If $ListValid(tEl) {
                Set tOut = tOut _ "S" _ i _ "=LIST(" _ $ListGet(tEl,1) _ "," _ $ListGet(tEl,2) _ "); "
            } Else {
                Set tOut = tOut _ "S" _ i _ "=[" _ $Extract(tEl, 1, 40) _ "]; "
            }
        }
        Set tOut = tOut _ $Char(10)
    }
    Quit tOut
}

ClassMethod SetRole(pUser, pRole) As %String
{
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tU = ##class(Security.Users).%OpenId(pUser)
    If '$IsObject(tU) Quit "OPEN_FAILED"
    Write "BEFORE_COUNT=",tU.Roles.Count(),!
    Set tSC = tU.Roles.Clear()
    Write "CLEAR_SC=",tSC,!
    Set tSC2 = tU.Roles.Insert(pRole)
    Write "INSERT_SC=",tSC2,!
    Set tSC3 = tU.%Save()
    Write "SAVE_SC=",tSC3,!
    Write "AFTER_COUNT=",tU.Roles.Count(),!
    For r=1:1:tU.Roles.Count() { Write "ROLE",r,"=",tU.Roles.GetAt(r),! }
    Quit "OK"
}

ClassMethod AddRole(pUser, pRole) As %String
{
    New $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tU = ##class(Security.Users).%OpenId(pUser)
    If '$IsObject(tU) Quit "OPEN_FAILED"
    Set tSC = tU.Roles.Insert(pRole)
    Write "INSERT_SC=",tSC,!
    Set tSC2 = tU.%Save()
    Write "SAVE_SC=",tSC2,!
    Write "AFTER_COUNT=",tU.Roles.Count(),!
    Quit "OK "
}

ClassMethod ProbeSub(pId As %String) As %String
{
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(^SYS("Task", "HistoryD", pId, tKey))
        Quit:tKey=""
        Set tSub = ""
        For {
            Set tSub = $Order(^SYS("Task", "HistoryD", pId, tKey, tSub))
            Quit:tSub=""
            Set tVal = $Get(^SYS("Task", "HistoryD", pId, tKey, tSub))
            Set tOut = tOut _ "K=" _ tKey _ " S=" _ tSub _ " V=" _ tVal _ "; "
        }
        If tKey = "" Quit
    }
    Quit tOut
}

ClassMethod TaskInfo(pId As %String) As %String
{
    Set tOut = ""
    Set tTask = ##class(%SYS.Task).%OpenId(pId)
    If '$IsObject(tTask) Quit "NOT_FOUND"
    Set tOut = "NAME=" _ $Property(tTask, "Name") _ "; "
    Set tOut = tOut _ "SUSPENDED=" _ $Property(tTask, "Suspended") _ "; "
    Set tOut = tOut _ "STATUS=" _ $Property(tTask, "Status") _ "; "
    Set tOut = tOut _ "ERROR=" _ $Property(tTask, "Error") _ "; "
    Set tOut = tOut _ "DISPFINISHED=" _ $Property(tTask, "DisplayFinished") _ "; "
    Set tOut = tOut _ "DISPRUN=" _ $Property(tTask, "DisplayRun") _ "; "
    Set tOut = tOut _ "LASTSTART=" _ $Property(tTask, "LastStarted") _ "; "
    Set tOut = tOut _ "LASTFINISH=" _ $Property(tTask, "LastFinished") _ "; "
    Set tOut = tOut _ "NAMESPACE=" _ $Property(tTask, "NameSpace") _ "; "
    Set tOut = tOut _ "RUNAS=" _ $Property(tTask, "RunAsUser") _ "; "
    Set tOut = tOut _ "TASKCLASS=" _ $Property(tTask, "TaskClass") _ "; "
    Set tOut = tOut _ "TYPE=" _ $Property(tTask, "Type") _ "; "
    Set tOut = tOut _ "TIMEINTERVAL=" _ $Property(tTask, "TimePeriodEvery") _ "; "
    Set tOut = tOut _ "DAILYFREQ=" _ $Property(tTask, "DailyFrequency") _ "; "
    Quit tOut
}

ClassMethod RunNow(pId As %String) As %String
{
    Set tTask = ##class(%SYS.Task).%OpenId(pId)
    If '$IsObject(tTask) Quit "NOT_FOUND"
    Set tSC = tTask.%Save()
    Quit "SC=" _ tSC
}

ClassMethod HistoryOne(pId As %String) As %String
{
    Set tOut = ""
    Set tNode = $Get(^SYS("Task", "HistoryD", pId))
    If tNode = "" Quit "EMPTY"
    Set tLen = $ListLength(tNode)
    For i = 1:1:tLen {
        Set tEl = $ListGet(tNode, i)
        If $ListValid(tEl) {
            Set tOut = tOut _ "S" _ i _ "=LIST(" _ $ListGet(tEl,1) _ "," _ $ListGet(tEl,2) _ "); "
        } Else {
            Set tOut = tOut _ "S" _ i _ "=[" _ $Extract(tEl, 1, 80) _ "]; "
        }
    }
    Quit tOut
}

ClassMethod SSLNames() As %String
{
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(^SYS("Security", "SSLConfigs", tKey))
        Quit:tKey=""
        Set tOut = tOut _ "K=[" _ tKey _ "] "
    }
    Quit tOut
}

ClassMethod ClassInfo(pCls As %String) As %String
{
    Set tOut = ""
    Set tC = ##class(%Dictionary.CompiledClass).%OpenId(pCls)
    If '$IsObject(tC) Quit "NO_CLASS"
    Set tOut = tOut _ "PROPS=" _ tC.Properties.Count() _ "; "
    For i = 1:1:tC.Properties.Count() {
        Set tP = tC.Properties.GetAt(i)
        Set tOut = tOut _ tP.Name _ "(" _ tP.Type _ "); "
    }
    Quit tOut
}

ClassMethod TaskMethods(pCls As %String) As %String
{
    Set tOut = ""
    Set tC = ##class(%Dictionary.CompiledClass).%OpenId(pCls)
    If '$IsObject(tC) Quit "NO_CLASS"
    For i = 1:1:tC.Methods.Count() {
        Set tM = tC.Methods.GetAt(i)
        Set tOut = tOut _ tM.Name _ "; "
    }
    Quit tOut
}

ClassMethod TestRunNow(pId As %String) As %String
{
    Set tOut = ""
    Set tTask = ##class(%SYS.Task).%OpenId(pId)
    If '$IsObject(tTask) Quit "NOT_FOUND"
    Try {
        Set tSC = tTask.RunNow()
        Set tOut = tOut _ "RUNNOW_SC=" _ tSC _ "; "
    } Catch ex {
        Set tOut = tOut _ "RUNNOW_ERR=" _ ex.DisplayString() _ "; "
    }
    Quit tOut
}

ClassMethod TestSuspendResume(pId As %String) As %String
{
    Set tOut = ""
    Set tTask = ##class(%SYS.Task).%OpenId(pId)
    If '$IsObject(tTask) Quit "NOT_FOUND"
    Try {
        Set tSC = tTask.Suspend()
        Set tOut = tOut _ "SUSP_SC=" _ tSC _ "; "
    } Catch ex {
        Set tOut = tOut _ "SUSP_ERR=" _ ex.DisplayString() _ "; "
    }
    Set tTask2 = ##class(%SYS.Task).%OpenId(pId)
    Try {
        Set tSC2 = tTask2.Resume()
        Set tOut = tOut _ "RESUME_SC=" _ tSC2 _ "; "
    } Catch ex {
        Set tOut = tOut _ "RESUME_ERR=" _ ex.DisplayString() _ "; "
    }
    Quit tOut
}

ClassMethod TestClassRunNow(pId As %String) As %String
{
    Set tOut = ""
    Try {
        Set tSC = ##class(%SYS.Task).RunNow(pId)
        Set tOut = tOut _ "CM_RUNNOW=" _ tSC _ "; "
    } Catch ex {
        Set tOut = tOut _ "CM_RUNNOW_ERR=" _ ex.DisplayString() _ "; "
    }
    Quit tOut
}

ClassMethod ClassSuspend(pId As %String) As %String
{
    Set tOut = ""
    Try {
        Set tSC = ##class(%SYS.Task).Suspend(pId)
        Set tOut = tOut _ "SUSP=" _ tSC _ "; "
    } Catch ex {
        Set tOut = tOut _ "SUSP_ERR=" _ ex.DisplayString() _ "; "
    }
    Quit tOut
}

ClassMethod ClassResume(pId As %String) As %String
{
    Set tOut = ""
    Try {
        Set tSC = ##class(%SYS.Task).Resume(pId)
        Set tOut = tOut _ "RESUME=" _ tSC _ "; "
    } Catch ex {
        Set tOut = tOut _ "RESUME_ERR=" _ ex.DisplayString() _ "; "
    }
    Quit tOut
}

ClassMethod TestRunTask(pId As %String) As %String
{
    Set tOut = ""
    Set tTask = ##class(%SYS.Task).%OpenId(pId)
    If '$IsObject(tTask) Quit "NOT_FOUND"
    Try {
        Set tSC = tTask.RunTask()
        Set tOut = tOut _ "RUNTASK=" _ tSC _ "; "
    } Catch ex {
        Set tOut = tOut _ "RUNTASK_ERR=" _ ex.DisplayString() _ "; "
    }
    Quit tOut
}

ClassMethod StatusProbe(pId As %String) As %String
{
    Set tOut = ""
    Set tTask = ##class(%SYS.Task).%OpenId(pId)
    If '$IsObject(tTask) Quit "NOT_FOUND"
    Set tRaw = $Property(tTask, "Status")
    Set tOut = tOut _ "STATUS_RAW=" _ tRaw _ "; "
    Try {
        Set tOut = tOut _ "STATUS_TEXT=" _ tTask.StatusAsText() _ "; "
    } Catch ex {
        Set tOut = tOut _ "STATUS_TEXT_ERR=" _ ex.DisplayString() _ "; "
    }
    Set tOut = tOut _ "DISPLAY_STATUS=" _ $Property(tTask, "DisplayStatus") _ "; "
    Set tOut = tOut _ "DISPLAY_RUN=" _ $Property(tTask, "DisplayRun") _ "; "
    Set tOut = tOut _ "DISPLAY_NEXT=" _ $Property(tTask, "DisplayNextScheduled") _ "; "
    Set tOut = tOut _ "DISP_NEXT_BRIEF=" _ $Property(tTask, "DisplayNextScheduledBrief") _ "; "
    Quit tOut
}

ClassMethod MethodFlags(pCls As %String, pFilter As %String) As %String
{
    Set tOut = ""
    Set tC = ##class(%Dictionary.CompiledClass).%OpenId(pCls)
    If '$IsObject(tC) Quit "NO_CLASS"
    For i = 1:1:tC.Methods.Count() {
        Set tM = tC.Methods.GetAt(i)
        Set tName = tM.Name
        If (pFilter '= "") && (tName '[ pFilter) Continue
        Set tIsClass = tM.ClassMethod
        Set tOut = tOut _ tName _ "(CM=" _ tIsClass _ "); "
    }
    Quit tOut
}

}