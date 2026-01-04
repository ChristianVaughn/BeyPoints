# List a tournament's participants

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /tournaments/{tournament}/participants.json:
    get:
      summary: List a tournament's participants
      deprecated: true
      description: Retrieve a tournament's participant list.
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
      responses:
        '200':
          description: ''
          content:
            application/json:
              schema:
                type: object
                properties: {}
              example:
                - participant:
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
                - participant:
                    active: true
                    checked_in_at: null
                    created_at: '2015-01-19T16:54:43-05:00'
                    final_rank: null
                    group_id: null
                    icon: null
                    id: 16543994
                    invitation_id: null
                    invite_email: null
                    misc: null
                    name: 'Participant #2'
                    on_waiting_list: false
                    seed: 2
                    tournament_id: 1086875
                    updated_at: '2015-01-19T16:54:43-05:00'
                    challonge_username: null
                    challonge_email_address_verified: null
                    removable: true
                    participatable_or_invitation_attached: false
                    confirm_remove: true
                    invitation_pending: false
                    display_name_with_invitation_email_address: 'Participant #2'
                    email_hash: null
                    username: null
                    attached_participatable_portrait_url: null
                    can_check_in: false
                    checked_in: false
                    reactivatable: false
                - participant:
                    active: true
                    checked_in_at: null
                    created_at: '2015-01-19T16:57:10-05:00'
                    final_rank: null
                    group_id: null
                    icon: null
                    id: 16543996
                    invitation_id: null
                    invite_email: null
                    misc: null
                    name: 'Participant #3'
                    on_waiting_list: false
                    seed: 3
                    tournament_id: 1086875
                    updated_at: '2015-01-19T16:57:10-05:00'
                    challonge_username: null
                    challonge_email_address_verified: null
                    removable: true
                    participatable_or_invitation_attached: false
                    confirm_remove: true
                    invitation_pending: false
                    display_name_with_invitation_email_address: 'Participant #3'
                    email_hash: null
                    username: null
                    attached_participatable_portrait_url: null
                    can_check_in: false
                    checked_in: false
                    reactivatable: false
                - participant:
                    active: true
                    checked_in_at: null
                    created_at: '2015-01-19T16:57:12-05:00'
                    final_rank: null
                    group_id: null
                    icon: null
                    id: 16543997
                    invitation_id: null
                    invite_email: null
                    misc: null
                    name: 'Participant #4'
                    on_waiting_list: false
                    seed: 4
                    tournament_id: 1086875
                    updated_at: '2015-01-19T16:57:12-05:00'
                    challonge_username: null
                    challonge_email_address_verified: null
                    removable: true
                    participatable_or_invitation_attached: false
                    confirm_remove: true
                    invitation_pending: false
                    display_name_with_invitation_email_address: 'Participant #4'
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
      x-run-in-apidog: https://app.apidog.com/web/project/1113893/apis/api-23830074-run
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
