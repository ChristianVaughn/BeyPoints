# Create a tournament

## OpenAPI Specification

```yaml
openapi: 3.0.1
info:
  title: ''
  description: ''
  version: 1.0.0
paths:
  /tournaments.json:
    post:
      summary: Create a tournament
      deprecated: true
      description: Create a new tournament.
      tags:
        - API v1 (deprecated)/Deprecated Endpoints/Tournaments
      parameters:
        - name: tournament[name]
          in: query
          description: 'Your event''s name/title (Max: 60 characters)'
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[tournament_type]
          in: query
          description: Single elimination (default), double elimination, round robin, swiss
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[url]
          in: query
          description: >-
            challonge.com/url (letters, numbers, and underscores only); when
            blank on create, a random URL will be generated for you
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[subdomain]
          in: query
          description: >-
            subdomain.challonge.com/url (Requires write access to the specified
            subdomain)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[description]
          in: query
          description: Description/instructions to be displayed above the bracket
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[open_signup]
          in: query
          description: >-
            True or false. Have Challonge host a sign-up page (otherwise, you
            manually add all participants)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[hold_third_place_match]
          in: query
          description: >-
            True or false - Single Elimination only. Include a match between
            semifinal losers? (default: false)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[pts_for_match_win]
          in: query
          description: 'Decimal (to the nearest tenth) - Swiss only - default: 1.0'
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[pts_for_match_tie]
          in: query
          description: 'Decimal (to the nearest tenth) - Swiss only - default: 0.5'
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[pts_for_game_win]
          in: query
          description: 'Decimal (to the nearest tenth) - Swiss only - default: 0.0'
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[pts_for_game_tie]
          in: query
          description: 'Decimal (to the nearest tenth) - Swiss only - default: 0.0'
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[pts_for_bye]
          in: query
          description: 'Decimal (to the nearest tenth) - Swiss only - default: 1.0'
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[swiss_rounds]
          in: query
          description: >-
            Integer - Swiss only - We recommend limiting the number of rounds to
            less than two-thirds the number of players. Otherwise, an impossible
            pairing situation can be reached and your tournament may end before
            the desired number of rounds are played.
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[ranked_by]
          in: query
          description: >-
            One of the following: 'match wins', 'game wins', 'points scored',
            'points difference', 'custom' Help
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[rr_pts_for_match_win]
          in: query
          description: >-
            Decimal (to the nearest tenth) - Round Robin 'custom' only -
            default: 1.0
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[rr_pts_for_match_tie]
          in: query
          description: >-
            Decimal (to the nearest tenth) - Round Robin 'custom' only -
            default: 0.5
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[rr_pts_for_game_win]
          in: query
          description: >-
            Decimal (to the nearest tenth) - Round Robin 'custom' only -
            default: 0.0
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[rr_pts_for_game_tie]
          in: query
          description: >-
            Decimal (to the nearest tenth) - Round Robin 'custom' only -
            default: 0.0
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[accept_attachments]
          in: query
          description: 'True or false - Allow match attachment uploads (default: false)'
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[hide_forum]
          in: query
          description: >-
            True or false - Hide the forum tab on your Challonge page (default:
            false)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[show_rounds]
          in: query
          description: >-
            True or false - Single & Double Elimination only - Label each round
            above the bracket (default: false)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[private]
          in: query
          description: >-
            True or false - Hide this tournament from the public browsable index
            and your profile (default: false)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[notify_users_when_matches_open]
          in: query
          description: >-
            True or false - Email registered Challonge participants when matches
            open up for them (default: false)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[notify_users_when_the_tournament_ends]
          in: query
          description: >-
            True or false - Email registered Challonge participants the results
            when this tournament ends (default: false)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[sequential_pairings]
          in: query
          description: >-
            True or false - Instead of traditional seeding rules, make pairings
            by going straight down the list of participants. First round matches
            are filled in top to bottom, then qualifying matches (if
            applicable). (default: false)
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[signup_cap]
          in: query
          description: >-
            Integer - Maximum number of participants in the bracket. A waiting
            list (attribute on Participant) will capture participants once the
            cap is reached.
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[start_at]
          in: query
          description: >-
            Datetime - the planned or anticipated start time for the tournament
            (Used with check_in_duration to determine participant check-in
            window). Timezone defaults to Eastern.
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[check_in_duration]
          in: query
          description: Integer - Length of the participant check-in window in minutes.
          required: false
          example: ''
          schema:
            type: string
        - name: tournament[grand_finals_modifier]
          in: query
          description: >-
            String - This option only affects double elimination. null/blank
            (default) - give the winners bracket finalist two chances to beat
            the losers bracket finalist, 'single match' - create only one grand
            finals match, 'skip' - don't create a finals match between winners
            and losers bracket finalists
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
              example:
                tournament:
                  accept_attachments: false
                  allow_participant_match_reporting: true
                  anonymous_voting: false
                  category: null
                  check_in_duration: null
                  completed_at: null
                  created_at: '2015-01-19T16:47:30-05:00'
                  created_by_api: false
                  credit_capped: false
                  description: ''
                  game_id: 600
                  group_stages_enabled: false
                  hide_forum: false
                  hide_seeds: false
                  hold_third_place_match: false
                  id: 1086875
                  max_predictions_per_user: 1
                  name: Sample Tournament 1
                  notify_users_when_matches_open: true
                  notify_users_when_the_tournament_ends: true
                  open_signup: false
                  participants_count: 4
                  prediction_method: 0
                  predictions_opened_at: null
                  private: false
                  progress_meter: 0
                  pts_for_bye: '1.0'
                  pts_for_game_tie: '0.0'
                  pts_for_game_win: '0.0'
                  pts_for_match_tie: '0.5'
                  pts_for_match_win: '1.0'
                  quick_advance: false
                  ranked_by: match wins
                  require_score_agreement: false
                  rr_pts_for_game_tie: '0.0'
                  rr_pts_for_game_win: '0.0'
                  rr_pts_for_match_tie: '0.5'
                  rr_pts_for_match_win: '1.0'
                  sequential_pairings: false
                  show_rounds: true
                  signup_cap: null
                  start_at: null
                  started_at: null
                  started_checking_in_at: null
                  state: pending
                  swiss_rounds: 0
                  teams: false
                  tie_breaks:
                    - match wins vs tied
                    - game wins
                    - points scored
                  tournament_type: single elimination
                  updated_at: '2015-01-19T16:57:17-05:00'
                  url: sample_tournament_1
                  description_source: ''
                  subdomain: null
                  full_challonge_url: http://challonge.com/sample_tournament_1
                  live_image_url: http://images.challonge.com/sample_tournament_1.png
                  sign_up_url: null
                  review_before_finalizing: true
                  accepting_predictions: false
                  participants_locked: true
                  game_name: Table Tennis
                  participants_swappable: false
                  team_convertable: false
                  group_stages_were_started: false
          headers: {}
          x-apidog-name: Success
      security:
        - API Key: []
          x-apidog:
            required: true
            schemeGroups:
              - id: _VQBKR0yoQm22cXOJ5WiE
                schemeIds:
                  - API Key
            use:
              id: _VQBKR0yoQm22cXOJ5WiE
      x-apidog-folder: API v1 (deprecated)/Deprecated Endpoints/Tournaments
      x-apidog-status: deprecated
      x-run-in-apidog: https://app.apidog.com/web/project/1113893/apis/api-23824895-run
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
