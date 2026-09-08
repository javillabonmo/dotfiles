#!/bin/bash
mkdir -p ~/.oh-my-zsh/completions
docker completion zsh > ~/.oh-my-zsh/completions/_docker

sudo apt install dotnet-sdk-10.0 -y