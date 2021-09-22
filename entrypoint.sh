#!/bin/bash
#####################################################
# original at https://github.com/sladyn98/auto-go-format

set -e

PR_NUMBER=$(jq --raw-output .number "$GITHUB_EVENT_PATH")

echo "Collecting information about PR #$PR_NUMBER of $GITHUB_REPOSITORY"

if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "GITHUB_TOKEN env variable not set."
	exit 1
fi

API_URI=https://api.github.com
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token $GITHUB_TOKEN"

PR_RESP=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
          "${API_URI}/repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER")

BASE_REPO_NAME=$(echo "$PR_RESP" | jq -r .base.repo.full_name)
BASE_BRANCH=$(echo "$PR_RESP" | jq -r .base.ref)

if [[ -z "$BASE_BRANCH" ]]; then
	echo "Cannot get base branch information for PR #$PR_NUMBER"
	echo "Github API response was: $PR_RESP"
	exit 1
fi

USER_LOGIN=$(jq -r ".comment.user.login" "$GITHUB_EVENT_PATH")

USER_RESP=$(curl -X GET -s -H "${AUTH_HEADER}" -H "${API_HEADER}" \
            "${API_URI}/users/${USER_LOGIN}")

USER_NAME=$(echo "$USER_RESP" | jq -r ".name")
if [[ "$USER_NAME" == "null" ]]; then
	USER_NAME=$USER_LOGIN
fi
USER_NAME="${USER_NAME} (Rebase PR Action)"

USER_EMAIL=$(echo "$USER_RESP" | jq -r ".email")
if [[ "$USER_EMAIL" == "null" ]]; then
	USER_EMAIL="$USER_LOGIN@users.noreply.github.com"
fi

HEAD_REPO_NAME=$(echo "$PR_RESP" | jq -r .head.repo.full_name)
HEAD_BRANCH=$(echo "$PR_RESP" | jq -r .head.ref)

echo "Base branch for PR #$PR_NUMBER is $BASE_BRANCH"

USER_TOKEN="${USER_LOGIN}_TOKEN"
COMMITTER_TOKEN="${!USER_TOKEN:-$GITHUB_TOKEN}"
git remote set-url origin https://x-access-token:"$COMMITTER_TOKEN"@github.com/"$GITHUB_REPOSITORY".git
git config --global user.email "$USER_EMAIL"
git config --global user.name "$USER_NAME"

git remote add fork https://x-access-token:"$COMMITTER_TOKEN"@github.com/"$HEAD_REPO_NAME".git

# enable TRACE logging of cmds for debugging
set -o xtrace

# make sure branches are up-to-date
git fetch origin "$BASE_BRANCH"
git fetch fork "$HEAD_BRANCH"

URL="https://api.github.com/repos/${BASE_REPO_NAME}/pulls/${PR_NUMBER}/files"
FILES=$(curl -s -X GET -H "Authorization: token $GITHUB_TOKEN" -G "$URL" | jq -r '.[] | .filename')
declare -i count=0

for FILE in $FILES; do
    if [ "${FILE##*.}" = "go" ]; then
        count=$((count+1))
        # https://pkg.go.dev/cmd/gofmt
        gofmt -w "${FILE}"
    fi
done

# $1 - comment text
post-comment () {
    local PAYLOAD
    PAYLOAD=$(echo '{}' | jq --arg body "$1" '.body = $body')
    local JSON_CONTENT_HEADER
    JSON_CONTENT_HEADER="Content-Type: application/json"
    local COMMENTS_URL
    COMMENTS_URL=$(< /github/workflow/event.json jq -r .pull_request.comments_url)
    if [ "$COMMENTS_URL" != null ]; then
        curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "$JSON_CONTENT_HEADER" --data "$PAYLOAD" "$COMMENTS_URL" > /dev/null
    fi
}

# Post results back as comment
if [ "$count" -eq "0" ]; then
    post-comment "You do not have any go files to format."
    exit $SUCCESS
fi

if [[ $(git status --porcelain) ]]; then    
    git add .
    git commit -m "Format Go source code files"
    git push --force-with-lease fork HEAD:"$HEAD_BRANCH"
    post-comment ":rocket: Your go files have been formatted successfully."
else
    post-comment ":heavy_check_mark: That is a perfectly formatted change."
fi

exit $SUCCESS
