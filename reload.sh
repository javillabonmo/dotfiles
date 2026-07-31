#!/usr/bin/env bash

rm -rf ~/.config/nvim
rm -rf ~/.config/opencode

cp -r linux/.config/nvim ~/.config/nvim
cp -r linux/.config/opencode ~/.config/opencode



export GIT_REPO_NAME=""

export GITHUB_PERSONAL_ACCESS_TOKEN=""

export POSTGRES_USER=""
export POSTGRES_PASSWORD=""
export POSTGRES_DB=""

export OBSIDIAN_VAULT=""

export MONGODB_CONNECTION_STRING=""