// 共同利用サブスクリプションの「最初の一手」Policy セット
//  1. リソースグループ作成時に projectName / owner / expires タグを強制 (deny)
//  2. RG のタグを配下のリソースへ自動継承 (modify)
//  3. リソース / RG の作成リージョンを日本国内に制限 (builtin)
// これ1ファイルをサブスクリプションに対してデプロイするだけで有効になる
targetScope = 'subscription'

@description('modify 用マネージド ID を置くリージョン')
param location string = 'japaneast'

@description('リソースグループに強制するタグ名')
param requiredTags array = [
  'projectName'
  'owner'
  'expires'
]

@description('許可するリージョン')
param allowedLocations array = [
  'japaneast'
  'japanwest'
]

@description('タグ強制の効果。まず様子を見るなら Audit にする')
@allowed([
  'Audit'
  'Deny'
])
param tagEffect string = 'Deny'

// Tag Contributor: modify の修復タスクがタグを書くために必要
var tagContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4a9ae827-6dc8-4573-8ac7-8239d42aa03f'
)

// ---------------------------------------------------------------
// 1. RG 作成時のタグ強制 (deny)
// ---------------------------------------------------------------
var missingTagConditions = [
  for t in requiredTags: {
    field: 'tags[\'${t}\']'
    exists: 'false'
  }
]

resource requireRgTagsDef 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'require-rg-tags'
  properties: {
    displayName: 'リソースグループ作成時に必須タグを強制する'
    policyType: 'Custom'
    mode: 'All' // リソースグループを対象にするには All が必要
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Resources/subscriptions/resourceGroups'
          }
          {
            anyOf: missingTagConditions
          }
        ]
      }
      then: {
        effect: tagEffect
      }
    }
  }
}

resource requireRgTagsAssign 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'require-rg-tags'
  properties: {
    displayName: 'RG 必須タグ: ${join(requiredTags, ', ')}'
    policyDefinitionId: requireRgTagsDef.id
  }
}

// ---------------------------------------------------------------
// 2. RG のタグを配下リソースへ継承 (modify)
// ---------------------------------------------------------------
resource inheritTagDefs 'Microsoft.Authorization/policyDefinitions@2023-04-01' = [
  for t in requiredTags: {
    name: 'inherit-tag-${t}-from-rg'
    properties: {
      displayName: 'タグ ${t} を RG から継承する'
      policyType: 'Custom'
      mode: 'Indexed' // タグ・リージョンを持つリソースのみ対象
      policyRule: {
        if: {
          allOf: [
            {
              field: 'tags[\'${t}\']'
              exists: 'false'
            }
            {
              value: '[resourceGroup().tags[\'${t}\']]'
              notEquals: ''
            }
          ]
        }
        then: {
          effect: 'modify'
          details: {
            roleDefinitionIds: [
              tagContributorRoleId
            ]
            operations: [
              {
                operation: 'addOrReplace'
                field: 'tags[\'${t}\']'
                value: '[resourceGroup().tags[\'${t}\']]'
              }
            ]
          }
        }
      }
    }
  }
]

resource inheritTagAssigns 'Microsoft.Authorization/policyAssignments@2023-04-01' = [
  for (t, i) in requiredTags: {
    name: 'inherit-tag-${t}'
    location: location
    identity: {
      type: 'SystemAssigned' // modify の修復に必須
    }
    properties: {
      displayName: 'タグ継承: ${t}'
      policyDefinitionId: inheritTagDefs[i].id
    }
  }
]

resource inheritTagRoleAssigns 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (t, i) in requiredTags: {
    name: guid(subscription().id, 'inherit-tag', t)
    properties: {
      principalId: inheritTagAssigns[i].identity.principalId
      roleDefinitionId: tagContributorRoleId
      principalType: 'ServicePrincipal'
    }
  }
]

// ---------------------------------------------------------------
// 3. リージョン制限（ビルトイン定義を割り当てるだけ）
// ---------------------------------------------------------------
// Allowed locations
var allowedLocationsDefId = tenantResourceId(
  'Microsoft.Authorization/policyDefinitions',
  'e56962a6-4747-49cd-b67b-bf8b01975c4c'
)
// Allowed locations for resource groups
var allowedRgLocationsDefId = tenantResourceId(
  'Microsoft.Authorization/policyDefinitions',
  'e765b5de-1225-4ba3-bd56-1ac6695af988'
)

resource allowedLocationsAssign 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'allowed-locations'
  properties: {
    displayName: 'リソースのリージョンを制限: ${join(allowedLocations, ', ')}'
    policyDefinitionId: allowedLocationsDefId
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}

resource allowedRgLocationsAssign 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'allowed-rg-locations'
  properties: {
    displayName: 'RG のリージョンを制限: ${join(allowedLocations, ', ')}'
    policyDefinitionId: allowedRgLocationsDefId
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}
