Class mp.impl.webapps Extends %RegisteredObject
{

/// Get a property value from any object, tolerating missing properties.
ClassMethod Prop(pObj, pName As %String, pDefault = "") As %String
{
    Set tValue = pDefault
    Try { Set tValue = $Property(pObj, pName) } Catch {}
    Quit $Get(tValue)
}

/// List all configured web applications.
ClassMethod List() As %DynamicArray
{
    Set tArr = []
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Security.Applications")
        While tRS.%Next() {
            Set tName = tRS.%Get("ID")
            If tName '= "" Do tArr.%Push(..AppRow(tName))
        }
    } Catch {}
    Set $Namespace = tNs
    Quit tArr
}

/// One web application projected to the API shape.
ClassMethod AppRow(pName As %String) As %DynamicObject
{
    Set tObj = {"path":(pName), "name":(pName), "namespace":"", "enabled":1, "type":"CSP", "authentication":"", "dispatchClass":"", "physicalPath":"", "serving":0, "resources":[]}
    Try {
        Set tApp = ##class(Security.Applications).%OpenId(pName)
        If '$IsObject(tApp) Return tObj
        Set tDispatch = ..Prop(tApp, "DispatchClass")
        Set tType = "CSP"
        If tDispatch '= "" Set tType = "REST"
        If '..Prop(tApp, "ServeFiles", 0) && tDispatch = "" Set tType = "Other"
        Do tObj.%Set("namespace", ..Prop(tApp, "NameSpace"))
        Do tObj.%Set("enabled", +..Prop(tApp, "Enabled", 1))
        Do tObj.%Set("type", tType)
        Do tObj.%Set("authentication", ..AuthList(tApp))
        Do tObj.%Set("dispatchClass", tDispatch)
        Do tObj.%Set("physicalPath", ..Prop(tApp, "Path"))
        Do tObj.%Set("serving", +..Prop(tApp, "ServeFiles", 0))
        Set tRes = []
        Try {
            Set tKey = ""
            For {
                Set tKey = tApp.Resources.GetNext(tKey)
                Quit:tKey=""
                Do tRes.%Push({"resource":(tKey), "permission":($Get(tApp.Resources.GetAt(tKey)))})
            }
        } Catch {}
        Do tObj.%Set("resources", tRes)
    } Catch {}
    Quit tObj
}

ClassMethod AuthList(pApp) As %String
{
    Set tAuth = ""
    Try {
        Set tList = pApp.AuthEnabled
        For i = 1:1:$ListLength(tList) {
            If tAuth '= "" Set tAuth = tAuth _ "+"
            Set tAuth = tAuth _ $List(tList, i)
        }
    } Catch {}
    Quit tAuth
}

/// List REST-enabled applications discovered through the native /api/mgmnt endpoint.
ClassMethod InstalledApps(pUser As %String, pPassword As %String, pNamespace As %String = "") As %DynamicObject
{
    Set tResult = {"ok":0, "apps":[], "raw":""}
    If pNamespace = "" Set pNamespace = ..ServerNamespace()
    Set tUrl = "/api/mgmnt/v1/" _ ..UrlEncode(pNamespace) _ "/restapps"
    Set tSC = ..GetJson(tUrl, pUser, pPassword, .tBody)
    If $$$ISERR(tSC) {
        Do tResult.%Set("raw", tBody)
        Quit tResult
    }
    Set tApps = []
    Try {
        Set tDynamic = ##class(%DynamicObject).%FromJSON(tBody)
        If $IsObject(tDynamic) && tDynamic.%IsA("%Library.DynamicArray") {
            For i = 0:1:tDynamic.%Size() - 1 {
                Set v = tDynamic.%Get(i)
                If '$IsObject(v) Continue
                Set tItem = {}
                Do tItem.%Set("name", ##class(mp.util.json).DynVal(v, "name", ""))
                Do tItem.%Set("namespace", pNamespace)
                Do tItem.%Set("dispatchClass", ..SpecDispatch(v))
                Do tItem.%Set("resource", ##class(mp.util.json).DynVal(v, "resource", ""))
                Set tEnabled = ##class(mp.util.json).DynVal(v, "enabled", 1)
                Do tItem.%Set("enabled", +tEnabled)
                Do tItem.%Set("swaggerSpecURL", "/api/mgmnt/v1/" _ ..UrlEncode(pNamespace) _ "/spec/" _ ..UrlEncode(##class(mp.util.json).DynVal(v, "name", "")))
                Do tApps.%Push(tItem)
            }
        }
    } Catch {}
    Do tResult.%Set("apps", tApps)
    Do tResult.%Set("ok", 1)
    Quit tResult
}

ClassMethod SpecDispatch(pObj) As %String
{
    Set tDefault = ""
    Try {
        Set tDispatch = pObj.dispatch
        If $IsObject(tDispatch) {
            Set tDefault = ##class(mp.util.json).DynVal(tDispatch, "default", "")
        } ElseIf pObj.%IsDefined("dispatchClass") {
            Set tDefault = pObj.dispatchClass
        }
    } Catch {}
    Quit tDefault
}

/// Proxy for the OpenAPI spec of an installed REST application.
ClassMethod AppSpec(pNamespace As %String, pAppName As %String, pUser As %String, pPassword As %String) As %String
{
    Set tUrl = "/api/mgmnt/v1/" _ ..UrlEncode(pNamespace) _ "/spec/" _ pAppName
    Set tSC = ..GetJson(tUrl, pUser, pPassword, .tBody)
    If $$$ISERR(tSC) Quit ##class(mp.util.json).Error("BAD_GATEWAY", tBody).%ToJSON()
    Quit tBody
}

/// Create a web application from a JSON property bag.
ClassMethod CreateApp(pName As %String, pProps As %DynamicObject) As %Status
{
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Set tSC = $$$OK
    Try {
        If ##class(Security.Applications).%ExistsId(pName) {
            Set tSC = $$$ERROR($$$GeneralError, "Web application already exists: " _ pName)
        } Else {
            Do ..PropsArray(pProps, .tProps)
            Set tSC = ##class(Security.Applications).Create(pName, .tProps)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $Namespace = tNs
    Quit tSC
}

/// Modify a web application from a JSON property bag.
ClassMethod ModifyApp(pName As %String, pProps As %DynamicObject) As %Status
{
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Set tSC = $$$OK
    Try {
        Set tApp = ##class(Security.Applications).%OpenId(pName)
        If '$IsObject(tApp) {
            Set tSC = $$$ERROR($$$GeneralError, "Web application not found: " _ pName)
        } Else {
            Do ..PropsArray(pProps, .tProps)
            Set tKey = ""
            For {
                Set tKey = $Order(tProps(tKey))
                Quit:tKey=""
                Try { Set $Property(tApp, tKey) = tProps(tKey) } Catch {}
            }
            Set tSC = tApp.%Save()
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $Namespace = tNs
    Quit tSC
}

/// Delete a web application by path.
ClassMethod DeleteApp(pName As %String) As %Status
{
    Set tNs = $Namespace
    Set $Namespace = "%SYS"
    Set tSC = $$$OK
    Try {
        If '##class(Security.Applications).%DeleteId(pName) Set tSC = $$$ERROR($$$GeneralError, "Web application not found: " _ pName)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $Namespace = tNs
    Quit tSC
}

/// Translate the client JSON property bag into a Security.Applications props array.
ClassMethod PropsArray(pProps As %DynamicObject, ByRef pOut) As %Status
{
    Kill pOut
    Set pOut("NameSpace") = ##class(mp.util.json).DynVal(pProps, "namespace", "USER")
    Set pOut("Path") = ##class(mp.util.json).DynVal(pProps, "path", "/opt/mgmt/csp")
    Set pOut("Enabled") = +##class(mp.util.json).DynVal(pProps, "enabled", 1)
    Set pOut("ServeFiles") = +##class(mp.util.json).DynVal(pProps, "serving", 0)
    Set pOut("Recurse") = +##class(mp.util.json).DynVal(pProps, "recurse", 1)
    Set pOut("DispatchClass") = ##class(mp.util.json).DynVal(pProps, "dispatchClass", "")
    Set pOut("Timeout") = +##class(mp.util.json).DynVal(pProps, "timeout", 900)
    Set pOut("CookiePath") = ##class(mp.util.json).DynVal(pProps, "cookiePath", "/csp/iris-atrium")
    Set pOut("DeepSeeEnabled") = 0
    Set pOut("Type") = 2
    Set pOut("AutheEnabled") = 32
    Quit $$$OK
}

/// URL-encode a path segment for the native /api/mgmnt proxy.
ClassMethod UrlEncode(pValue As %String) As %String
{
    Set tValue = $ZConvert($Get(pValue), "O", "URL")
    Quit tValue
}

/// The namespace the portal runs in (used as the /api/mgmnt default).
ClassMethod ServerNamespace() As %String
{
    Set tNs = "USER"
    Try { Set tNs = $Namespace } Catch {}
    Quit tNs
}

/// Perform an authenticated GET against the native API, returning the raw body.
ClassMethod GetJson(pUrl As %String, pUser As %String, pPassword As %String, Output pBody As %String) As %Status
{
    Set pBody = ""
    Set tReq = ##class(%Net.HttpRequest).%New()
    Try {
        Set tReq.Server = "127.0.0.1"
        Set tReq.Port = ..ServerPort()
        Do tReq.SetHeader("Authorization", "Basic " _ ##class(%SYSTEM.Encryption).Base64Encode(pUser _ ":" _ pPassword))
        Set tSC = tReq.Get(pUrl)
        If $$$ISERR(tSC) Return tSC
        Set tResp = tReq.HttpResponse
        If '$IsObject(tResp) Return $$$ERROR($$$GeneralError, "No response from native API")
        If tResp.StatusCode '= 200 {
            Set pBody = "Native API returned HTTP " _ tResp.StatusCode
            Return $$$ERROR($$$GeneralError, "Native API returned HTTP " _ tResp.StatusCode)
        }
        Set pBody = tResp.Data.Read(10000000)
    } Catch ex {
        Return ex.AsStatus()
    }
    Quit $$$OK
}

ClassMethod ServerPort() As %Integer
{
    Set tPort = 52773
    Try {
        Set tCandidate = %request.GetCgiEnv("SERVER_PORT")
        If tCandidate '= "" Set tPort = +tCandidate
    } Catch {}
    If tPort = 0 Set tPort = 52773
    Quit tPort
}

}