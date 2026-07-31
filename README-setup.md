# PoAIW setup instructions

## Clone

Clone the following repos to your local disk using this folder structure:

```
|-funnAI       (https://github.com/onicai/funnAI)
  |-PoAIW      (https://github.com/onicai/PoAIW)
```

Note: The folder structure is important, because the scripts use relative paths.

## Miniconda

Create a conda environment with python dependencies of `llama_cpp_canister` repo

```bash
# install Miniconda on your system

# create a conda environment
conda create --name llama_cpp_canister python=3.11
conda activate llama_cpp_canister

# from folder: PoAIW/llms/llama_cpp_canister
pip install -r requirements.txt
```

## mops

Install mops (https://mops.one/docs/install), and then:

```bash
# Do this in all these folders:
# - from folder: `PoAIW/src/Challenger`
# - from folder: `PoAIW/src/Judge`
# - from folder: `PoAIW/src/mAIner`
# - from folder: `PoAIW/src/ckSigner`
mops install
```

## Install icp-cli

dfx is deprecated; icp-cli (`icp`) replaces it. `@icp-sdk/ic-wasm` is not optional -- the
Motoko build recipe shells out to it -- and both it and `moc` are pinned because each one
changes the module hash.

```bash
npm install -g @icp-sdk/icp-cli@1.2.0 @icp-sdk/ic-wasm@0.11.0 ic-mops@2.13.2
mops toolchain use moc 1.4.1

node --version   # must be >= 22
icp --version    # 1.2.0
```

See `funnAI/README-developer-migration-guide-from-dfx-to-icp-cli.md` for the identity
setup and the full dfx -> icp command translation.

# Download the LLMs from HuggingFace

## Download LLM model (gguf)

Download the model `qwen2.5-0.5b-instruct-q8_0.gguf` from huggingface: https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF

Store it in: 
```
PoAIW/llms/models/Qwen/Qwen2.5-0.5B-Instruct-GGUF/qwen2.5-0.5b-instruct-q8_0.gguf
```

## ckSigner Python test dependencies

The ckSigner canister tests require additional Python packages:

```bash
pip install -r requirements.txt
```

This installs `icpp-pro` and `bitcoin-utils` (needed for BIP340 signature verification in tests).

# Deploy ALL canisters:

Follow instructions of:
- funnAI/README.md
- README-prd-upgrade-commands.md

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
icp canister call <canister> assignAdminRole \ -e $NETWORK
  '( record { "principal" = "<principal-id>"; role = variant { AdminQuery }; note = "Description" } )'

# Assign AdminUpdate role
icp canister call <canister> assignAdminRole \ -e $NETWORK
  '( record { "principal" = "<principal-id>"; role = variant { AdminUpdate }; note = "Description" } )'

# List all admin role assignments
icp canister call <canister -e $NETWORK > getAdminRoles

# Revoke an admin role
icp canister call <canister> revokeAdminRole '( "<principal-id>" )' -e $NETWORK
```