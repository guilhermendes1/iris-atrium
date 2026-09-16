Class mp.impl.security Extends %RegisteredObject
{

ClassMethod Prop(pObj, pName As %String, pDefault = "") As %String
{
    Set tValue = pDefault
    Try { Set tValue = $Property(pObj, pName) } Catch {}
    Quit $Get(tValue)
}

/// Switch to %SYS where security definitions live.
ClassMethod InSys() As %String
{
    Set $NAMESPACE = "%SYS"
    Quit ""
}

/// Unified credentials dashboard across SSL, x509, wallet and OAuth categories.
ClassMethod Credentials(pType As %String = "all") As %DynamicArray
{
    Set tType = $ZConvert($Get(pType), "L")
    Set tArr = []
    New $NAMESPACE
    Do ..InSys()
    Try {
        If tType = "all" || (tType = "ssl") Do ..Collect("SSL", ..ListSSL(), .tArr)
        If tType = "all" || (tType = "x509") Do ..Collect("X509", ..ListX509(), .tArr)
        If tType = "all" || (tType = "wallet") Do ..Collect("Wallet", ..ListWallets(), .tArr)
        If tType = "all" || (tType = "oauth") Do ..Collect("OAuth", ..ListOAuth(), .tArr)
    } Catch {}
    Quit tArr
}

ClassMethod Collect(pType As %String, pNames As %DynamicArray, ByRef pArr) As %Status
{
    Set tIter = pNames.%GetIterator()
    While tIter.%GetNext(.tKey, .tValue) {
        Set tItem = { "type":(pType), "alias":(tValue), "description":"", "status":"Active", "enabled":1, "issuer":"", "subject":"", "validFrom":"", "validTo":"" }
        If pType = "SSL" {
            New $NAMESPACE
            Set $NAMESPACE = "%SYS"
            Set tCfg = ##class(Security.SSLConfigs).%OpenId(tValue)
            If $IsObject(tCfg) {
                Do tItem.%Set("description", ..Prop(tCfg, "Description"))
                Set tEnabledYN = ..Prop(tCfg, "Enabled", "0")
                Do tItem.%Set("enabled", +tEnabledYN)
            }
        }
        Do pArr.%Push(tItem)
    }
    Quit $$$OK
}

ClassMethod ListSSL() As %DynamicArray
{
    Set tArr = []
    Try {
        New $NAMESPACE
        Set $NAMESPACE = "%SYS"
        Set tStmt = ##class(%SQL.Statement).%New(1)
        Set tSC = tStmt.%Prepare("SELECT Name FROM Security.SSLConfigs")
        If $$$ISERR(tSC) Return tArr
        Set tRs = tStmt.%Execute()
        While tRs.%Next() {
            Set tName = tRs.Name
            If tName '= "" Do tArr.%Push(tName)
        }
    } Catch {}
    Quit tArr
}

ClassMethod ListX509() As %DynamicArray
{
    Set tArr = []
    Try {
        Set tSc = ##class(%SYS.X509Credentials).List(.tNames)
        If $$$ISERR(tSc) Return tArr
        For i = 1:1:$ListLength(tNames) {
            Set tName = $List(tNames, i)
            If tName '= "" Do tArr.%Push(tName)
        }
    } Catch {}
    Quit tArr
}

ClassMethod ListWallets() As %DynamicArray
{
    Set tArr = []
    Try {
        Set tList = ##class(%SYS.Wallet).List()
        For i = 1:1:$ListLength(tList) {
            Set tName = $List(tList, i)
            If tName '= "" Do tArr.%Push(tName)
        }
    } Catch {}
    If tArr.%Size() = 0 {
        Try {
            New $NAMESPACE
            Set $NAMESPACE = "%SYS"
            Set tKey = ""
            For {
                Set tKey = $Order(^SYS("Config", "Wallet", tKey))
                Quit:tKey=""
                Set tName = tKey
                For {
                    Set tName2 = $Order(^SYS("Config", "Wallet", tKey, tName))
                    Quit:tName2=""
                    Set tName = tName2
                    Do tArr.%Push(tName)
                }
            }
        } Catch {}
    }
    Quit tArr
}

ClassMethod ListOAuth() As %DynamicArray
{
    Set tArr = []
    Try {
        Set tList = ##class(%SYS.OAuth2.Registration).List()
        For i = 1:1:$ListLength(tList) {
            Set tName = $List(tList, i)
            If tName '= "" Do tArr.%Push(tName)
        }
    } Catch {}
    Quit tArr
}

/// Detail for a single credential.
ClassMethod Detail(pType As %String, pAlias As %String) As %DynamicObject
{
    Set tType = $ZConvert($Get(pType), "L")
    Set tObj = { "type":($ZConvert(pType, "U")), "alias":(pAlias), "description":"", "status":"Active", "enabled":1, "issuer":"", "subject":"", "validFrom":"", "validTo":"", "extra":{} }
    New $NAMESPACE
    Do ..InSys()
    Try {
        If tType = "ssl" {
            Set tCfg = ##class(Security.SSLConfigs).%OpenId(pAlias)
            If $IsObject(tCfg) {
                Do tObj.%Set("description", ..Prop(tCfg, "Description"))
                Set tEnabledYN = ..Prop(tCfg, "Enabled", "0")
                Do tObj.%Set("enabled", +tEnabledYN)
            }
        } ElseIf tType = "x509" {
            Set tCred = ##class(%SYS.X509Credentials).%OpenId(pAlias)
            If $IsObject(tCred) {
                Do tObj.%Set("issuer", ..Prop(tCred, "Issuer"))
                Do tObj.%Set("subject", ..Prop(tCred, "Subject"))
                Do tObj.%Set("description", ..Prop(tCred, "Alias"))
            }
        } ElseIf tType = "wallet" {
            Set tW = ##class(%SYS.Wallet).%OpenId(pAlias)
            If $IsObject(tW) Do tObj.%Set("description", ..Prop(tW, "Directory"))
        }
    } Catch {}
    Quit tObj
}

}