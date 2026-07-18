#!/usr/bin/env bash
# expires タグが期限切れのリソースグループを一覧する
# 必要: az extension add --name resource-graph
set -euo pipefail

az graph query -q "
ResourceContainers
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| extend expires = todatetime(tags['expires'])
| where isnotnull(expires) and expires < now()
| project name, subscriptionId, projectName = tags['projectName'], owner = tags['owner'], expires
| order by expires asc
" --query "data" --output table
