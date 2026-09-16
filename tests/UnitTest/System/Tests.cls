Class UnitTest.System.Tests Extends %UnitTest.TestCase
{

Method TestMetricsShape()
{
    Set tObj = ##class(mp.impl.system).Metrics()
    Do $$$AssertTrue($IsObject(tObj), "Metrics returns an object")
    Do $$$AssertTrue(tObj.%IsDefined("cpuPercent"), "Has cpuPercent")
    Do $$$AssertTrue(tObj.%IsDefined("memoryTotalKB"), "Has memoryTotalKB")
    Do $$$AssertTrue(tObj.%IsDefined("memoryUsedKB"), "Has memoryUsedKB")
    Do $$$AssertTrue(tObj.%IsDefined("memoryPercent"), "Has memoryPercent")
    Do $$$AssertTrue(tObj.%IsDefined("uptimeSeconds"), "Has uptimeSeconds")
}

Method TestDisks()
{
    Set tArr = ##class(mp.impl.system).Disks()
    Do $$$AssertTrue($IsObject(tArr), "Disks returns a JSON array")
}

Method TestNamespaces()
{
    Set tArr = ##class(mp.impl.system).Namespaces()
    Do $$$AssertTrue($IsObject(tArr), "Namespaces returns a JSON array")
}

Method TestProcesses()
{
    Set tArr = ##class(mp.impl.system).Processes("")
    Do $$$AssertTrue($IsObject(tArr), "Processes returns a JSON array")
}

}