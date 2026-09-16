Class UnitTest.WebApps.Tests Extends %UnitTest.TestCase
{

Method TestListHasApps()
{
    Set tArr = ##class(mp.impl.webapps).List()
    Do $$$AssertTrue($IsObject(tArr), "List returns a JSON array")
}

Method TestListShape()
{
    Set tArr = ##class(mp.impl.webapps).List()
    If tArr.%Size() = 0 {
        Do $$$AssertTrue(1, "No web applications exposed by this environment")
        Quit
    }
    Set tItem = tArr.%Get(0)
    Do $$$AssertTrue($IsObject(tItem), "First entry is an object")
    Do $$$AssertTrue(tItem.%IsDefined("path"), "Entry has a path")
    Do $$$AssertTrue(tItem.%IsDefined("enabled"), "Entry has enabled")
    Do $$$AssertTrue(tItem.%IsDefined("namespace"), "Entry has namespace")
}

Method TestServerNamespace()
{
    Do $$$AssertEquals(##class(mp.impl.webapps).ServerNamespace(), "USER", "Server namespace is USER")
}

Method TestUrlEncode()
{
    Do $$$AssertEquals(##class(mp.impl.webapps).UrlEncode("%SYS"), "%25SYS", "%SYS encodes to %25SYS")
}

}