Class mp.Installer Extends %RegisteredObject
{

/// Bootstrap both web applications (the portal and the REST endpoint) in the
/// given namespace. Call from %SYS: the Security.* classes only exist there.
ClassMethod CreateApplications(pNamespace As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Kill tProps
        Set tProps("NameSpace") = pNamespace
        Set tProps("Path") = "/opt/mgmt/csp"
        Set tProps("Enabled") = 1
        Set tProps("ServeFiles") = 1
        Set tProps("Recurse") = 1
        Set tProps("Timeout") = 900
        Set tProps("CookiePath") = "/csp/iris-atrium"
        Set tProps("DeepSeeEnabled") = 0
        Set tProps("AutoCompile") = 0
        Set tProps("AutheEnabled") = 32
        Set tSC = ..ApplyApp("/csp/iris-atrium", .tProps)
        If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)

        Kill tProps
        Set tProps("NameSpace") = pNamespace
        Set tProps("DispatchClass") = "mp.disp"
        Set tProps("Path") = "/opt/mgmt/api"
        Set tProps("Enabled") = 1
        Set tProps("ServeFiles") = 0
        Set tProps("Recurse") = 1
        Set tProps("Timeout") = 900
        Set tProps("CookiePath") = "/api/mp"
        Set tProps("DeepSeeEnabled") = 0
        Set tProps("AutheEnabled") = 32
        Set tSC = ..ApplyApp("/api/mp", .tProps)
        If $$$ISERR(tSC) Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
    } Catch ex {
        If $IsObject(ex) Set tSC = ex.AsStatus()
        Else
        Set tSC = $$$ERROR($$$GeneralError, "Web application setup failed: " _ $ZERROR)
    }
    Quit tSC
}

/// Create or update a Security.Applications entry. Properties are applied through
/// the object layer so every supported key is honored regardless of what Create
/// accepted.
ClassMethod ApplyApp(pName As %String, ByRef pProps) As %Status
{
    Try {
        Set tApp = ##class(Security.Applications).%OpenId(pName)
        If '$IsObject(tApp) {
            Set tCreated = ##class(Security.Applications).Create(pName, .pProps)
            If $$$ISERR(tCreated) Return tCreated
            Set tApp = ##class(Security.Applications).%OpenId(pName)
        }
        If '$IsObject(tApp) Return $$$ERROR($$$GeneralError, "Cannot open web application: " _ pName)
        Set tKey = ""
        For {
            Set tKey = $Order(pProps(tKey))
            Quit:tKey=""
            Try { Set $Property(tApp, tKey) = pProps(tKey) } Catch {}
        }
        Return tApp.%Save()
    } Catch ex {
        Return ex.AsStatus()
    }
}

}