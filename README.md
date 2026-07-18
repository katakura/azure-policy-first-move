# Azure Policy "First Move" Set for Shared Subscriptions

[日本語版はこちら / Japanese version](README-ja.md)

A minimal Azure Policy set to deploy **before** a team-shared Azure subscription
gets messy. One `main.bicep` file, one command.

Zenn article (Japanese): (link will be added after publication)

## What's included

| # | Policy | Effect | Purpose |
|---|---|---|---|
| 1 | Require `projectName` / `owner` / `expires` tags on resource groups | deny | No more orphaned resource groups nobody dares to delete |
| 2 | Inherit tags from resource group to child resources | modify | Per-resource cost tracking and inventory |
| 3 | Restrict locations to japaneast / japanwest (both RGs and resources) | deny (builtin) | Prevent accidental deployments to unintended regions |

## Deploy

```bash
az deployment sub create -l japaneast -f main.bicep
```

Not ready for hard deny? Start in audit mode:

```bash
az deployment sub create -l japaneast -f main.bicep -p tagEffect=Audit
```

## Find expired resource groups

```bash
./find-expired-rgs.sh
```

Then ask each `owner` "are you still using this?" — this simple routine
alone cuts a surprising amount of wasted spend.

## Notes

- Applying `modify` tag inheritance to pre-existing resources requires running
  a remediation task
- The builtin location restriction already excludes `location: global` resources
  (Front Door, DNS zones, etc.), so they are NOT restricted. If you need to ban
  global services entirely, add a separate deny by resource type
- Verify the builtin definition IDs (Allowed locations) with
  `az policy definition show` before assigning

## License

[MIT](LICENSE)
