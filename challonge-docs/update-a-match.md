# Update a match

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /tournaments/{tournament}/matches/{match_id}.json:
    put:
      summary: Update a match
      deprecated: true
      description: >-
        Update/submit the score(s) for a match.


        _If you're updating winner_id, scores_csv must also be provided. You
        may, however, update score_csv without providing winner_id for live
        score updates._
      tags:
        - API v1 (deprecated)/Deprecated Endpoints/Matches
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
        - name: match_id
          in: path
          description: The match's unique ID
          required: true
          schema:
            type: string
        - name: match[scores_csv]
          in: query
          description: >-
            Comma separated set/game scores with player 1 score first (e.g.
            "1-3,3-0,3-2")
          required: false
          schema:
            type: string
        - name: match[winner_id]
          in: query
          description: >-
            The participant ID of the winner or "tie" if applicable (Round Robin
            and Swiss). NOTE: If you change the outcome of a completed match,
            all matches in the bracket that branch from the updated match will
            be reset.
          required: false
          schema:
            type: string
        - name: match[player1_votes]
          in: query
          description: Overwrites the number of votes for player 1
          required: false
          schema:
            type: string
        - name: match[player2_votes]
          in: query
          description: Overwrites the number of votes for player 1
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
                match:
                  attachment_count: null
                  created_at: '2015-01-19T16:57:17-05:00'
                  group_id: null
                  has_attachment: false
                  id: 23575258
                  identifier: A
                  location: null
                  loser_id: 16543997
                  player1_id: 16543993
                  player1_is_prereq_match_loser: false
                  player1_prereq_match_id: null
                  player1_votes: null
                  player2_id: 16543997
                  player2_is_prereq_match_loser: false
                  player2_prereq_match_id: null
                  player2_votes: null
                  round: 1
                  scheduled_time: null
                  started_at: '2015-01-19T16:57:17-05:00'
                  state: complete
                  tournament_id: 1086875
                  underway_at: null
                  updated_at: '2015-01-19T16:57:17-05:00'
                  winner_id: 16543993
                  prerequisite_match_ids_csv: ''
                  scores_csv: 3-1,3-2
          headers: {}
          x-apidog-name: Success
      security:
        - API Key: []
          x-apidog:
            required: true
            schemeGroups:
              - id: CkcVB6vw303P7eTGwiaRC
                schemeIds:
                  - API Key
            use:
              id: CkcVB6vw303P7eTGwiaRC
      x-apidog-folder: API v1 (deprecated)/Deprecated Endpoints/Matches
      x-apidog-status: deprecated
      x-run-in-apidog: https://app.apidog.com/web/project/1113893/apis/api-23832578-run
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
