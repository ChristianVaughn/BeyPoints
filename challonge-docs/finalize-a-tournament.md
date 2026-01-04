# Finalize a tournament

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /tournaments/{tournament}/finalize.json:
    post:
      summary: Finalize a tournament
      deprecated: true
      description: >-
        Finalize a tournament that has had all match scores submitted, rendering
        its results permanent.
      tags:
        - API v1 (deprecated)/Deprecated Endpoints/Tournaments
      parameters:
        - name: tournament
          in: path
          description: >-
            Tournament ID (e.g. 10230) or URL (e.g. 'single_elim' for
            challonge.com/single_elim). If assigned to a subdomain, URL format
            must be :subdomain-:tournament_url (e.g. 'test-mytourney' for
            test.challonge.com/mytourney)
          required: true
          schema:
            type: string
        - name: include_participants
          in: query
          description: 0 or 1; includes an array of associated participant records
          required: false
          example: ''
          schema:
            type: string
        - name: include_matches
          in: query
          description: 0 or 1; includes an array of associated match records
          required: false
          example: ''
          schema:
            type: string
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                properties: {}
          headers: {}
          x-apidog-name: Success
      security:
        - API Key: []
          x-apidog:
            required: true
            schemeGroups:
              - id: p8F1zdi4KPXkAGXKkxPR7
                schemeIds:
                  - API Key
            use:
              id: p8F1zdi4KPXkAGXKkxPR7
      x-apidog-folder: API v1 (deprecated)/Deprecated Endpoints/Tournaments
      x-apidog-status: deprecated
      x-run-in-apidog: https://app.apidog.com/web/project/1113893/apis/api-23827364-run
components:
  schemas: {}
  securitySchemes:
    api_key:
      in: header
      name: Authorization
      type: apikey
    challonge_oauth:
      type: oauth2
      appName: Development Environment
      grantType: authorization_code
      flows:
        authorizationCode:
          authorizationUrl: https://api.challonge.com/oauth/authorize
          tokenUrl: https://api.challonge.com/oauth/token
          scopes:
            me: Read details about the user
            tournaments:read: Read all of the user's tournaments
            tournaments:write: Create, update and delete any of the user's tournaments
            matches:read: Read matches associated with the user's tournaments
            matches:write: Update matches associated with the user's tournaments
            attachments:read: Read match attachments associated with the user's tournaments
            attachments:write: >-
              Create, update and delete match attachments associated with the
              user's tournaments
            participants:read: Read participants associated with the user's tournaments
            participants:write: >-
              Create, update and delete participants associated with the user's
              tournaments
            communities:manage: Access resources belonging to communities that a user administers
            application:organizer: >-
              Full access to the user's resources that are associated with your
              application
            application:player: >-
              Read the user's resources that are associated with your
              application, register them for tournaments, and report their
              scores
            application:manage: >-
              Full access to all tournaments connected to your app. This scope
              can only be obtained via the client credentials flow and should be
              carefully protected.
          x-apidog:
            addTokenTo: header
            useTokenType: access_token
            queryParamKey: access_token
            headerKey: Authorization
            headerPrefix: Bearer
            challengeAlgorithm: S256
            clientAuthentication: header
            useTokenConfigAsRefreshTokenConfig: true
            redirectUri: https://app.apidog.com/oauth2-browser-callback.html
    api_key1:
      in: header
      name: Authorization
      type: apikey
    challonge_oauth1:
      type: oauth2
      appName: Development Environment
      grantType: authorization_code
      flows:
        authorizationCode:
          authorizationUrl: https://api.challonge.com/oauth/authorize
          tokenUrl: https://api.challonge.com/oauth/token
          scopes:
            me: Read details about the user
            application:organizer: >-
              Full access to the user's resources that are associated with your
              application
            application:player: >-
              Read the user's resources that are associated with your
              application, register them for tournaments, and report their
              scores
            tournaments:read: Read all of the user's tournaments
            tournaments:write: Create, update and delete any of the user's tournaments
            matches:read: Read matches associated with the user's tournaments
            matches:write: Update matches associated with the user's tournaments
            attachments:read: Read match attachments associated with the user's tournaments
            attachments:write: >-
              Create, update and delete match attachments associated with the
              user's tournaments
            participants:read: Read participants associated with the user's tournaments
            participants:write: >-
              Create, update and delete participants associated with the user's
              tournaments
            communities:manage: Read and manage communities that the user belongs to
    API Key:
      type: apikey
      in: query
      name: api_key
servers:
  - url: https://api.challonge.com/v2.1
    description: https://api.challonge.com/v2.1
security: []

```
