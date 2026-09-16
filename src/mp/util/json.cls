Class mp.util.json Extends %RegisteredObject
{

/// JSON "ok" envelope
ClassMethod Ok() As %DynamicObject
{
    Quit {"ok":1}
}

/// Error envelope object factory
ClassMethod Error(pCode As %String, pMessage As %String) As %DynamicObject
{
    Quit {"error":(pCode),"message":(pMessage)}
}

/// Convert a %Status into an error envelope object
ClassMethod StatusError(pStatus As %Status, pFallback As %String = "Internal server error") As %DynamicObject
{
    Set tMessage = pFallback
    Try {
        Set tText = $System.Status.GetErrorText(pStatus)
        If tText '= "" Set tMessage = tText
    } Catch {}
    Quit {"error":("INTERNAL_ERROR"),"message":(tMessage)}
}

/// Map a short error code to an HTTP status line
ClassMethod HttpStatus(pCode As %String) As %String
{
    Set pCode = $ZConvert($Get(pCode), "U")
    Quit $Case(pCode,
        "BAD_REQUEST":"400 Bad Request",
        "UNAUTHORIZED":"401 Unauthorized",
        "PERMISSION_DENIED":"403 Forbidden",
        "NOT_FOUND":"404 Not Found",
        "METHOD_NOT_ALLOWED":"405 Method Not Allowed",
        "CONFLICT":"409 Conflict",
        "BAD_GATEWAY":"502 Bad Gateway",
        :"500 Internal Server Error")
}

/// Send a JSON-serializable value with a 2xx status
ClassMethod Send(pObject) As %Status
{
    Set %response.Status = "200 OK"
    Set %response.ContentType = "application/json"
    Set %response.CharSet = "utf-8"
    If $IsObject(pObject) && pObject.%IsA("%Library.DynamicAbstractObject") {
        Do pObject.%ToJSON()
    } ElseIf $IsObject(pObject) && pObject.%IsA("%Library.Object") {
        Write pObject.%ToJSON()
    } Else {
        Write pObject
    }
    Quit $$$OK
}

/// Send a raw string (caller is responsible for content type)
ClassMethod SendRaw(pText As %String) As %Status
{
    Set %response.Status = "200 OK"
    Set %response.ContentType = "application/json"
    Set %response.CharSet = "utf-8"
    Write pText
    Quit $$$OK
}

/// Send a JSON error response
ClassMethod SendError(pCode As %String, pMessage As %String, pStatus As %Status = "") As %Status
{
    Set %response.Status = ..HttpStatus(pCode)
    Set %response.ContentType = "application/json"
    Set %response.CharSet = "utf-8"
    If pStatus '= "" {
        Do ..Error(pCode, ..StatusText(pStatus)).%ToJSON()
    } Else {
        Do ..Error(pCode, pMessage).%ToJSON()
    }
    Quit $$$OK
}

ClassMethod StatusText(pStatus As %Status) As %String
{
    Set tText = "Internal server error"
    Try { Set tText = $System.Status.GetErrorText(pStatus) } Catch {}
    Quit tText
}

/// Read the raw request body. Prefers URL-encoded form data (reliable on all CSP
/// versions), falling back to the raw content stream.
ClassMethod ReadBody() As %String
{
    Set tBody = ""
    Try {
        Set tB64 = $Get(%request.Data("body64", 1))
        If tB64 '= "" Set tBody = $System.Encryption.Base64Decode(tB64)
    } Catch {}
    If tBody = "" {
        Try {
            Set tBody = $Get(%request.Data("", 1))
        } Catch {}
    }
    If tBody = "" {
        Set tBody = $Get(%request.MimeData("body", 1))
    }
    If tBody = "" {
        Try {
            If $IsObject(%request.Content) {
                Do %request.Content.Rewind()
                Set tChunk = ""
                For {
                    Set tChunk = %request.Content.Read()
                    Quit:tChunk=""
                    Set tBody = tBody _ tChunk
                }
            }
        } Catch {
            Set tBody = ""
        }
    }
    Quit tBody
}

/// Coerce a raw value into a JSON-friendly string
ClassMethod AsJson(pValue) As %String
{
    If pValue = $C(0) Quit ""
    If $IsObject(pValue) Quit ""
    Quit $Get(pValue)
}

/// Project one $lb row into a JSON object using a comma-separated column list
ClassMethod RowAsObject(pRow, pColumns As %String) As %DynamicObject
{
    Set tObj = {}
    Set tCount = $ListLength(pColumns)
    For i = 1:1:tCount {
        Do tObj.%Set($ZStrip($List(pColumns, i), "<>W"), ..AsJson($ListGet(pRow, i)))
    }
    Quit tObj
}

/// Project a %ResultSet into a JSON array of objects (dynamic columns)
ClassMethod RowsToArray(pRS As %ResultSet) As %DynamicArray
{
    Set tArr = []
    Try {
        While pRS.Next() {
            Set tObj = {}
            For c = 1:1:pRS.GetColumnCount() {
                Do tObj.%Set(pRS.GetColumnName(c), ..AsJson(pRS.GetData(c)))
            }
            Do tArr.%Push(tObj)
        }
    } Catch {}
    Quit tArr
}

/// Read a property from a JSON object with a default
ClassMethod DynVal(pObj, pName As %String, pDefault = "") As %String
{
    Set tValue = pDefault
    Try {
        If pObj.%IsDefined(pName) Set tValue = pObj.%Get(pName)
    } Catch {}
    Quit tValue
}

/// Render a $H timestamp as ISO-8601 (UTC-naive, demo format).
/// Accepts $H in "day,seconds" string, numeric fraction, or combined form.
ClassMethod Stamp(pDateTime) As %String
{
    If pDateTime = "" Quit ""
    Set tStamp = ""
    Try {
        Set tValue = pDateTime
        If tValue [ "," {
            Set tDays = +$Piece(tValue, ",", 1)
            Set tSecs = +$Piece(tValue, ",", 2)
        } Else {
            Set tDays = +$Piece(tValue, ".", 1)
            Set tSecs = +("." _ $Piece(tValue, ".", 2)) * 86400
        }
        If tDays > 0 && (tSecs >= 0) && (tSecs < 86400) {
            Set tStamp = $ZDate(tDays, 3) _ "T" _ $ZTime(tSecs, 1) _ "Z"
        }
    } Catch {}
    Quit tStamp
}

/// Render a timestamp that may be $H, an IRIS %TimeStamp string
/// ("2026-09-16 11:39:00") or an ISO string ("2026-09-16T11:39:00.123Z").
ClassMethod StampFlex(pValue) As %String
{
    If pValue = "" Quit ""
    If pValue = $C(0) Quit ""
    If $IsObject(pValue) Quit ""
    Set pValue = $Get(pValue)
    If pValue '= +pValue {
        ; "67829,41940" - $H encoded as day,seconds text
        Set tComma = $Find(pValue, ",")
        If tComma > 0 {
            Set tDays = +pValue
            Set tSecs = +$Piece(pValue, ",", 2)
            If tDays > 0 && (tSecs >= 0) Quit ..Stamp(tDays _ "," _ tSecs)
        }
        ; not a pure number - treat as a timestamp STRING
        If pValue [ "T" {
            ; already ISO-ish: trim fractional seconds and normalize suffix
            Set tIso = $Piece(pValue, ".", 1)
            If $Extract(tIso, *) '= "Z" Set tIso = tIso _ "Z"
            Quit tIso
        }
        If (pValue [ "1840-12-31") || (pValue [ "0000-00-00") Quit ""
        If pValue [ " " {
            Quit $Replace(pValue, " ", "T") _ "Z"
        }
        Quit pValue
    }
    ; zero-ish numeric never-run marker
    If pValue = 0 Quit ""
    ; pure number: could be $H (day,seconds) or $H fraction
    Quit ..Stamp(pValue)
}

}