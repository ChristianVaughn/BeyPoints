#!/bin/bash

# Create the output directory
mkdir -p challonge-docs

# Base URL
BASE="https://challonge.apidog.io"

# Array of all v1.0 API endpoint paths
urls=(
    # About
    "about-1726725m0.md"
    
    # Tournaments (11)
    "list-tournaments-23621660e0.md"
    "create-a-tournament-23824895e0.md"
    "get-a-tournament-23824918e0.md"
    "update-a-tournament-23824929e0.md"
    "delete-a-tournament-23824932e0.md"
    "process-check-in-results-for-a-tournament-23824997e0.md"
    "abort-check-in-for-a-tournament-23825012e0.md"
    "start-a-tournament-23825026e0.md"
    "finalize-a-tournament-23827364e0.md"
    "reset-a-tournament-23827367e0.md"
    "open-for-predictions-23827372e0.md"
    
    # Participants (10)
    "list-a-tournaments-participants-23830074e0.md"
    "create-a-participant-23830076e0.md"
    "bulk-create-participants-23831430e0.md"
    "get-a-participant-23831728e0.md"
    "update-a-participant-23831734e0.md"
    "check-in-a-participant-23832009e0.md"
    "undo-check-in-for-a-participant-23832014e0.md"
    "deletedeactivate-a-participant-23832019e0.md"
    "cleardelete-all-participants-23832027e0.md"
    "randomize-a-tournaments-participants-23832032e0.md"
    
    # Matches (6)
    "list-a-tournaments-matches-23832273e0.md"
    "get-a-match-23832278e0.md"
    "update-a-match-23832578e0.md"
    "reopen-a-match-23832652e0.md"
    "mark-a-match-as-underway-23832661e0.md"
    "unmark-a-match-as-underway-23832664e0.md"
    
    # Match Attachments (5)
    "list-a-matchs-attachments-23832672e0.md"
    "create-a-match-attachment-23832710e0.md"
    "get-a-match-attachment-23832714e0.md"
    "update-a-match-attachment-23832740e0.md"
    "delete-a-match-attachment-23832743e0.md"
)

echo "Downloading ${#urls[@]} Challonge v1.0 API docs..."

for url in "${urls[@]}"; do
    filename=$(echo "$url" | sed 's/-[a-z0-9]*e0\.md/.md/' | sed 's/-[a-z0-9]*m0\.md/.md/')
    echo "Downloading: $url -> $filename"
    curl -s "${BASE}/${url}" -o "challonge-docs/${filename}"
    sleep 0.5  # Be nice to the server
done

echo "Done! Files saved to challonge-docs/"
ls -la challonge-docs/
