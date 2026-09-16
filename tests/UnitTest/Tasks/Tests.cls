Class UnitTest.Tasks.Tests Extends %UnitTest.TestCase
{

Method TestTasksList()
{
    Set tArr = ##class(mp.impl.tasks).Tasks()
    Do $$$AssertTrue($IsObject(tArr), "Tasks returns a JSON array")
    If tArr.%Size() > 0 {
        Set tItem = tArr.%Get(0)
        Do $$$AssertTrue(tItem.%IsDefined("guid"), "Task has guid")
        Do $$$AssertTrue(tItem.%IsDefined("name"), "Task has name")
        Do $$$AssertTrue(tItem.%IsDefined("status"), "Task has status")
        Do $$$AssertTrue(tItem.%IsDefined("enabled"), "Task has enabled")
    }
}

Method TestHistoryIsArray()
{
    Set tArr = ##class(mp.impl.tasks).History("")
    Do $$$AssertTrue($IsObject(tArr), "History returns a JSON array")
}

Method TestSuspendResumeIdempotent()
{
    Set tArr = ##class(mp.impl.tasks).Tasks()
    If tArr.%Size() = 0 Quit
    Set tGuid = tArr.%Get(0).guid
    Set tEnabled = tArr.%Get(0).enabled
    If tEnabled {
        Set tSC = ##class(mp.impl.tasks).SetSuspended(tGuid, 1)
        Do $$$AssertStatusOK(tSC, "Suspend succeeds")
        Set tSC = ##class(mp.impl.tasks).SetSuspended(tGuid, 0)
        Do $$$AssertStatusOK(tSC, "Resume succeeds")
    } Else {
        Set tSC = ##class(mp.impl.tasks).SetSuspended(tGuid, 0)
        Do $$$AssertStatusOK(tSC, "Resume succeeds")
        Set tSC = ##class(mp.impl.tasks).SetSuspended(tGuid, 1)
        Do $$$AssertStatusOK(tSC, "Suspend succeeds")
    }
}

}