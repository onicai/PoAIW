# PoAIW setup instructions

For operations of PoAIW within the funnAI context, see funnAI/README-setup.md

---

## ckSigner Python test dependencies

ckSigner is a component used by the experimental IConfucius trading agent.

`PoAIW/requirements.txt`, brings in `icpp-pro` and `bitcoin-utils` (needed for BIP340 signature verification in the ckSigner tests).


# Admin RBAC

Admin Role-Based Access Control allows non-controller principals to call admin endpoints without requiring full controller privileges.

## Role Hierarchy

```
controller > AdminUpdate > AdminQuery
```

- **Controllers** always pass all admin checks
- **AdminUpdate** role includes AdminQuery permissions
- **AdminQuery** role only has query permissions

## Canisters with Admin RBAC

- GameState canister
- API canister
- mAIner canisters

## Management Endpoints (Controller-Only)

| Endpoint          | Description                           |
| ----------------- | ------------------------------------- |
| `assignAdminRole` | Assign an admin role to a principal   |
| `revokeAdminRole` | Revoke an admin role from a principal |
| `getAdminRoles`   | List all admin role assignments       |

## Usage Examples

```bash
# Assign AdminQuery role
icp canister call <canister> assignAdminRole \
  '( record { "principal" = "<principal-id>"; role = variant { AdminQuery }; note = "Description" } )' \
  -e $NETWORK

# Assign AdminUpdate role
icp canister call <canister> assignAdminRole \
  '( record { "principal" = "<principal-id>"; role = variant { AdminUpdate }; note = "Description" } )' \
  -e $NETWORK

# List all admin role assignments
icp canister call <canister> getAdminRoles '()' -e $NETWORK

# Revoke an admin role
icp canister call <canister> revokeAdminRole '( "<principal-id>" )' -e $NETWORK
```