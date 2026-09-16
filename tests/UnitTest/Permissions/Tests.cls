Class UnitTest.Permissions.Tests Extends %UnitTest.TestCase
{

Method TestUsersList()
{
    Set tArr = ##class(mp.impl.permissions).Users()
    Do $$$AssertTrue($IsObject(tArr), "Users returns a JSON array")
}

Method TestRolesList()
{
    Set tArr = ##class(mp.impl.permissions).Roles()
    Do $$$AssertTrue($IsObject(tArr), "Roles returns a JSON array")
}

Method TestResourcesList()
{
    Set tArr = ##class(mp.impl.permissions).Resources()
    Do $$$AssertTrue($IsObject(tArr), "Resources returns a JSON array")
}

Method TestRoleUpdateIsIdempotent()
{
    Set tUsers = ##class(mp.impl.permissions).Users()
    If tUsers.%Size() = 0 {
        Do $$$AssertTrue(1, "No users exposed by this environment")
        Quit
    }
    Set tUsername = tUsers.%Get(0).username
    Do $$$AssertNotEquals("", $Get(tUsername), "Resolved a user to test with")
    Set tRoles = tUsers.%Get(0).roles
    Set tSC = ##class(mp.impl.permissions).SetUserRoles(tUsername, tRoles)
    Do $$$AssertStatusOK(tSC, "Re-applying the same roles succeeds")
}

}