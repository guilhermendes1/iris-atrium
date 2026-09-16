Class mp.impl.session Extends %RegisteredObject
{

/// Current session summary (data only - caller must have authenticated)
ClassMethod Current() As %DynamicObject
{
    Quit {"authenticated":1, "username":(##class(mp.util.security).Username())}
}

/// Validate credentials without writing any response
ClassMethod Validate(pUser As %String, pPassword As %String) As %Status
{
    Quit ##class(mp.util.security).Authenticate(pUser, pPassword)
}

}