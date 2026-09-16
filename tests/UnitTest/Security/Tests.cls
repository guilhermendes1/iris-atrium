Class UnitTest.Security.Tests Extends %UnitTest.TestCase
{

Method TestCredentialsShape()
{
    Set tArr = ##class(mp.impl.security).Credentials("all")
    Do $$$AssertTrue($IsObject(tArr), "Credentials returns a JSON array")
    If tArr.%Size() > 0 {
        Set tItem = tArr.%Get(0)
        Do $$$AssertTrue(tItem.%IsDefined("alias"), "Credential has alias")
        Do $$$AssertTrue(tItem.%IsDefined("type"), "Credential has type")
    }
}

Method TestCategoryListsAreArrays()
{
    Set tSsl = ##class(mp.impl.security).ListSSL()
    Do $$$AssertTrue($IsObject(tSsl), "SSL list is a JSON array")
    Set tX509 = ##class(mp.impl.security).ListX509()
    Do $$$AssertTrue($IsObject(tX509), "X509 list is a JSON array")
}

Method TestDetailReturnsObject()
{
    Set tObj = ##class(mp.impl.security).Detail("ssl", "missing-alias")
    Do $$$AssertTrue($IsObject(tObj), "Detail returns an object even for a missing alias")
    Do $$$AssertEquals(tObj.alias, "missing-alias", "Alias is echoed")
}

}