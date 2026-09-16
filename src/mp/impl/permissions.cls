Class mp.impl.permissions Extends %RegisteredObject
{

ClassMethod Prop(pObj, pName As %String, pDefault = "") As %String
{
    Set tValue = pDefault
    Try { Set tValue = $Property(pObj, pName) } Catch {}
    Quit $Get(tValue)
}

/// List IRIS users with their roles.
ClassMethod Users() As %DynamicArray
{
    Set tArr = []
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Try {
        Set tRS = ##class(%SQL.Statement).%New().%ExecDirect(, "SELECT ID FROM Security.Users")
        While tRS.%Next() {
            Set tName = tRS.%Get("ID")
            If tName '= "" Do tArr.%Push(..UserRow(tName))
        }
    } Catch {}
    Set $Namespace = tNs
    Quit tArr
}

ClassMethod UserRow(pUsername As %String) As %DynamicObject
{
    Set tObj = {"username":(pUsername), "enabled":1, "fullName":"", "comment":"", "roles":[], "lastLogin":"", "userType":""}
    Try {
        Set tU = ##class(Security.Users).%OpenId(pUsername)
        If '$IsObject(tU) Return tObj
        Do tObj.%Set("enabled", +..Prop(tU, "Enabled", 1))
        Do tObj.%Set("fullName", ..Prop(tU, "FullName"))
        Do tObj.%Set("comment", ..Prop(tU, "Comment"))
        Do tObj.%Set("userType", ..Prop(tU, "UserType"))
        Do tObj.%Set("lastLogin", ##class(mp.util.json).Stamp(..Prop(tU, "LastUsedDate")))
        Set tRoles = []
        Try {
            If $IsObject(tU.Roles) {
                Set tCount = tU.Roles.Count()
                For r = 1:1:tCount {
                    Set tRole = tU.Roles.GetAt(r)
                    If tRole '= "" Do tRoles.%Push(tRole)
                }
            }
        } Catch {}
        Do tObj.%Set("roles", tRoles)
    } Catch {}
    Quit tObj
}

/// Replace a user's role assignments.
ClassMethod SetUserRoles(pUsername As %String, pRoles As %DynamicArray) As %Status
{
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Set tSC = $$$OK
    Try {
        Set tU = ##class(Security.Users).%OpenId(pUsername)
        If '$IsObject(tU) {
            Set tSC = $$$ERROR($$$GeneralError, "User not found: " _ pUsername)
        } Else {
            Set tSC = $$$OK
            Try {
                If $IsObject(tU.Roles) {
                    ; Note: Roles is a %Collection.ListOfDataTypes in this IRIS —
                    ; there is no RemoveAll(); use Clear() to empty it.
                    Set tSC = tU.Roles.Clear()
                    If '$$$ISERR(tSC) && $IsObject(pRoles) {
                        For i = 0:1:pRoles.%Size() - 1 {
                            Set tRole = pRoles.%Get(i)
                            If tRole '= "" Do tU.Roles.Insert(tRole)
                        }
                    }
                }
            } Catch {}
            If '$$$ISERR(tSC) Set tSC = tU.%Save()
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $Namespace = tNs
    Quit tSC
}

/// Convert a JSON roles array into an IRIS list.
ClassMethod RolesList(pRoles As %DynamicObject, ByRef pList) As %Status
{
    Set pList = $LB()
    If $IsObject(pRoles) {
        For i = 0:1:pRoles.%Size() - 1 {
            Set tRole = pRoles.%Get(i)
            If tRole '= "" Set pList = pList _ $ListBuild(tRole)
        }
    }
    Quit $$$OK
}

/// Create a user from a JSON property bag.
ClassMethod CreateUser(pProps As %DynamicObject) As %Status
{
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Set tSC = $$$OK
    Try {
        Set tUsername = ##class(mp.util.json).DynVal(pProps, "username", "")
        If tUsername = "" {
            Set tSC = $$$ERROR($$$GeneralError, "username is required")
        } Else {
            If ##class(Security.Users).%ExistsId(tUsername) {
                Set tSC = $$$ERROR($$$GeneralError, "User already exists: " _ tUsername)
            } Else {
                Set tU = ##class(Security.Users).%New()
                Set tU.Name = tUsername
                Set tU.FullName = ##class(mp.util.json).DynVal(pProps, "fullName", "")
                Set tU.Comment = ##class(mp.util.json).DynVal(pProps, "comment", "")
                Set tU.Enabled = +##class(mp.util.json).DynVal(pProps, "enabled", 1)
                Set tPassword = ##class(mp.util.json).DynVal(pProps, "password", "")
                If tPassword '= "" Set tU.Password = tPassword
                ; persist first, then assign roles to the now-existing user
                Set tSC = tU.%Save()
                If '$$$ISERR(tSC) && pProps.%IsDefined("roles") && $IsObject(pProps.roles) {
                    Set tSC = ..SetUserRoles(tUsername, pProps.roles)
                    If '$$$ISERR(tSC) {
                        Set tU2 = ##class(Security.Users).%OpenId(tUsername)
                        If $IsObject(tU2) Set tSC = tU2.%Save()
                    }
                }
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $Namespace = tNs
    Quit tSC
}

/// Update basic user fields from a JSON property bag.
ClassMethod UpdateUser(pUsername As %String, pProps As %DynamicObject) As %Status
{
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Set tSC = $$$OK
    Try {
        Set tU = ##class(Security.Users).%OpenId(pUsername)
        If '$IsObject(tU) {
            Set tSC = $$$ERROR($$$GeneralError, "User not found: " _ pUsername)
        } Else {
            If pProps.%IsDefined("fullName") Set tU.FullName = pProps.fullName
            If pProps.%IsDefined("comment") Set tU.Comment = pProps.comment
            If pProps.%IsDefined("enabled") Set tU.Enabled = +pProps.enabled
            If pProps.%IsDefined("password") && pProps.password '= "" Set tU.Password = pProps.password
            If pProps.%IsDefined("roles") && $IsObject(pProps.roles) {
                Set tSC = ..SetUserRoles(pUsername, pProps.roles)
                If '$$$ISERR(tSC) Set tSC = tU.%Save()
            } Else {
                Set tSC = tU.%Save()
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $Namespace = tNs
    Quit tSC
}

/// Enable or disable a user.
ClassMethod SetUserEnabled(pUsername As %String, pEnabled As %Boolean) As %Status
{
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Set tSC = $$$OK
    Try {
        Set tU = ##class(Security.Users).%OpenId(pUsername)
        If '$IsObject(tU) {
            Set tSC = $$$ERROR($$$GeneralError, "User not found: " _ pUsername)
        } Else {
            Set tU.Enabled = +pEnabled
            Set tSC = tU.%Save()
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $Namespace = tNs
    Quit tSC
}

/// List roles with their resource permissions.
ClassMethod Roles() As %DynamicArray
{
    Set tArr = []
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Try {
        Set tRS = ##class(%SQL.Statement).%New().%ExecDirect(, "SELECT ID FROM Security.Roles")
        While tRS.%Next() {
            Set tName = tRS.%Get("ID")
            If tName = "" Continue
            Set tObj = {"name":(tName), "description":"", "resources":[]}
            Try {
                Set tR = ##class(Security.Roles).%OpenId(tName)
                If $IsObject(tR) {
                    Do tObj.%Set("description", ..Prop(tR, "Description"))
                    Set tRes = []
                    Set tKey = ""
                    For {
                        Set tKey = tR.Resources.GetNext(tKey)
                        Quit:tKey=""
                        Do tRes.%Push({"resource":(tKey), "permission":($Get(tR.Resources.GetAt(tKey)))})
                    }
                    Do tObj.%Set("resources", tRes)
                }
            } Catch {}
            Do tArr.%Push(tObj)
        }
    } Catch {}
    Set $Namespace = tNs
    Quit tArr
}

/// List security resources.
ClassMethod Resources() As %DynamicArray
{
    Set tArr = []
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Try {
        Set tRS = ##class(%SQL.Statement).%New().%ExecDirect(, "SELECT ID FROM Security.Resources")
        While tRS.%Next() {
            Set tName = tRS.%Get("ID")
            If tName = "" Continue
            Set tObj = {"name":(tName), "description":"", "publicPermission":"", "type":""}
            Try {
                Set tR = ##class(Security.Resources).%OpenId(tName)
                If $IsObject(tR) {
                    Do tObj.%Set("description", ..Prop(tR, "Description"))
                    Do tObj.%Set("publicPermission", ..Prop(tR, "PublicPermission"))
                    Do tObj.%Set("type", ..Prop(tR, "Type"))
                }
            } Catch {}
            Do tArr.%Push(tObj)
        }
    } Catch {}
    Set $Namespace = tNs
    Quit tArr
}

}