# Bulk create participants

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /tournaments/{tournament}/participants/bulk_add.json:
    post:
      summary: Bulk create participants
      deprecated: true
      description: >-
        Bulk add participants to a tournament (up until it is started). If an
        invalid participant is detected, bulk participant creation will halt and
        any previously added participants (from this API request) will be rolled
        back.
      tags:
        - API v1 (deprecated)/Deprecated Endpoints/Participants
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
        - name: participant[][name]
          in: query
          description: >-
            The name displayed in the bracket/schedule - not required if email
            or challonge_username is provided. Must be unique per tournament.
          required: false
          schema:
            type: string
        - name: participant[][challonge_username]
          in: query
          description: >-
            Provide this if the participant has a Challonge account. He or she
            will be invited to the tournament.
          required: false
          schema:
            type: string
        - name: participant[][email]
          in: query
          description: >-
            Providing this will first search for a matching Challonge account.
            If one is found, this will have the same effect as the
            "challonge_username" attribute. If one is not found, the
            "new-user-email" attribute will be set, and the user will be invited
            via email to create an account.
          required: false
          schema:
            type: string
        - name: participant[][seed]
          in: query
          description: >-
            The participant's new seed. Must be between 1 and the current number
            of participants (including the new record). Overwriting an existing
            seed will automatically bump other participants as you would expect.
          required: false
          schema:
            type: integer
        - name: participant[][misc]
          in: query
          description: >-
            Max: 255 characters. Multi-purpose field that is only visible via
            the API and handy for site integration (e.g. key to your users
            table)
          required: false
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
              example:
                participant:
                  active: true
                  checked_in_at: null
                  created_at: '2015-01-19T16:54:40-05:00'
                  final_rank: null
                  group_id: null
                  icon: null
                  id: 16543993
                  invitation_id: null
                  invite_email: null
                  misc: null
                  name: 'Participant #1'
                  on_waiting_list: false
                  seed: 1
                  tournament_id: 1086875
                  updated_at: '2015-01-19T16:54:40-05:00'
                  challonge_username: null
                  challonge_email_address_verified: null
                  removable: true
                  participatable_or_invitation_attached: false
                  confirm_remove: true
                  invitation_pending: false
                  display_name_with_invitation_email_address: 'Participant #1'
                  email_hash: null
                  username: null
                  attached_participatable_portrait_url: null
                  can_check_in: false
                  checked_in: false
                  reactivatable: false
          headers: {}
          x-apidog-name: Success
      security:
        - API Key: []
          x-apidog:
            required: true
            schemeGroups:
              - id: B6l922NL43EoIEqKgZEs5
                schemeIds:
                  - API Key
            use:
              id: B6l922NL43EoIEqKgZEs5
      x-apidog-folder: API v1 (deprecated)/Deprecated Endpoints/Participants
      x-apidog-status: deprecated
      x-run-in-apidog: https://app.apidog.com/web/project/1113893/apis/api-23831430-run
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
