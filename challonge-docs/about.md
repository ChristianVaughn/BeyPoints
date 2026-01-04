# About

*Still importing documentation from https://api.challonge.com/v1 ...*

---

API v1 was introduced many, many years ago. If you're just starting out, use [v2.1](https://challonge.apidog.io/getting-started-1726706m0) instead. This API version has no support for two-stage tournaments.

🔔 Please note that effective March 2026, our API requires a paid plan should you need more than 5,000* requests per month (* _subject to change prior to official announcement_). You can upgrade your app from the [Developer Portal](https://connect.challonge.com).

## Base URL
API v1 is accessible over a secure connection at https://api.challonge.com/v1/

## Authentication
All interactions with the API require a Challonge account with a verified email address and API key. You can generate one from your [developer settings page](https://challonge.com/settings/developer). We support HTTP basic authentication. Username = your Challonge username, Password = your API key. Many clients format these requests as: `https://username:api-key@api.challonge.com/v1/` Or, if you prefer, you can just pass your API key as parameter `api_key` to all method calls.

API methods with GET request types are permitted for any tournament, whether belonging to you or not. All other API methods are scoped to tournaments that you either own or have admin access to.

## Response Formats
XML or JSON. The extension in your request indicates your desired response. e.g. https://api.challonge.com/v1/tournaments.xml or https://api.challonge.com/v1/tournaments.json - you may also set your request headers to accept application/json, text/xml or application/xml

## Response Codes
The following HTTP response codes are issued by the API. All other codes are the result of a request not reaching the application.

`200` OK
`401` Unauthorized (Invalid API key or insufficient permissions)
`404` Object not found within your account scope
`406` Requested format is not supported - request JSON or XML only
`422` Validation error(s) for create or update method
`500` Something went wrong on our end. If you continually receive this, please contact us.

## Validation Errors
Requests that complete but have validation errors or other issues will return an array of error messages and status code 422. e.g.:

```json
{
  "errors": [
    "Name can't be blank",
    "URL can't be blank"
  ]
}
```
