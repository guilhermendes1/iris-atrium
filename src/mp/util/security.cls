Class mp.util.security Extends %RegisteredObject
{

/// Extract Basic credentials from the Authorization header
ClassMethod GetCredentials(Output pUser As %String, Output pPassword As %String) As %Status
{
    Set pUser = "", pPassword = ""
    Set tHeader = ""
    Try { Set tHeader = %request.CgiEnvs("HTTP_AUTHORIZATION") } Catch {}
    If tHeader = "" Try { Set tHeader = %request.GetHeader("Authorization") } Catch {}
    If tHeader = "" Quit $$$ERROR($$$GeneralError, "Missing Authorization header")
    If $ZConvert($Extract(tHeader, 1, 6), "L") '= "basic " Quit $$$ERROR($$$GeneralError, "Unsupported authorization scheme")
    Set tDec = ##class(%SYSTEM.Encryption).Base64Decode($ZStrip($Extract(tHeader, 7, *), "<>W"))
    Set tPos = $Find(tDec, ":", 1)
    If 'tPos Quit $$$ERROR($$$GeneralError, "Malformed Authorization header")
    Set pUser = $Extract(tDec, 1, tPos - 2)
    Set pPassword = $Extract(tDec, tPos, $Length(tDec))
    Quit $$$OK
}

/// Authenticate a user in the current process (IRIS credential store)
ClassMethod Authenticate(pUser As %String, pPassword As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ##class(%SYSTEM.Security).Login(pUser, pPassword)
    } Catch ex {
        Return ex.AsStatus()
    }
    Quit tSC
}

/// Name of the current process user
ClassMethod Username() As %String
{
    Set tName = ""
    Try { Set tName = $UserName } Catch {}
    Quit tName
}

/// Whether the current process user holds a permission on a resource
ClassMethod Check(pResource As %String, pPermission As %String = "USE") As %Boolean
{
    Set tOk = 0
    Try {
        If pResource = "" Set tOk = 1
        If pResource '= "" Set tOk = ##class(%SYSTEM.Security).Check(pResource, pPermission)
    } Catch { Set tOk = 0 }
    Quit tOk
}

/// Authenticate from the request headers and enforce an optional resource gate.
/// On failure writes a JSON error response and returns an error %Status.
ClassMethod Guard(pResource As %String = "%Admin_Manage", pPermission As %String = "USE") As %Status
{
    Set tSC = ..GetCredentials(.tUser, .tPass)
    If $$$ISERR(tSC) {
        Do ##class(mp.util.json).SendError("UNAUTHORIZED", "Authentication required. Provide Basic credentials.")
        Quit $$$ERROR($$$AccessDenied)
    }
    Set tSC = ..Authenticate(tUser, tPass)
    If $$$ISERR(tSC) {
        Do ##class(mp.util.json).SendError("UNAUTHORIZED", "Invalid username or password")
        Quit $$$ERROR($$$AccessDenied)
    }
    If '..Check(pResource, pPermission) {
        Do ##class(mp.util.json).SendError("PERMISSION_DENIED", "Permission " _ pPermission _ " on resource " _ pResource _ " is required")
        Quit $$$ERROR($$$AccessDenied)
    }
    Quit $$$OK
}

}