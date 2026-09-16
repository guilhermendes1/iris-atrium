Class mp.disp Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

Parameter CONTENTTYPE = "application/json";

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
  <!-- Session -->
  <Route Url="/login" Method="POST" Call="SessionLogin"/>
  <Route Url="/logout" Method="POST" Call="SessionLogout"/>
  <Route Url="/session" Method="GET" Call="SessionInfo"/>

  <!-- Web Apps & REST explorer -->
  <Route Url="/webapps/spec" Method="GET" Call="WebAppsSpec"/>
  <Route Url="/webapps/installed" Method="GET" Call="WebAppsInstalled"/>
  <Route Url="/webapps" Method="DELETE" Call="WebAppsDelete"/>
  <Route Url="/webapps" Method="POST" Call="WebAppsCreate"/>
  <Route Url="/webapps" Method="PUT" Call="WebAppsModify"/>
  <Route Url="/webapps" Method="GET" Call="WebAppsList"/>

  <!-- Permissions -->
  <Route Url="/users/:username/roles" Method="PUT" Call="UsersRolesPut"/>
  <Route Url="/users/:username/enabled" Method="PUT" Call="UsersEnabledPut"/>
  <Route Url="/users/:username" Method="PUT" Call="UsersPut"/>
  <Route Url="/users" Method="POST" Call="UsersPost"/>
  <Route Url="/users" Method="GET" Call="UsersList"/>
  <Route Url="/roles" Method="GET" Call="RolesList"/>
  <Route Url="/resources" Method="GET" Call="ResourcesList"/>

  <!-- Security & Secrets -->
  <Route Url="/security/credentials/:type/:alias" Method="GET" Call="CredentialsDetail"/>
  <Route Url="/security/credentials/:type" Method="GET" Call="CredentialsByType"/>
  <Route Url="/security/credentials" Method="GET" Call="CredentialsList"/>

  <!-- Tasks -->
  <Route Url="/tasks/history" Method="GET" Call="TasksHistory"/>
  <Route Url="/tasks/:guid/run" Method="POST" Call="TasksRun"/>
  <Route Url="/tasks/:guid/suspend" Method="PUT" Call="TasksSuspend"/>
  <Route Url="/tasks/:guid/resume" Method="PUT" Call="TasksResume"/>
  <Route Url="/tasks" Method="GET" Call="TasksList"/>

  <!-- System / OS -->
  <Route Url="/system/processes/:pid/terminate" Method="POST" Call="SystemTerminate"/>
  <Route Url="/system/metrics" Method="GET" Call="SystemMetrics"/>
  <Route Url="/system/disks" Method="GET" Call="SystemDisks"/>
  <Route Url="/system/namespaces" Method="GET" Call="SystemNamespaces"/>
  <Route Url="/system/processes" Method="GET" Call="SystemProcesses"/>

  <!-- Logs -->
  <Route Url="/logs/sources" Method="GET" Call="LogsSources"/>
  <Route Url="/logs/export" Method="GET" Call="LogsExport"/>
  <Route Url="/logs" Method="GET" Call="LogsQuery"/>
</Routes>
}

/// Parse the JSON request body into a dynamic object.
ClassMethod ReadObj(Output pObj) As %Status
{
    Set pObj = ""
    Set tBody = ##class(mp.util.json).ReadBody()
    Try {
        Set pObj = ##class(%DynamicObject).%FromJSON(tBody)
        If '$IsObject(pObj) Return $$$ERROR($$$GeneralError, "Request body must be a JSON object")
    } Catch ex {
        Return $$$ERROR($$$GeneralError, "Invalid JSON request body")
    }
    Quit $$$OK
}

/// Convenience: reject the request when the guard already wrote the error response.
ClassMethod Guarded(pResource As %String, pPermission As %String = "USE") As %Status
{
    Set tSC = ##class(mp.util.security).Guard(pResource, pPermission)
    If $$$ISERR(tSC) Quit $$$ERROR($$$AccessDenied)
    Quit $$$OK
}

// ---------------------------------------------------------------------------
// Session
// ---------------------------------------------------------------------------

ClassMethod SessionLogin() As %Status
{
    Set tSC = ..ReadObj(.tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Set tUser = ##class(mp.util.json).DynVal(tBody, "username")
    Set tPass = ##class(mp.util.json).DynVal(tBody, "password")
    If tUser = "" Do ##class(mp.util.json).SendError("BAD_REQUEST", "username is required") Quit $$$OK
    Set tSC = ##class(mp.impl.session).Validate(tUser, tPass)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("UNAUTHORIZED", "Invalid username or password") Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod SessionLogout() As %Status
{
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod SessionInfo() As %Status
{
    Set tSC = ..Guarded("")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.session).Current())
    Quit $$$OK
}

// ---------------------------------------------------------------------------
// Web Apps (US1)
// ---------------------------------------------------------------------------

ClassMethod WebAppsList() As %Status
{
    Set tSC = ..Guarded("%Admin_Manage")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.webapps).List())
    Quit $$$OK
}

ClassMethod WebAppsInstalled() As %Status
{
    Set tSC = ..Guarded("%Admin_Manage")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ##class(mp.util.security).GetCredentials(.tUser, .tPass)
    If $$$ISERR(tSC) Quit $$$OK
    Set tNs = $Get(%request.Data("ns", 1))
    Do ##class(mp.util.json).Send(##class(mp.impl.webapps).InstalledApps(tUser, tPass, tNs))
    Quit $$$OK
}

ClassMethod WebAppsSpec() As %Status
{
    Set tSC = ..Guarded("%Admin_Manage")
    If $$$ISERR(tSC) Quit $$$OK
    Set tNs = $Get(%request.Data("ns", 1))
    Set tApp = $Get(%request.Data("app", 1))
    If tApp = "" Do ##class(mp.util.json).SendError("BAD_REQUEST", "app is required") Quit $$$OK
    Set tSC = ##class(mp.util.security).GetCredentials(.tUser, .tPass)
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).SendRaw(##class(mp.impl.webapps).AppSpec(tNs, tApp, tUser, tPass))
    Quit $$$OK
}

ClassMethod WebAppsCreate() As %Status
{
    Set tSC = ..Guarded("%Admin_Manage")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ..ReadObj(.tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Set tName = ##class(mp.util.json).DynVal(tBody, "name")
    If tName = "" Do ##class(mp.util.json).SendError("BAD_REQUEST", "name is required") Quit $$$OK
    Set tSC = ##class(mp.impl.webapps).CreateApp(tName, tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("CONFLICT", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod WebAppsModify() As %Status
{
    Set tSC = ..Guarded("%Admin_Manage")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ..ReadObj(.tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Set tName = ##class(mp.util.json).DynVal(tBody, "name")
    If tName = "" Do ##class(mp.util.json).SendError("BAD_REQUEST", "name is required") Quit $$$OK
    Set tSC = ##class(mp.impl.webapps).ModifyApp(tName, tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod WebAppsDelete() As %Status
{
    Set tSC = ..Guarded("%Admin_Manage")
    If $$$ISERR(tSC) Quit $$$OK
    Set tName = $Get(%request.Data("name", 1))
    If tName = "" Do ##class(mp.util.json).SendError("BAD_REQUEST", "name is required") Quit $$$OK
    Set tSC = ##class(mp.impl.webapps).DeleteApp(tName)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("NOT_FOUND", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

// ---------------------------------------------------------------------------
// Permissions (US2)
// ---------------------------------------------------------------------------

ClassMethod UsersList() As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.permissions).Users())
    Quit $$$OK
}

ClassMethod UsersRolesPut(pUsername As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ..ReadObj(.tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Set tRoles = ##class(mp.util.json).DynVal(tBody, "roles", "[]")
    Set tSC = ##class(mp.impl.permissions).SetUserRoles(pUsername, tRoles)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod UsersEnabledPut(pUsername As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ..ReadObj(.tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Set tEnabled = +##class(mp.util.json).DynVal(tBody, "enabled", 1)
    Set tSC = ##class(mp.impl.permissions).SetUserEnabled(pUsername, tEnabled)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod UsersPut(pUsername As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ..ReadObj(.tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Set tSC = ##class(mp.impl.permissions).UpdateUser(pUsername, tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod UsersPost() As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ..ReadObj(.tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Set tSC = ##class(mp.impl.permissions).CreateUser(tBody)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("CONFLICT", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod RolesList() As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.permissions).Roles())
    Quit $$$OK
}

ClassMethod ResourcesList() As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.permissions).Resources())
    Quit $$$OK
}

// ---------------------------------------------------------------------------
// Security & Secrets (US3)
// ---------------------------------------------------------------------------

ClassMethod CredentialsList() As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.security).Credentials("all"))
    Quit $$$OK
}

ClassMethod CredentialsByType(pType As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.security).Credentials(pType))
    Quit $$$OK
}

ClassMethod CredentialsDetail(pType As %String, pAlias As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Secure")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.security).Detail(pType, pAlias))
    Quit $$$OK
}

// ---------------------------------------------------------------------------
// Tasks (US4)
// ---------------------------------------------------------------------------

ClassMethod TasksList() As %Status
{
    Set tSC = ..Guarded("%Admin_Tasks")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.tasks).Tasks())
    Quit $$$OK
}

ClassMethod TasksHistory() As %Status
{
    Set tSC = ..Guarded("%Admin_Tasks")
    If $$$ISERR(tSC) Quit $$$OK
    Set tGuid = $Get(%request.Data("guid", 1))
    Do ##class(mp.util.json).Send(##class(mp.impl.tasks).History(tGuid))
    Quit $$$OK
}

ClassMethod TasksRun(pGuid As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Tasks")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ##class(mp.impl.tasks).RunNow(pGuid)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod TasksSuspend(pGuid As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Tasks")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ##class(mp.impl.tasks).SetSuspended(pGuid, 1)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

ClassMethod TasksResume(pGuid As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Tasks")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ##class(mp.impl.tasks).SetSuspended(pGuid, 0)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

// ---------------------------------------------------------------------------
// System (US5)
// ---------------------------------------------------------------------------

ClassMethod SystemMetrics() As %Status
{
    Set tSC = ..Guarded("%Admin_Operate")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.system).Metrics())
    Quit $$$OK
}

ClassMethod SystemDisks() As %Status
{
    Set tSC = ..Guarded("%Admin_Operate")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.system).Disks())
    Quit $$$OK
}

ClassMethod SystemNamespaces() As %Status
{
    Set tSC = ..Guarded("%Admin_Operate")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.system).Namespaces())
    Quit $$$OK
}

ClassMethod SystemProcesses() As %Status
{
    Set tSC = ..Guarded("%Admin_Operate")
    If $$$ISERR(tSC) Quit $$$OK
    Set tNs = $Get(%request.Data("namespace", 1))
    Do ##class(mp.util.json).Send(##class(mp.impl.system).Processes(tNs))
    Quit $$$OK
}

ClassMethod SystemTerminate(pPid As %String) As %Status
{
    Set tSC = ..Guarded("%Admin_Operate")
    If $$$ISERR(tSC) Quit $$$OK
    Set tSC = ##class(mp.impl.system).Terminate(pPid)
    If $$$ISERR(tSC) Do ##class(mp.util.json).SendError("BAD_REQUEST", $System.Status.GetErrorText(tSC)) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.util.json).Ok())
    Quit $$$OK
}

// ---------------------------------------------------------------------------
// Logs (US6)
// ---------------------------------------------------------------------------

ClassMethod LogsSources() As %Status
{
    Set tSC = ..Guarded("%Admin_Operate")
    If $$$ISERR(tSC) Quit $$$OK
    Do ##class(mp.util.json).Send(##class(mp.impl.logs).Sources())
    Quit $$$OK
}

ClassMethod LogsQuery() As %Status
{
    Set tSC = ..Guarded("%Admin_Operate")
    If $$$ISERR(tSC) Quit $$$OK
    Set tResult = ##class(mp.impl.logs).Query(
        $Get(%request.Data("source", 1)),
        $Get(%request.Data("from", 1)),
        $Get(%request.Data("to", 1)),
        $Get(%request.Data("severity", 1)),
        +$Get(%request.Data("pageSize", 1), 200))
    Do ##class(mp.util.json).Send(tResult)
    Quit $$$OK
}

ClassMethod LogsExport() As %Status
{
    Set tSC = ..Guarded("%Admin_Operate")
    If $$$ISERR(tSC) Quit $$$OK
    Set tResult = ##class(mp.impl.logs).Query(
        $Get(%request.Data("source", 1)),
        $Get(%request.Data("from", 1)),
        $Get(%request.Data("to", 1)),
        $Get(%request.Data("severity", 1)),
        100000)
    Set %response.Status = "200 OK"
    Set %response.ContentType = "text/csv; charset=utf-8"
    Do %response.SetHeader("Content-Disposition", "attachment; filename=""logs-export.csv""")
    Write ##class(mp.impl.logs).ToCsv(tResult)
    Quit $$$OK
}

}